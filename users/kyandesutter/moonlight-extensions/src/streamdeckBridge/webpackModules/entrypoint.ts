import {
  ApplicationStreamingStore,
  ChannelStore,
  MediaEngineStore,
  SelectedChannelStore,
  SoundboardStore
} from "@moonlight-mod/wp/common_stores";
import spacepack from "@moonlight-mod/wp/spacepack_spacepack";
import { trigger } from "@moonlight-mod/wp/streamdeckBridge_keybinds";

const logger = moonlight.getLogger("streamdeckBridge");
const natives = moonlight.getNatives("streamdeckBridge");

type Sound = {
  soundId: string;
  guildId: string;
  name: string;
  emojiId: string | null;
  emojiName: string | null;
  available: boolean;
};

// Default sounds are filed under this guild id in SoundboardStore.
const DEFAULT_GUILD = "0";

// Export keys are minified, so these are found by a string only their body
// contains. The soundboard module has two functions that dispatch
// SOUNDBOARD_TRACK_USAGE; only the one that plays into the call reads
// emojiName, the other sends an echo.
const lookups: Record<string, [string, string[]]> = {
  playSound: ['"SOUNDBOARD_TRACK_USAGE"', ['type:"SOUNDBOARD_TRACK_USAGE"', "emojiName"]],
  fetchSounds: ['"OVERLAY_SOUNDBOARD_SOUNDS_FETCH_REQUEST"', ['"OVERLAY_SOUNDBOARD_SOUNDS_FETCH_REQUEST"']]
};
const found: Record<string, any> = {};

function lookup(name: keyof typeof lookups) {
  if (found[name] != null) return found[name];
  const [code, strings] = lookups[name];
  for (const mod of spacepack.findByCode(code)) {
    const fn = spacepack.findFunctionByStrings(mod.exports, ...strings);
    if (fn != null) return (found[name] = fn);
  }
  logger.error(`could not find ${name}`);
  return null;
}

function voiceChannel() {
  const id = SelectedChannelStore.getVoiceChannelId();
  return id == null ? null : ChannelStore.getChannel(id);
}

// What the soundboard button in a call offers without Nitro: the server's
// own sounds, then Discord's defaults.
function sounds(guildId: string | null): Sound[] {
  const own: Sound[] = guildId == null ? [] : SoundboardStore.getSoundsForGuild(guildId) ?? [];
  const defaults: Sound[] = SoundboardStore.getSoundsForGuild(DEFAULT_GUILD) ?? [];
  return [...own, ...defaults].filter((s) => s.available !== false);
}

function snapshot() {
  const channel = voiceChannel();
  const guildId: string | null = channel?.guild_id ?? null;
  return JSON.stringify({
    inCall: channel != null,
    mute: MediaEngineStore.isSelfMute(),
    deaf: MediaEngineStore.isSelfDeaf(),
    video: MediaEngineStore.isVideoEnabled(),
    sharing: ApplicationStreamingStore.getCurrentUserActiveStream() != null,
    sounds:
      channel == null
        ? []
        : sounds(guildId).map((s) => ({
            id: s.soundId,
            guild: s.guildId,
            name: s.name,
            emoji: s.emojiName,
            emojiId: s.emojiId
          }))
  });
}

let fetchedFor: string | null = null;

function publish() {
  const channel = voiceChannel();
  // Guild sounds only reach the store once something asks for them, which
  // is normally the soundboard popout opening.
  if (channel != null && channel.id !== fetchedFor) {
    fetchedFor = channel.id;
    lookup("fetchSounds")?.({ disableAnalytics: true });
  }
  natives.publish(snapshot());
}

const KEYBINDS: Record<string, string> = {
  mute: "TOGGLE_MUTE",
  deaf: "TOGGLE_DEAFEN",
  camera: "TOGGLE_CAMERA",
  share: "TOGGLE_GO_LIVE_STREAMING"
};

function onCommand(line: string) {
  let msg: { cmd: string; guild?: string; id?: string };
  try {
    msg = JSON.parse(line);
  } catch {
    return;
  }
  if (msg.cmd in KEYBINDS) {
    if (!trigger(KEYBINDS[msg.cmd])) logger.error("keybind table was never captured");
    return;
  }
  if (msg.cmd === "sound") {
    const channel = voiceChannel();
    const sound = SoundboardStore.getSound(msg.guild, msg.id);
    if (channel != null && sound != null) lookup("playSound")?.(sound, channel.id, []);
  }
}

for (const store of [MediaEngineStore, SelectedChannelStore, SoundboardStore, ApplicationStreamingStore]) {
  store.addChangeListener(publish);
}
natives.start(onCommand);
publish();
