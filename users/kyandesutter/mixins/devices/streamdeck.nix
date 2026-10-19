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

  # The Stream Deck Mini on the g815's desk: six keys, two pages, the last key
  # flips between them.
  #
  #   herdr                          system
  #   [blocked] [done]  [working]    [mic]        [mute] [play/pause]
  #   [new tab] [herdr] [system]     [screenshot] [lock] [herdr]
  #
  # The jump keys show how many agents are in that state and focus the one
  # that entered it most recently. Focus goes to the macbook's Herdr server,
  # which every attached client (`herdr --remote macbook` included) follows;
  # the herdr key opens such a client. The page key turns red on the system
  # page while an agent is blocked.
  #
  # Herdr runs on the macbook, so agent state arrives the same way as
  # dualsense-herdr's: one long-lived SSH connection with the poll loop on the
  # remote side. See that unit for why ClearAllForwardings and bash -c.
  streamdeckKeys = pkgs.writers.writePython3Bin "streamdeck-keys"
    {
      libraries = [ streamdeck ] ++ (with pkgs.python3Packages; [ pillow fonttools ]);
      flakeIgnore = [ "E501" ];
    } ''
    import json
    import os
    import subprocess
    import threading
    import time

    from fontTools.ttLib import TTFont
    from PIL import ImageDraw, ImageFont
    from StreamDeck.DeviceManager import DeviceManager
    from StreamDeck.ImageHelpers import PILHelper

    FONT = "${font}"
    HERDR = "/etc/profiles/per-user/kyandesutter/bin/herdr"
    SSH = ["${pkgs.openssh}/bin/ssh", "-o", "BatchMode=yes", "-o", "ClearAllForwardings=yes", "-o", "ConnectTimeout=10"]
    WPCTL = "${pkgs.wireplumber}/bin/wpctl"
    LOCK = ${pyList shellCmds.lock}
    SCREENSHOT = ${pyList shellCmds.screenshot}
    PLAY_PAUSE = ${pyList shellCmds.playPause}
    HERDR_TERMINAL = ["ghostty", "-e", "herdr", "--remote", "macbook"]

    BG = "${base.black}"
    FG = "${base.b200}"
    DIM = "${base.b600}"
    RED = "${accents.red.d}"
    YELLOW = "${accents.yellow.d}"
    GREEN = "${accents.green.d}"
    BLUE = "${accents.blue.d}"

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


    PAGES = ["herdr", "system"]


    def page_key(page, blocked):
        nxt = PAGES[(PAGES.index(page) + 1) % len(PAGES)]
        icon = {"herdr": "md-robot", "system": "md-cog"}[nxt]
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

        return [
            ("md-microphone_off", "mic off", BG, RED, None) if source else ("md-microphone", "mic", FG, BG, None),
            ("md-volume_off", "muted", BG, RED, None) if sink else ("md-volume_high", "sound", FG, BG, None),
            ("md-play_pause", "play", FG, BG, lambda: spawn(PLAY_PAUSE)),
            ("md-monitor_screenshot", "shot", FG, BG, lambda: spawn(SCREENSHOT)),
            ("md-lock", "lock", FG, BG, lambda: spawn(LOCK)),
            page_key(page, blocked),
        ]


    # The mute keys toggle by position rather than through a stored action, so
    # a press always flips whatever the live state is.
    SYSTEM_TOGGLES = {
        0: [WPCTL, "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"],
        1: [WPCTL, "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"],
    }


    def render_key(deck, key, icon_font, label_font):
        image = PILHelper.create_key_image(deck, background=key[3] if key else BG)
        if key:
            icon, label, fg, _, _ = key
            draw = ImageDraw.Draw(image)
            w, h = image.size
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
        try:
            while deck.connected():
                keys = layout()
                with deck:
                    for i in range(deck.key_count()):
                        deck.set_key_image(i, render_key(deck, keys[i] if i < len(keys) else None, icon_font, label_font))
                # A periodic repaint covers the deck resetting itself across
                # a suspend, which reports no event.
                STATE.changed.wait(timeout=30)
                STATE.changed.clear()
        finally:
            try:
                deck.close()
            except Exception:
                pass


    def main():
        threading.Thread(target=watch_herdr, daemon=True).start()
        threading.Thread(target=watch_audio, daemon=True).start()
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
      Description = "Stream Deck keys for Herdr agents and system controls";
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
