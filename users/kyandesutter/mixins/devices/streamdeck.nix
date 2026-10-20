{ config, lib, pkgs, osConfig, ... }:
let
  flexoki = import ../flexoki/palette.nix;
  inherit (flexoki) accents base;

  # Same shell selector as mixins/devices/dualsense.nix, so the keys drive whichever
  # shell owns the session.
  useFormalshell = osConfig.kyan.desktop.shell == "formalshell";
  fsBin = "${config.programs.formalshell.package}/bin/formalshell";
  dmsBin = "${config.programs.dank-material-shell.package}/bin/dms";
  shellCmds =
    if useFormalshell then
      {
        lock = [ fsBin "ipc" "--any-display" "call" "lock" "lock" ];
        screenshot = [ fsBin "ipc" "--any-display" "call" "screenshot" "pick" "smart" "default" ];
        playPause = [ fsBin "ipc" "--any-display" "call" "media" "playPause" ];
      }
    else
      {
        lock = [ dmsBin "ipc" "call" "lock" "lock" ];
        screenshot = [ dmsBin "screenshot" ];
        playPause = [ dmsBin "ipc" "call" "mpris" "playPause" ];
      };

  pyList = xs: "[${lib.concatMapStringsSep ", " builtins.toJSON xs}]";

  font = "${pkgs.nerd-fonts.geist-mono}/share/fonts/opentype/NerdFonts/GeistMono/GeistMonoNerdFont-Regular.otf";
  emojiFont = "${pkgs.noto-fonts-color-emoji}/share/fonts/noto/NotoColorEmoji.ttf";

  # Soundboard sounds listed here (by name, case-insensitive) come first on
  # the soundboard page, in this order; the rest follow as Discord lists them,
  # the call's server first, then the defaults.
  soundboardPins = [ ];

  # The desk unit is the Discord edition of the Mini (PID 0x00b3), which
  # 0.9.8 doesn't list. Drop the fetchpatch once a release past 0.9.8 lands. The
  # sdist ships these two files with CRLF endings and the GitHub patch is LF.
  streamdeck = pkgs.python3Packages.streamdeck.overridePythonAttrs (old: {
    prePatch = (old.prePatch or "") + ''
      sed -i 's/\r$//' src/StreamDeck/DeviceManager.py src/StreamDeck/ProductIDs.py
    '';
    patches = (old.patches or [ ]) ++ [
      (pkgs.fetchpatch {
        url = "https://github.com/abcminiuser/python-elgato-streamdeck/commit/ac67de1f70.patch";
        hash = "sha256-IOEfH32Dy0bKq4wNXTuDeRgx6eMJXXdLd6Dk6cJg/pc=";
      })
    ];
  });

  # The Stream Deck Mini on the g815's desk: six keys, three pages, the last
  # key cycles through them.
  #
  #   herdr                          system
  #   [blocked] [done]  [working]    [mic]        [mute] [play/pause]
  #   [new tab] [herdr] [system]     [screenshot] [lock] [discord]
  #
  #   discord                        soundboard
  #   [mute]  [deafen] [camera]      [sound] [sound] [sound]
  #   [share] [sounds] [herdr]       [sound] [more]  [back]
  #
  # The jump keys show how many agents are in that state and focus the one
  # that entered it most recently. Focus goes to the macbook's Herdr server,
  # which every attached client (`herdr --remote macbook` included) follows;
  # the herdr key opens such a client. The page key turns red on the other
  # pages while an agent is blocked.
  #
  # The discord page talks to Discord through the streamdeckBridge moonlight
  # extension (mixins/apps/discord.nix), which fires Discord's own keybind
  # actions, so each key behaves exactly like the matching Discord keybind.
  # The sounds key opens a page of the soundboard sounds usable in the current
  # call, paged four at a time when there are more than five.
  #
  # Herdr runs on the macbook, so agent state arrives the same way as
  # dualsense-herdr's: one long-lived SSH connection with the poll loop on the
  # remote side. See that unit for why ClearAllForwardings and bash -c.
  streamdeckKeys = pkgs.writers.writePython3Bin "streamdeck-keys"
    {
      libraries = [ streamdeck ] ++ (with pkgs.python3Packages; [ pillow fonttools ]);
      flakeIgnore = [ "E501" ];
    } ''
    import io
    import json
    import os
    import socket
    import subprocess
    import threading
    import time
    import urllib.error
    import urllib.request

    from fontTools.ttLib import TTFont
    from PIL import Image, ImageDraw, ImageFont, ImageSequence
    from StreamDeck.DeviceManager import DeviceManager
    from StreamDeck.ImageHelpers import PILHelper

    FONT = "${font}"
    EMOJI_FONT = "${emojiFont}"
    DISCORD_SOCKET = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "discord-streamdeck.sock")
    SOUNDBOARD_PINS = ${pyList soundboardPins}
    HERDR = "/etc/profiles/per-user/kyandesutter/bin/herdr"
    SSH = ["${pkgs.openssh}/bin/ssh", "-o", "BatchMode=yes", "-o", "ClearAllForwardings=yes", "-o", "ConnectTimeout=10"]
    WPCTL = "${pkgs.wireplumber}/bin/wpctl"
    LOCK = ${pyList shellCmds.lock}
    SCREENSHOT = ${pyList shellCmds.screenshot}
    PLAY_PAUSE = ${pyList shellCmds.playPause}
    HERDR_TERMINAL = ["ghostty", "-e", "herdr", "--remote", "macbook"]

    # Keys carry colour roles; render_key resolves them against the palette,
    # so a matugen re-theme repaints without rebuilding any layout.
    BG, FG, DIM, RED, YELLOW, GREEN, BLUE = "bg", "fg", "dim", "red", "yellow", "green", "blue"
    FLEXOKI = {
        BG: "${base.black}",
        FG: "${base.b200}",
        DIM: "${base.b600}",
        RED: "${accents.red.d}",
        YELLOW: "${accents.yellow.d}",
        GREEN: "${accents.green.d}",
        BLUE: "${accents.blue.d}",
    }
    THEME = os.path.expanduser("~/.cache/dank/streamdeck.json")

    AGENT_STYLE = {
        "blocked": ("md-alert", BG, RED),
        "done": ("md-check_circle", GREEN, BG),
        "working": ("md-robot", YELLOW, BG),
    }

    # Glyphs are looked up by their Nerd Font name rather than hardcoded
    # codepoints, so a renamed or missing icon fails loudly at start.
    GLYPHS = {name: chr(cp) for cp, name in TTFont(FONT).getBestCmap().items()}


    def glyph(name):
        return GLYPHS[name]


    class State:
        def __init__(self):
            self.lock = threading.Lock()
            self.changed = threading.Event()
            self.page = "herdr"
            self.agents = []
            self.sink_muted = False
            self.source_muted = False
            self.discord = None
            self.sound_page = 0
            self.palette = dict(FLEXOKI)

        def update(self, **kw):
            with self.lock:
                dirty = any(getattr(self, k) != v for k, v in kw.items())
                for k, v in kw.items():
                    setattr(self, k, v)
            if dirty:
                self.changed.set()


    STATE = State()


    def spawn(cmd):
        threading.Thread(target=subprocess.run, args=(cmd,), kwargs={"check": False, "stdout": subprocess.DEVNULL}, daemon=True).start()


    def parse_agents(line):
        try:
            agents = json.loads(line)["result"]["agents"]
        except (ValueError, KeyError, TypeError):
            return []
        out = [
            {
                "pane": a["pane_id"],
                "status": a.get("agent_status", "idle"),
                "seq": a.get("state_change_seq", 0),
                "label": os.path.basename((a.get("cwd") or "").rstrip("/")) or a.get("agent", "?"),
            }
            for a in agents
        ]
        return out


    def watch_herdr():
        remote = f"bash -c 'while :; do {HERDR} agent list 2>/dev/null || echo null; sleep 2; done'"
        while True:
            proc = subprocess.Popen(
                SSH + ["-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=2", "macbook", remote],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
            )
            for line in proc.stdout:
                STATE.update(agents=parse_agents(line))
            proc.wait()
            STATE.update(agents=[])
            time.sleep(10)


    DISCORD = {"sock": None}


    def watch_discord():
        while True:
            try:
                with socket.socket(socket.AF_UNIX) as sock:
                    sock.connect(DISCORD_SOCKET)
                    DISCORD["sock"] = sock
                    for line in sock.makefile(encoding="utf-8"):
                        STATE.update(discord=json.loads(line))
            except (OSError, ValueError):
                pass
            DISCORD["sock"] = None
            STATE.update(discord=None)
            time.sleep(5)


    def discord(cmd, **args):
        sock = DISCORD["sock"]
        if sock is None:
            return
        try:
            sock.sendall((json.dumps({"cmd": cmd, **args}) + "\n").encode())
        except OSError:
            pass


    def watch_theme():
        seen = None
        while True:
            try:
                mtime = os.stat(THEME).st_mtime
                if mtime != seen:
                    seen = mtime
                    with open(THEME) as f:
                        STATE.update(palette={**FLEXOKI, **json.load(f)})
            except (OSError, ValueError):
                if seen is not None:
                    seen = None
                    STATE.update(palette=dict(FLEXOKI))
            time.sleep(2)


    def muted(target):
        out = subprocess.run([WPCTL, "get-volume", target], capture_output=True, text=True, check=False).stdout
        return "[MUTED]" in out


    def watch_audio():
        while True:
            STATE.update(
                sink_muted=muted("@DEFAULT_AUDIO_SINK@"),
                source_muted=muted("@DEFAULT_AUDIO_SOURCE@"),
            )
            time.sleep(1)


    def herdr(*args):
        spawn(SSH + ["macbook", HERDR, *args])


    def focus_agent(pane):
        herdr("agent", "focus", pane)


    PAGES = ["herdr", "system", "discord"]


    def page_key(page, blocked):
        nxt = PAGES[(PAGES.index(page) + 1) % len(PAGES)]
        icon = {"herdr": "md-robot", "system": "md-cog", "discord": "md-discord"}[nxt]
        fg, bg = (BG, RED) if blocked and page != "herdr" else (FG, BG)
        return (icon, nxt, fg, bg, lambda: STATE.update(page=nxt))


    def jump_key(agents, status, label):
        matches = [a for a in agents if a["status"] == status]
        icon, fg, bg = AGENT_STYLE[status]
        if not matches:
            return (icon, label, DIM, BG, None)
        newest = max(matches, key=lambda a: a["seq"])
        return (icon, f"{len(matches)} {newest['label']}", fg, bg, lambda p=newest["pane"]: focus_agent(p))


    def layout():
        """Six (icon, label, fg, bg, action) tuples for the current page."""
        with STATE.lock:
            page = STATE.page
            agents = list(STATE.agents)
            sink, source = STATE.sink_muted, STATE.source_muted
            d, sound_page = STATE.discord, STATE.sound_page

        blocked = any(a["status"] == "blocked" for a in agents)

        if page == "herdr":
            return [
                jump_key(agents, "blocked", "blocked"),
                jump_key(agents, "done", "done"),
                jump_key(agents, "working", "working"),
                ("md-tab_plus", "new tab", FG, BG, lambda: herdr("tab", "create")),
                ("md-console", "herdr", BLUE, BG, lambda: spawn(HERDR_TERMINAL)),
                page_key(page, blocked),
            ]

        if page == "discord":
            return discord_page(d, blocked)
        if page == "soundboard":
            return soundboard_page(d, sound_page)

        return [
            ("md-microphone_off", "mic off", BG, RED, None) if source else ("md-microphone", "mic", FG, BG, None),
            ("md-volume_off", "muted", BG, RED, None) if sink else ("md-volume_high", "sound", FG, BG, None),
            ("md-play_pause", "play", FG, BG, lambda: spawn(PLAY_PAUSE)),
            ("md-monitor_screenshot", "shot", FG, BG, lambda: spawn(SCREENSHOT)),
            ("md-lock", "lock", FG, BG, lambda: spawn(LOCK)),
            page_key(page, blocked),
        ]


    def toggle_key(on, icon_on, label_on, icon_off, label_off, cmd, enabled=True):
        if not enabled:
            return (icon_off, label_off, DIM, BG, None)
        if on:
            return (icon_on, label_on, BG, RED, lambda: discord(cmd))
        return (icon_off, label_off, FG, BG, lambda: discord(cmd))


    def discord_page(d, blocked):
        online = d is not None
        call = online and d["inCall"]
        return [
            toggle_key(online and d["mute"], "md-microphone_off", "muted", "md-microphone", "mute", "mute", online),
            toggle_key(online and d["deaf"], "md-headphones_off", "deafened", "md-headphones", "deafen", "deaf", online),
            toggle_key(call and d["video"], "md-video", "camera on", "md-video_off", "camera", "camera", call),
            toggle_key(call and d["sharing"], "md-monitor_share", "sharing", "md-monitor_share", "share", "share", call),
            ("md-music_box_multiple", "sounds", FG, BG, lambda: STATE.update(page="soundboard", sound_page=0))
            if call and d["sounds"] else ("md-music_box_multiple", "sounds", DIM, BG, None),
            page_key("discord", blocked),
        ]


    def soundboard_page(d, sound_page):
        rank = {name.lower(): i for i, name in enumerate(SOUNDBOARD_PINS)}
        sounds = sorted(d["sounds"] if d and d["inCall"] else [], key=lambda s: rank.get(s["name"].lower(), len(rank)))
        back = ("md-arrow_left", "back", FG, BG, lambda: STATE.update(page="discord"))
        if len(sounds) <= 5:
            shown, more = sounds, []
        else:
            pages = -(-len(sounds) // 4)
            start = (sound_page % pages) * 4
            shown = sounds[start:start + 4]
            more = [("md-chevron_right", f"{sound_page % pages + 1}/{pages}", FG, BG,
                     lambda: STATE.update(sound_page=(sound_page + 1) % pages))]
        keys = [
            (s, s["name"], FG, BG, lambda s=s: discord("sound", guild=s["guild"], id=s["id"]))
            for s in shown
        ]
        return keys + [None] * (5 - len(keys) - len(more)) + more + [back]


    EMOJI_CACHE = {}


    def fetch_emoji(emoji_id):
        # The CDN answers urllib's default User-Agent with a 403, and asking
        # for the .gif of a static emoji with a 415.
        for ext in ("gif", "png"):
            req = urllib.request.Request(
                f"https://cdn.discordapp.com/emojis/{emoji_id}.{ext}?size=96",
                headers={"User-Agent": "streamdeck-keys"},
            )
            try:
                with urllib.request.urlopen(req, timeout=3) as resp:
                    return Image.open(io.BytesIO(resp.read()))
            except urllib.error.HTTPError as err:
                if err.code != 415:
                    raise
        return None


    def emoji_frames(sound, size):
        """The sound's emoji as [(RGBA image, duration ms)], or None if it has none."""
        key = (sound["emojiId"] or sound["emoji"], size)
        if key in EMOJI_CACHE:
            return EMOJI_CACHE[key]
        frames = None
        try:
            if sound["emojiId"]:
                image = fetch_emoji(sound["emojiId"])
                if image is not None:
                    frames = [(f.convert("RGBA"), f.info.get("duration") or 100) for f in ImageSequence.Iterator(image)]
            elif sound["emoji"]:
                # Noto Color Emoji is a bitmap font with a single 109px strike.
                image = Image.new("RGBA", (160, 160))
                ImageDraw.Draw(image).text((0, 0), sound["emoji"], font=ImageFont.truetype(EMOJI_FONT, 109), embedded_color=True)
                box = image.getbbox()
                frames = [(image.crop(box), 0)] if box else None
        except (OSError, ValueError) as err:
            print(f"emoji for {sound['name']}: {err}", flush=True)
            frames = None
        for image, _ in frames or []:
            image.thumbnail((size, size))
        EMOJI_CACHE[key] = frames
        return frames


    def frame_at(frames, now_ms):
        total = sum(ms for _, ms in frames)
        if total == 0:
            return frames[0][0]
        t = now_ms % total
        for image, ms in frames:
            if t < ms:
                return image
            t -= ms
        return frames[-1][0]


    def animated(keys, size):
        return any(
            isinstance(k[0], dict) and len(emoji_frames(k[0], int(size * 0.5)) or []) > 1
            for k in keys if k
        )


    # The mute keys toggle by position rather than through a stored action, so
    # a press always flips whatever the live state is.
    SYSTEM_TOGGLES = {
        0: [WPCTL, "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"],
        1: [WPCTL, "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"],
    }


    def render_key(deck, key, palette, icon_font, label_font):
        image = PILHelper.create_key_image(deck, background=palette[key[3] if key else BG])
        if key:
            icon, label, fg, _, _ = key
            fg = palette[fg]
            draw = ImageDraw.Draw(image)
            w, h = image.size
            if isinstance(icon, dict):
                frames = emoji_frames(icon, int(h * 0.5))
                if frames:
                    emoji = frame_at(frames, int(time.monotonic() * 1000))
                    image.paste(emoji, ((w - emoji.width) // 2, int(h * 0.42 - emoji.height / 2)), emoji)
                    draw.text((w / 2, h * 0.84), label[:9], font=label_font, fill=fg, anchor="mm")
                    return PILHelper.to_native_key_format(deck, image)
                icon = "md-music_note"
            # Nerd Font icons overflow their monospace cell, so centring on the
            # advance box lands them right of centre. Centre the ink instead.
            x0, y0, x1, y1 = draw.textbbox((0, 0), glyph(icon), font=icon_font)
            draw.text(((w - (x1 - x0)) / 2 - x0, h * 0.42 - (y1 - y0) / 2 - y0), glyph(icon), font=icon_font, fill=fg)
            draw.text((w / 2, h * 0.84), label[:9], font=label_font, fill=fg, anchor="mm")
        return PILHelper.to_native_key_format(deck, image)


    def on_key(deck, index, pressed):
        if not pressed:
            return
        with STATE.lock:
            page = STATE.page
        if page == "system" and index in SYSTEM_TOGGLES:
            spawn(SYSTEM_TOGGLES[index])
            # wpctl's poll picks the new state up within a second; nudge it.
            threading.Timer(0.2, lambda: STATE.update(
                sink_muted=muted("@DEFAULT_AUDIO_SINK@"),
                source_muted=muted("@DEFAULT_AUDIO_SOURCE@"),
            )).start()
            return
        keys = layout()
        if index < len(keys) and keys[index] and keys[index][4]:
            keys[index][4]()


    def drive(deck):
        deck.open()
        deck.reset()
        deck.set_brightness(70)
        size = deck.key_image_format()["size"][1]
        icon_font = ImageFont.truetype(FONT, int(size * 0.45))
        label_font = ImageFont.truetype(FONT, int(size * 0.16))
        deck.set_key_callback(on_key)
        sent = [None] * deck.key_count()
        last_full = 0
        try:
            while deck.connected():
                keys = layout()
                with STATE.lock:
                    palette = STATE.palette
                # A periodic full repaint covers the deck resetting itself
                # across a suspend, which reports no event.
                if time.monotonic() - last_full > 30:
                    sent = [None] * deck.key_count()
                    last_full = time.monotonic()
                # Only keys whose image changed go over USB: the Mini takes
                # uncompressed bitmaps, and animated emoji redraw constantly.
                with deck:
                    for i in range(deck.key_count()):
                        image = render_key(deck, keys[i] if i < len(keys) else None, palette, icon_font, label_font)
                        if image != sent[i]:
                            deck.set_key_image(i, image)
                            sent[i] = image
                STATE.changed.wait(timeout=0.05 if animated(keys, size) else 30)
                STATE.changed.clear()
        finally:
            try:
                deck.close()
            except Exception:
                pass


    def main():
        threading.Thread(target=watch_herdr, daemon=True).start()
        threading.Thread(target=watch_audio, daemon=True).start()
        threading.Thread(target=watch_discord, daemon=True).start()
        threading.Thread(target=watch_theme, daemon=True).start()
        while True:
            decks = DeviceManager().enumerate()
            if not decks:
                time.sleep(5)
                continue
            try:
                drive(decks[0])
            except Exception as err:
                print(f"stream deck lost: {err}", flush=True)
            time.sleep(2)


    main()
  '';
in
{
  home.packages = [ streamdeckKeys ];

  systemd.user.services.streamdeck-keys = {
    Unit = {
      Description = "Stream Deck keys for Herdr agents, system and Discord controls";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${streamdeckKeys}/bin/streamdeck-keys";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
