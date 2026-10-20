"use strict";
var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// src/streamdeckBridge/webpackModules/entrypoint.ts
var import_common_stores = require("common_stores");
var import_spacepack_spacepack = __toESM(require("spacepack_spacepack"));
var import_streamdeckBridge_keybinds = require("streamdeckBridge_keybinds");
var logger = moonlight.getLogger("streamdeckBridge");
var natives = moonlight.getNatives("streamdeckBridge");
var DEFAULT_GUILD = "0";
var lookups = {
  playSound: ['"SOUNDBOARD_TRACK_USAGE"', ['type:"SOUNDBOARD_TRACK_USAGE"', "emojiName"]],
  fetchSounds: ['"OVERLAY_SOUNDBOARD_SOUNDS_FETCH_REQUEST"', ['"OVERLAY_SOUNDBOARD_SOUNDS_FETCH_REQUEST"']]
};
var found = {};
function lookup(name) {
  if (found[name] != null)
    return found[name];
  const [code, strings] = lookups[name];
  for (const mod of import_spacepack_spacepack.default.findByCode(code)) {
    const fn = import_spacepack_spacepack.default.findFunctionByStrings(mod.exports, ...strings);
    if (fn != null)
      return found[name] = fn;
  }
  logger.error(`could not find ${name}`);
  return null;
}
function voiceChannel() {
  const id = import_common_stores.SelectedChannelStore.getVoiceChannelId();
  return id == null ? null : import_common_stores.ChannelStore.getChannel(id);
}
function sounds(guildId) {
  const own = guildId == null ? [] : import_common_stores.SoundboardStore.getSoundsForGuild(guildId) ?? [];
  const defaults = import_common_stores.SoundboardStore.getSoundsForGuild(DEFAULT_GUILD) ?? [];
  return [...own, ...defaults].filter((s) => s.available !== false);
}
function snapshot() {
  const channel = voiceChannel();
  const guildId = channel?.guild_id ?? null;
  return JSON.stringify({
    inCall: channel != null,
    mute: import_common_stores.MediaEngineStore.isSelfMute(),
    deaf: import_common_stores.MediaEngineStore.isSelfDeaf(),
    video: import_common_stores.MediaEngineStore.isVideoEnabled(),
    sharing: import_common_stores.ApplicationStreamingStore.getCurrentUserActiveStream() != null,
    sounds: channel == null ? [] : sounds(guildId).map((s) => ({
      id: s.soundId,
      guild: s.guildId,
      name: s.name,
      emoji: s.emojiName,
      emojiId: s.emojiId
    }))
  });
}
var fetchedFor = null;
function publish() {
  const channel = voiceChannel();
  if (channel != null && channel.id !== fetchedFor) {
    fetchedFor = channel.id;
    lookup("fetchSounds")?.({ disableAnalytics: true });
  }
  natives.publish(snapshot());
}
var KEYBINDS = {
  mute: "TOGGLE_MUTE",
  deaf: "TOGGLE_DEAFEN",
  camera: "TOGGLE_CAMERA",
  share: "TOGGLE_GO_LIVE_STREAMING"
};
function onCommand(line) {
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return;
  }
  if (msg.cmd in KEYBINDS) {
    if (!(0, import_streamdeckBridge_keybinds.trigger)(KEYBINDS[msg.cmd]))
      logger.error("keybind table was never captured");
    return;
  }
  if (msg.cmd === "sound") {
    const channel = voiceChannel();
    const sound = import_common_stores.SoundboardStore.getSound(msg.guild, msg.id);
    if (channel != null && sound != null)
      lookup("playSound")?.(sound, channel.id, []);
  }
}
for (const store of [import_common_stores.MediaEngineStore, import_common_stores.SelectedChannelStore, import_common_stores.SoundboardStore, import_common_stores.ApplicationStreamingStore]) {
  store.addChangeListener(publish);
}
natives.start(onCommand);
publish();
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vLi4vc3JjL3N0cmVhbWRlY2tCcmlkZ2Uvd2VicGFja01vZHVsZXMvZW50cnlwb2ludC50cyJdLAogICJzb3VyY2VzQ29udGVudCI6IFsiaW1wb3J0IHtcbiAgQXBwbGljYXRpb25TdHJlYW1pbmdTdG9yZSxcbiAgQ2hhbm5lbFN0b3JlLFxuICBNZWRpYUVuZ2luZVN0b3JlLFxuICBTZWxlY3RlZENoYW5uZWxTdG9yZSxcbiAgU291bmRib2FyZFN0b3JlXG59IGZyb20gXCJAbW9vbmxpZ2h0LW1vZC93cC9jb21tb25fc3RvcmVzXCI7XG5pbXBvcnQgc3BhY2VwYWNrIGZyb20gXCJAbW9vbmxpZ2h0LW1vZC93cC9zcGFjZXBhY2tfc3BhY2VwYWNrXCI7XG5pbXBvcnQgeyB0cmlnZ2VyIH0gZnJvbSBcIkBtb29ubGlnaHQtbW9kL3dwL3N0cmVhbWRlY2tCcmlkZ2Vfa2V5YmluZHNcIjtcblxuY29uc3QgbG9nZ2VyID0gbW9vbmxpZ2h0LmdldExvZ2dlcihcInN0cmVhbWRlY2tCcmlkZ2VcIik7XG5jb25zdCBuYXRpdmVzID0gbW9vbmxpZ2h0LmdldE5hdGl2ZXMoXCJzdHJlYW1kZWNrQnJpZGdlXCIpO1xuXG50eXBlIFNvdW5kID0ge1xuICBzb3VuZElkOiBzdHJpbmc7XG4gIGd1aWxkSWQ6IHN0cmluZztcbiAgbmFtZTogc3RyaW5nO1xuICBlbW9qaUlkOiBzdHJpbmcgfCBudWxsO1xuICBlbW9qaU5hbWU6IHN0cmluZyB8IG51bGw7XG4gIGF2YWlsYWJsZTogYm9vbGVhbjtcbn07XG5cbi8vIERlZmF1bHQgc291bmRzIGFyZSBmaWxlZCB1bmRlciB0aGlzIGd1aWxkIGlkIGluIFNvdW5kYm9hcmRTdG9yZS5cbmNvbnN0IERFRkFVTFRfR1VJTEQgPSBcIjBcIjtcblxuLy8gRXhwb3J0IGtleXMgYXJlIG1pbmlmaWVkLCBzbyB0aGVzZSBhcmUgZm91bmQgYnkgYSBzdHJpbmcgb25seSB0aGVpciBib2R5XG4vLyBjb250YWlucy4gVGhlIHNvdW5kYm9hcmQgbW9kdWxlIGhhcyB0d28gZnVuY3Rpb25zIHRoYXQgZGlzcGF0Y2hcbi8vIFNPVU5EQk9BUkRfVFJBQ0tfVVNBR0U7IG9ubHkgdGhlIG9uZSB0aGF0IHBsYXlzIGludG8gdGhlIGNhbGwgcmVhZHNcbi8vIGVtb2ppTmFtZSwgdGhlIG90aGVyIHNlbmRzIGFuIGVjaG8uXG5jb25zdCBsb29rdXBzOiBSZWNvcmQ8c3RyaW5nLCBbc3RyaW5nLCBzdHJpbmdbXV0+ID0ge1xuICBwbGF5U291bmQ6IFsnXCJTT1VOREJPQVJEX1RSQUNLX1VTQUdFXCInLCBbJ3R5cGU6XCJTT1VOREJPQVJEX1RSQUNLX1VTQUdFXCInLCBcImVtb2ppTmFtZVwiXV0sXG4gIGZldGNoU291bmRzOiBbJ1wiT1ZFUkxBWV9TT1VOREJPQVJEX1NPVU5EU19GRVRDSF9SRVFVRVNUXCInLCBbJ1wiT1ZFUkxBWV9TT1VOREJPQVJEX1NPVU5EU19GRVRDSF9SRVFVRVNUXCInXV1cbn07XG5jb25zdCBmb3VuZDogUmVjb3JkPHN0cmluZywgYW55PiA9IHt9O1xuXG5mdW5jdGlvbiBsb29rdXAobmFtZToga2V5b2YgdHlwZW9mIGxvb2t1cHMpIHtcbiAgaWYgKGZvdW5kW25hbWVdICE9IG51bGwpIHJldHVybiBmb3VuZFtuYW1lXTtcbiAgY29uc3QgW2NvZGUsIHN0cmluZ3NdID0gbG9va3Vwc1tuYW1lXTtcbiAgZm9yIChjb25zdCBtb2Qgb2Ygc3BhY2VwYWNrLmZpbmRCeUNvZGUoY29kZSkpIHtcbiAgICBjb25zdCBmbiA9IHNwYWNlcGFjay5maW5kRnVuY3Rpb25CeVN0cmluZ3MobW9kLmV4cG9ydHMsIC4uLnN0cmluZ3MpO1xuICAgIGlmIChmbiAhPSBudWxsKSByZXR1cm4gKGZvdW5kW25hbWVdID0gZm4pO1xuICB9XG4gIGxvZ2dlci5lcnJvcihgY291bGQgbm90IGZpbmQgJHtuYW1lfWApO1xuICByZXR1cm4gbnVsbDtcbn1cblxuZnVuY3Rpb24gdm9pY2VDaGFubmVsKCkge1xuICBjb25zdCBpZCA9IFNlbGVjdGVkQ2hhbm5lbFN0b3JlLmdldFZvaWNlQ2hhbm5lbElkKCk7XG4gIHJldHVybiBpZCA9PSBudWxsID8gbnVsbCA6IENoYW5uZWxTdG9yZS5nZXRDaGFubmVsKGlkKTtcbn1cblxuLy8gV2hhdCB0aGUgc291bmRib2FyZCBidXR0b24gaW4gYSBjYWxsIG9mZmVycyB3aXRob3V0IE5pdHJvOiB0aGUgc2VydmVyJ3Ncbi8vIG93biBzb3VuZHMsIHRoZW4gRGlzY29yZCdzIGRlZmF1bHRzLlxuZnVuY3Rpb24gc291bmRzKGd1aWxkSWQ6IHN0cmluZyB8IG51bGwpOiBTb3VuZFtdIHtcbiAgY29uc3Qgb3duOiBTb3VuZFtdID0gZ3VpbGRJZCA9PSBudWxsID8gW10gOiBTb3VuZGJvYXJkU3RvcmUuZ2V0U291bmRzRm9yR3VpbGQoZ3VpbGRJZCkgPz8gW107XG4gIGNvbnN0IGRlZmF1bHRzOiBTb3VuZFtdID0gU291bmRib2FyZFN0b3JlLmdldFNvdW5kc0Zvckd1aWxkKERFRkFVTFRfR1VJTEQpID8/IFtdO1xuICByZXR1cm4gWy4uLm93biwgLi4uZGVmYXVsdHNdLmZpbHRlcigocykgPT4gcy5hdmFpbGFibGUgIT09IGZhbHNlKTtcbn1cblxuZnVuY3Rpb24gc25hcHNob3QoKSB7XG4gIGNvbnN0IGNoYW5uZWwgPSB2b2ljZUNoYW5uZWwoKTtcbiAgY29uc3QgZ3VpbGRJZDogc3RyaW5nIHwgbnVsbCA9IGNoYW5uZWw/Lmd1aWxkX2lkID8/IG51bGw7XG4gIHJldHVybiBKU09OLnN0cmluZ2lmeSh7XG4gICAgaW5DYWxsOiBjaGFubmVsICE9IG51bGwsXG4gICAgbXV0ZTogTWVkaWFFbmdpbmVTdG9yZS5pc1NlbGZNdXRlKCksXG4gICAgZGVhZjogTWVkaWFFbmdpbmVTdG9yZS5pc1NlbGZEZWFmKCksXG4gICAgdmlkZW86IE1lZGlhRW5naW5lU3RvcmUuaXNWaWRlb0VuYWJsZWQoKSxcbiAgICBzaGFyaW5nOiBBcHBsaWNhdGlvblN0cmVhbWluZ1N0b3JlLmdldEN1cnJlbnRVc2VyQWN0aXZlU3RyZWFtKCkgIT0gbnVsbCxcbiAgICBzb3VuZHM6XG4gICAgICBjaGFubmVsID09IG51bGxcbiAgICAgICAgPyBbXVxuICAgICAgICA6IHNvdW5kcyhndWlsZElkKS5tYXAoKHMpID0+ICh7XG4gICAgICAgICAgICBpZDogcy5zb3VuZElkLFxuICAgICAgICAgICAgZ3VpbGQ6IHMuZ3VpbGRJZCxcbiAgICAgICAgICAgIG5hbWU6IHMubmFtZSxcbiAgICAgICAgICAgIGVtb2ppOiBzLmVtb2ppTmFtZSxcbiAgICAgICAgICAgIGVtb2ppSWQ6IHMuZW1vamlJZFxuICAgICAgICAgIH0pKVxuICB9KTtcbn1cblxubGV0IGZldGNoZWRGb3I6IHN0cmluZyB8IG51bGwgPSBudWxsO1xuXG5mdW5jdGlvbiBwdWJsaXNoKCkge1xuICBjb25zdCBjaGFubmVsID0gdm9pY2VDaGFubmVsKCk7XG4gIC8vIEd1aWxkIHNvdW5kcyBvbmx5IHJlYWNoIHRoZSBzdG9yZSBvbmNlIHNvbWV0aGluZyBhc2tzIGZvciB0aGVtLCB3aGljaFxuICAvLyBpcyBub3JtYWxseSB0aGUgc291bmRib2FyZCBwb3BvdXQgb3BlbmluZy5cbiAgaWYgKGNoYW5uZWwgIT0gbnVsbCAmJiBjaGFubmVsLmlkICE9PSBmZXRjaGVkRm9yKSB7XG4gICAgZmV0Y2hlZEZvciA9IGNoYW5uZWwuaWQ7XG4gICAgbG9va3VwKFwiZmV0Y2hTb3VuZHNcIik/Lih7IGRpc2FibGVBbmFseXRpY3M6IHRydWUgfSk7XG4gIH1cbiAgbmF0aXZlcy5wdWJsaXNoKHNuYXBzaG90KCkpO1xufVxuXG5jb25zdCBLRVlCSU5EUzogUmVjb3JkPHN0cmluZywgc3RyaW5nPiA9IHtcbiAgbXV0ZTogXCJUT0dHTEVfTVVURVwiLFxuICBkZWFmOiBcIlRPR0dMRV9ERUFGRU5cIixcbiAgY2FtZXJhOiBcIlRPR0dMRV9DQU1FUkFcIixcbiAgc2hhcmU6IFwiVE9HR0xFX0dPX0xJVkVfU1RSRUFNSU5HXCJcbn07XG5cbmZ1bmN0aW9uIG9uQ29tbWFuZChsaW5lOiBzdHJpbmcpIHtcbiAgbGV0IG1zZzogeyBjbWQ6IHN0cmluZzsgZ3VpbGQ/OiBzdHJpbmc7IGlkPzogc3RyaW5nIH07XG4gIHRyeSB7XG4gICAgbXNnID0gSlNPTi5wYXJzZShsaW5lKTtcbiAgfSBjYXRjaCB7XG4gICAgcmV0dXJuO1xuICB9XG4gIGlmIChtc2cuY21kIGluIEtFWUJJTkRTKSB7XG4gICAgaWYgKCF0cmlnZ2VyKEtFWUJJTkRTW21zZy5jbWRdKSkgbG9nZ2VyLmVycm9yKFwia2V5YmluZCB0YWJsZSB3YXMgbmV2ZXIgY2FwdHVyZWRcIik7XG4gICAgcmV0dXJuO1xuICB9XG4gIGlmIChtc2cuY21kID09PSBcInNvdW5kXCIpIHtcbiAgICBjb25zdCBjaGFubmVsID0gdm9pY2VDaGFubmVsKCk7XG4gICAgY29uc3Qgc291bmQgPSBTb3VuZGJvYXJkU3RvcmUuZ2V0U291bmQobXNnLmd1aWxkLCBtc2cuaWQpO1xuICAgIGlmIChjaGFubmVsICE9IG51bGwgJiYgc291bmQgIT0gbnVsbCkgbG9va3VwKFwicGxheVNvdW5kXCIpPy4oc291bmQsIGNoYW5uZWwuaWQsIFtdKTtcbiAgfVxufVxuXG5mb3IgKGNvbnN0IHN0b3JlIG9mIFtNZWRpYUVuZ2luZVN0b3JlLCBTZWxlY3RlZENoYW5uZWxTdG9yZSwgU291bmRib2FyZFN0b3JlLCBBcHBsaWNhdGlvblN0cmVhbWluZ1N0b3JlXSkge1xuICBzdG9yZS5hZGRDaGFuZ2VMaXN0ZW5lcihwdWJsaXNoKTtcbn1cbm5hdGl2ZXMuc3RhcnQob25Db21tYW5kKTtcbnB1Ymxpc2goKTtcbiJdLAogICJtYXBwaW5ncyI6ICI7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7QUFBQSwyQkFNTztBQUNQLGlDQUFzQjtBQUN0Qix1Q0FBd0I7QUFFeEIsSUFBTSxTQUFTLFVBQVUsVUFBVSxrQkFBa0I7QUFDckQsSUFBTSxVQUFVLFVBQVUsV0FBVyxrQkFBa0I7QUFZdkQsSUFBTSxnQkFBZ0I7QUFNdEIsSUFBTSxVQUE4QztBQUFBLEVBQ2xELFdBQVcsQ0FBQyw0QkFBNEIsQ0FB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
