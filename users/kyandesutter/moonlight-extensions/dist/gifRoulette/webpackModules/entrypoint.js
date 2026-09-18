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

// src/gifRoulette/webpackModules/entrypoint.ts
var import_commands_commands = __toESM(require("commands_commands"));
var import_spacepack_spacepack = __toESM(require("spacepack_spacepack"));
function extractFavoriteGifs(candidate) {
  if (typeof candidate?.getCurrentValue !== "function")
    return null;
  try {
    const gifs = candidate.getCurrentValue()?.favoriteGifs?.gifs;
    return gifs != null && typeof gifs === "object" ? gifs : null;
  } catch {
    return null;
  }
}
function findFavoriteGifs() {
  const cache = import_spacepack_spacepack.default.cache;
  for (const id in cache) {
    const exports = cache[id]?.exports;
    if (exports == null)
      continue;
    const gifs = extractFavoriteGifs(exports.FrecencyUserSettingsActionCreators) ?? extractFavoriteGifs(exports.default?.FrecencyUserSettingsActionCreators);
    if (gifs != null)
      return gifs;
  }
  return null;
}
function getRandomFavoriteGifUrl() {
  const gifs = findFavoriteGifs();
  if (gifs == null) {
    console.error("[gifRoulette] could not find a validated FrecencyUserSettingsActionCreators.getCurrentValue().favoriteGifs.gifs in the webpack cache");
    return null;
  }
  const urls = Object.keys(gifs);
  if (urls.length === 0) {
    console.warn("[gifRoulette] no favorited GIFs");
    return null;
  }
  return urls[Math.floor(Math.random() * urls.length)];
}
import_commands_commands.default.registerCommand({
  type: 1 /* CHAT */,
  inputType: 1 /* BUILT_IN_TEXT */,
  id: "gifroulette",
  description: "Sends a random favorited GIF",
  // options must be an explicit empty array, not omitted: Discord's own
  // command-submit handling treats a command with options: undefined as
  // unconfirmed and falls back to sending the typed text literally.
  options: [],
  // Returning nothing (rather than { content: ... }) means no message is
  // sent when this fails, instead of pasting an error into the channel.
  execute: () => {
    const url = getRandomFavoriteGifUrl();
    if (url == null)
      return void 0;
    return { content: url };
  }
});
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vLi4vc3JjL2dpZlJvdWxldHRlL3dlYnBhY2tNb2R1bGVzL2VudHJ5cG9pbnQudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImltcG9ydCBDb21tYW5kcyBmcm9tIFwiQG1vb25saWdodC1tb2Qvd3AvY29tbWFuZHNfY29tbWFuZHNcIjtcbmltcG9ydCB7IENvbW1hbmRUeXBlLCBJbnB1dFR5cGUgfSBmcm9tIFwiQG1vb25saWdodC1tb2QvdHlwZXMvY29yZUV4dGVuc2lvbnMvY29tbWFuZHNcIjtcbmltcG9ydCBzcGFjZXBhY2sgZnJvbSBcIkBtb29ubGlnaHQtbW9kL3dwL3NwYWNlcGFja19zcGFjZXBhY2tcIjtcblxuLy8gTmFtZWQgZXhwb3J0cyBzdXJ2aXZlIERpc2NvcmQncyBtaW5pZmllciAob25seSBsb2NhbCB2YXJpYWJsZSBuYW1lcyBnZXRcbi8vIG1hbmdsZWQpLCBzbyBzY2FubmluZyB0aGUgYWxyZWFkeS1yZXF1aXJlZCBtb2R1bGUgY2FjaGUgZm9yIHRoaXMgZXhhY3Qga2V5XG4vLyBpcyBtb3JlIHJlbGlhYmxlIHRoYW4gbWF0Y2hpbmcgYWdhaW5zdCBtaW5pZmllZCBzb3VyY2UgdmlhIGZpbmRCeUNvZGUuXG4vL1xuLy8gQSBwbGFpbiBgIT0gbnVsbGAgY2hlY2sgb24gdGhlIHByb3BlcnR5IGlzbid0IGVub3VnaDogc2V2ZXJhbCB3ZWJwYWNrXG4vLyBtb2R1bGVzIChpMThuIHN0cmluZyBjYXRhbG9ncykgZXhwb3J0IGNhdGNoLWFsbCBQcm94aWVzIHRoYXQgcmV0dXJuIGFcbi8vIHRydXRoeSB2YWx1ZSBmb3IgKmFueSoga2V5LCBpbmNsdWRpbmcgdGhpcyBvbmUsIHNvIGV2ZXJ5IGNhbmRpZGF0ZSBoYXMgdG9cbi8vIGJlIHZhbGlkYXRlZCBieSBzaGFwZSAoYSByZWFsIGdldEN1cnJlbnRWYWx1ZSgpIGNhbGwgdGhhdCByZXNvbHZlcyB0byBhXG4vLyBmYXZvcml0ZUdpZnMuZ2lmcyBtYXApIGJlZm9yZSBiZWluZyBhY2NlcHRlZC5cbmZ1bmN0aW9uIGV4dHJhY3RGYXZvcml0ZUdpZnMoY2FuZGlkYXRlOiBhbnkpOiBSZWNvcmQ8c3RyaW5nLCB1bmtub3duPiB8IG51bGwge1xuICBpZiAodHlwZW9mIGNhbmRpZGF0ZT8uZ2V0Q3VycmVudFZhbHVlICE9PSBcImZ1bmN0aW9uXCIpIHJldHVybiBudWxsO1xuXG4gIHRyeSB7XG4gICAgY29uc3QgZ2lmcyA9IGNhbmRpZGF0ZS5nZXRDdXJyZW50VmFsdWUoKT8uZmF2b3JpdGVHaWZzPy5naWZzO1xuICAgIHJldHVybiBnaWZzICE9IG51bGwgJiYgdHlwZW9mIGdpZnMgPT09IFwib2JqZWN0XCIgPyBnaWZzIDogbnVsbDtcbiAgfSBjYXRjaCB7XG4gICAgcmV0dXJuIG51bGw7XG4gIH1cbn1cblxuZnVuY3Rpb24gZmluZEZhdm9yaXRlR2lmcygpOiBSZWNvcmQ8c3RyaW5nLCB1bmtub3duPiB8IG51bGwge1xuICBjb25zdCBjYWNoZSA9IHNwYWNlcGFjay5jYWNoZTtcbiAgZm9yIChjb25zdCBpZCBpbiBjYWNoZSkge1xuICAgIGNvbnN0IGV4cG9ydHMgPSBjYWNoZVtpZF0/LmV4cG9ydHM7XG4gICAgaWYgKGV4cG9ydHMgPT0gbnVsbCkgY29udGludWU7XG5cbiAgICBjb25zdCBnaWZzID1cbiAgICAgIGV4dHJhY3RGYXZvcml0ZUdpZnMoZXhwb3J0cy5GcmVjZW5jeVVzZXJTZXR0aW5nc0FjdGlvbkNyZWF0b3JzKSA/P1xuICAgICAgZXh0cmFjdEZhdm9yaXRlR2lmcyhleHBvcnRzLmRlZmF1bHQ/LkZyZWNlbmN5VXNlclNldHRpbmdzQWN0aW9uQ3JlYXRvcnMpO1xuICAgIGlmIChnaWZzICE9IG51bGwpIHJldHVybiBnaWZzO1xuICB9XG4gIHJldHVybiBudWxsO1xufVxuXG4vLyBUaGUgZmF2b3JpdGVzIGxpdmUgb24gRGlzY29yZCdzIEZyZWNlbmN5VXNlclNldHRpbmdzIHByb3RvLCBhbHJlYWR5IHN5bmNlZFxuLy8gdG8gdGhlIGNsaWVudCBhbmQgY2FjaGVkIGluIG1lbW9yeSwgc28gdGhpcyBpcyBhIHN5bmNocm9ub3VzIGxvY2FsIGxvb2t1cFxuLy8gd2l0aCBubyBwYWdpbmF0aW9uOiBPYmplY3Qua2V5cygpIG9uY2UsIHRoZW4gb25lIE8oMSkgcmFuZG9tIGluZGV4LCBob3dldmVyXG4vLyBtYW55IHRob3VzYW5kIEdJRnMgYXJlIGZhdm9yaXRlZC5cbmZ1bmN0aW9uIGdldFJhbmRvbUZhdm9yaXRlR2lmVXJsKCk6IHN0cmluZyB8IG51bGwge1xuICBjb25zdCBnaWZzID0gZmluZEZhdm9yaXRlR2lmcygpO1xuICBpZiAoZ2lmcyA9PSBudWxsKSB7XG4gICAgY29uc29sZS5lcnJvcihcIltnaWZSb3VsZXR0ZV0gY291bGQgbm90IGZpbmQgYSB2YWxpZGF0ZWQgRnJlY2VuY3lVc2VyU2V0dGluZ3NBY3Rpb25DcmVhdG9ycy5nZXRDdXJyZW50VmFsdWUoKS5mYXZvcml0ZUdpZnMuZ2lmcyBpbiB0aGUgd2VicGFjayBjYWNoZVwiKTtcbiAgICByZXR1cm4gbnVsbDtcbiAgfVxuXG4gIGNvbnN0IHVybHMgPSBPYmplY3Qua2V5cyhnaWZzKTtcbiAgaWYgKHVybHMubGVuZ3RoID09PSAwKSB7XG4gICAgY29uc29sZS53YXJuKFwiW2dpZlJvdWxldHRlXSBubyBmYXZvcml0ZWQgR0lGc1wiKTtcbiAgICByZXR1cm4gbnVsbDtcbiAgfVxuXG4gIHJldHVybiB1cmxzW01hdGguZmxvb3IoTWF0aC5yYW5kb20oKSAqIHVybHMubGVuZ3RoKV07XG59XG5cbkNvbW1hbmRzLnJlZ2lzdGVyQ29tbWFuZCh7XG4gIHR5cGU6IENvbW1hbmRUeXBlLkNIQVQsXG4gIGlucHV0VHlwZTogSW5wdXRUeXBlLkJVSUxUX0lOX1RFWFQsXG4gIGlkOiBcImdpZnJvdWxldHRlXCIsXG4gIGRlc2NyaXB0aW9uOiBcIlNlbmRzIGEgcmFuZG9tIGZhdm9yaXRlZCBHSUZcIixcbiAgLy8gb3B0aW9ucyBtdXN0IGJlIGFuIGV4cGxpY2l0IGVtcHR5IGFycmF5LCBub3Qgb21pdHRlZDogRGlzY29yZCdzIG93blxuICAvLyBjb21tYW5kLXN1Ym1pdCBoYW5kbGluZyB0cmVhdHMgYSBjb21tYW5kIHdpdGggb3B0aW9uczogdW5kZWZpbmVkIGFzXG4gIC8vIHVuY29uZmlybWVkIGFuZCBmYWxscyBiYWNrIHRvIHNlbmRpbmcgdGhlIHR5cGVkIHRleHQgbGl0ZXJhbGx5LlxuICBvcHRpb25zOiBbXSxcbiAgLy8gUmV0dXJuaW5nIG5vdGhpbmcgKHJhdGhlciB0aGFuIHsgY29udGVudDogLi4uIH0pIG1lYW5zIG5vIG1lc3NhZ2UgaXNcbiAgLy8gc2VudCB3aGVuIHRoaXMgZmFpbHMsIGluc3RlYWQgb2YgcGFzdGluZyBhbiBlcnJvciBpbnRvIHRoZSBjaGFubmVsLlxuICBleGVjdXRlOiAoKSA9PiB7XG4gICAgY29uc3QgdXJsID0gZ2V0UmFuZG9tRmF2b3JpdGVHaWZVcmwoKTtcbiAgICBpZiAodXJsID09IG51bGwpIHJldHVybiB1bmRlZmluZWQ7XG4gICAgcmV0dXJuIHsgY29udGVudDogdXJsIH07XG4gIH1cbn0pO1xuIl0sCiAgIm1hcHBpbmdzIjogIjs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7OztBQUFBLCtCQUFxQjtBQUVyQixpQ0FBc0I7QUFXdEIsU0FBUyxvQkFBb0IsV0FBZ0Q7QUFDM0UsTUFBSSxPQUFPLFdBQVcsb0JBQW9CO0FBQVksV0FBTztBQUU3RCxNQUFJO0FBQ0YsVUFBTSxPQUFPLFVBQVUsZ0JBQWdCLEdBQUcsY0FBYztBQUN4RCxXQUFPLFFBQVEsUUFBUSxPQUFPLFNBQVMsV0FBVyxPQUFPO0FBQUEsRUFDM0QsUUFBUTtBQUNOLFdBQU87QUFBQSxFQUNUO0FBQ0Y7QUFFQSxTQUFTLG1CQUFtRDtBQUMxRCxRQUFNLFFBQVEsMkJBQUFBLFFBQVU7QUFDeEIsYUFBVyxNQUFNLE9BQU87QUFDdEIsVUFBTSxVQUFVLE1BQU0sRUFBRSxHQUFHO0FBQzNCLFFBQUksV0FBVztBQUFNO0FBRXJCLFVBQU0sT0FDSixvQkFBb0IsUUFBUSxrQ0FBa0MsS0FDOUQsb0JBQW9CLFFBQVEsU0FBUyxrQ0FBa0M7QUFDekUsUUFBSSxRQUFRO0FBQU0sYUFBTztBQUFBLEVBQzNCO0FBQ0EsU0FBTztBQUNUO0FBTUEsU0FBUywwQkFBeUM7QUFDaEQsUUFBTSxPQUFPLGlCQUFpQjtBQUM5QixNQUFJLFFBQVEsTUFBTTtBQUNoQixZQUFRLE1BQU0sc0lBQXNJO0FBQ3BKLFdBQU87QUFBQSxFQUNUO0FBRUEsUUFBTSxPQUFPLE9BQU8sS0FBSyxJQUFJO0FBQzdCLE1BQUksS0FBSyxXQUFXLEdBQUc7QUFDckIsWUFBUSxLQUFLLGlDQUFpQztBQUM5QyxXQUFPO0FBQUEsRUFDVDtBQUVBLFNBQU8sS0FBSyxLQUFLLE1BQU0sS0FBSyxPQUFPLElBQUksS0FBSyxNQUFNLENBQUM7QUFDckQ7QUFFQSx5QkFBQUMsUUFBUyxnQkFBZ0I7QUFBQSxFQUN2QjtBQUFBLEVBQ0E7QUFBQSxFQUNBLElBQUk7QUFBQSxFQUNKLGFBQWE7QUFBQTtBQUFBO0FBQUE7QUFBQSxFQUliLFNBQVMsQ0FBQztBQUFBO0FBQUE7QUFBQSxFQUdWLFNBQVMsTUFBTTtBQUNiLFVBQU0sTUFBTSx3QkFBd0I7QUFDcEMsUUFBSSxPQUFPO0FBQU0sYUFBTztBQUN4QixXQUFPLEVBQUUsU0FBUyxJQUFJO0FBQUEsRUFDeEI7QUFDRixDQUFDOyIsCiAgIm5hbWVzIjogWyJzcGFjZXBhY2siLCAiQ29tbWFuZHMiXQp9Cg==
