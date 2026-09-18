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
function findFrecencyActionCreators() {
  const cache = import_spacepack_spacepack.default.cache;
  for (const id in cache) {
    const exports = cache[id]?.exports;
    if (exports?.FrecencyUserSettingsActionCreators != null) {
      return exports.FrecencyUserSettingsActionCreators;
    }
    if (exports?.default?.FrecencyUserSettingsActionCreators != null) {
      return exports.default.FrecencyUserSettingsActionCreators;
    }
  }
  return null;
}
function getRandomFavoriteGifUrl() {
  const actionCreators = findFrecencyActionCreators();
  if (actionCreators == null) {
    console.error("[gifRoulette] could not find FrecencyUserSettingsActionCreators in the webpack cache");
    return null;
  }
  const gifs = actionCreators.getCurrentValue?.()?.favoriteGifs?.gifs;
  if (gifs == null) {
    console.error("[gifRoulette] FrecencyUserSettings has no favoriteGifs.gifs", actionCreators.getCurrentValue?.());
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
  // Returning nothing (rather than { content: ... }) means no message is
  // sent when this fails, instead of pasting an error into the channel.
  execute: () => {
    const url = getRandomFavoriteGifUrl();
    if (url == null)
      return void 0;
    return { content: url };
  }
});
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vLi4vc3JjL2dpZlJvdWxldHRlL3dlYnBhY2tNb2R1bGVzL2VudHJ5cG9pbnQudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImltcG9ydCBDb21tYW5kcyBmcm9tIFwiQG1vb25saWdodC1tb2Qvd3AvY29tbWFuZHNfY29tbWFuZHNcIjtcbmltcG9ydCB7IENvbW1hbmRUeXBlLCBJbnB1dFR5cGUgfSBmcm9tIFwiQG1vb25saWdodC1tb2QvdHlwZXMvY29yZUV4dGVuc2lvbnMvY29tbWFuZHNcIjtcbmltcG9ydCBzcGFjZXBhY2sgZnJvbSBcIkBtb29ubGlnaHQtbW9kL3dwL3NwYWNlcGFja19zcGFjZXBhY2tcIjtcblxuLy8gTmFtZWQgZXhwb3J0cyBzdXJ2aXZlIERpc2NvcmQncyBtaW5pZmllciAob25seSBsb2NhbCB2YXJpYWJsZSBuYW1lcyBnZXRcbi8vIG1hbmdsZWQpLCBzbyBzY2FubmluZyB0aGUgYWxyZWFkeS1yZXF1aXJlZCBtb2R1bGUgY2FjaGUgZm9yIHRoaXMgZXhhY3Qga2V5XG4vLyBpcyBtb3JlIHJlbGlhYmxlIHRoYW4gbWF0Y2hpbmcgYWdhaW5zdCBtaW5pZmllZCBzb3VyY2UgdmlhIGZpbmRCeUNvZGUuXG5mdW5jdGlvbiBmaW5kRnJlY2VuY3lBY3Rpb25DcmVhdG9ycygpOiBhbnkge1xuICBjb25zdCBjYWNoZSA9IHNwYWNlcGFjay5jYWNoZTtcbiAgZm9yIChjb25zdCBpZCBpbiBjYWNoZSkge1xuICAgIGNvbnN0IGV4cG9ydHMgPSBjYWNoZVtpZF0/LmV4cG9ydHM7XG4gICAgaWYgKGV4cG9ydHM/LkZyZWNlbmN5VXNlclNldHRpbmdzQWN0aW9uQ3JlYXRvcnMgIT0gbnVsbCkge1xuICAgICAgcmV0dXJuIGV4cG9ydHMuRnJlY2VuY3lVc2VyU2V0dGluZ3NBY3Rpb25DcmVhdG9ycztcbiAgICB9XG4gICAgaWYgKGV4cG9ydHM/LmRlZmF1bHQ/LkZyZWNlbmN5VXNlclNldHRpbmdzQWN0aW9uQ3JlYXRvcnMgIT0gbnVsbCkge1xuICAgICAgcmV0dXJuIGV4cG9ydHMuZGVmYXVsdC5GcmVjZW5jeVVzZXJTZXR0aW5nc0FjdGlvbkNyZWF0b3JzO1xuICAgIH1cbiAgfVxuICByZXR1cm4gbnVsbDtcbn1cblxuLy8gVGhlIGZhdm9yaXRlcyBsaXZlIG9uIERpc2NvcmQncyBGcmVjZW5jeVVzZXJTZXR0aW5ncyBwcm90bywgYWxyZWFkeSBzeW5jZWRcbi8vIHRvIHRoZSBjbGllbnQgYW5kIGNhY2hlZCBpbiBtZW1vcnksIHNvIHRoaXMgaXMgYSBzeW5jaHJvbm91cyBsb2NhbCBsb29rdXBcbi8vIHdpdGggbm8gcGFnaW5hdGlvbjogT2JqZWN0LmtleXMoKSBvbmNlLCB0aGVuIG9uZSBPKDEpIHJhbmRvbSBpbmRleCwgaG93ZXZlclxuLy8gbWFueSB0aG91c2FuZCBHSUZzIGFyZSBmYXZvcml0ZWQuXG5mdW5jdGlvbiBnZXRSYW5kb21GYXZvcml0ZUdpZlVybCgpOiBzdHJpbmcgfCBudWxsIHtcbiAgY29uc3QgYWN0aW9uQ3JlYXRvcnMgPSBmaW5kRnJlY2VuY3lBY3Rpb25DcmVhdG9ycygpO1xuICBpZiAoYWN0aW9uQ3JlYXRvcnMgPT0gbnVsbCkge1xuICAgIGNvbnNvbGUuZXJyb3IoXCJbZ2lmUm91bGV0dGVdIGNvdWxkIG5vdCBmaW5kIEZyZWNlbmN5VXNlclNldHRpbmdzQWN0aW9uQ3JlYXRvcnMgaW4gdGhlIHdlYnBhY2sgY2FjaGVcIik7XG4gICAgcmV0dXJuIG51bGw7XG4gIH1cblxuICBjb25zdCBnaWZzID0gYWN0aW9uQ3JlYXRvcnMuZ2V0Q3VycmVudFZhbHVlPy4oKT8uZmF2b3JpdGVHaWZzPy5naWZzO1xuICBpZiAoZ2lmcyA9PSBudWxsKSB7XG4gICAgY29uc29sZS5lcnJvcihcIltnaWZSb3VsZXR0ZV0gRnJlY2VuY3lVc2VyU2V0dGluZ3MgaGFzIG5vIGZhdm9yaXRlR2lmcy5naWZzXCIsIGFjdGlvbkNyZWF0b3JzLmdldEN1cnJlbnRWYWx1ZT8uKCkpO1xuICAgIHJldHVybiBudWxsO1xuICB9XG5cbiAgY29uc3QgdXJscyA9IE9iamVjdC5rZXlzKGdpZnMpO1xuICBpZiAodXJscy5sZW5ndGggPT09IDApIHtcbiAgICBjb25zb2xlLndhcm4oXCJbZ2lmUm91bGV0dGVdIG5vIGZhdm9yaXRlZCBHSUZzXCIpO1xuICAgIHJldHVybiBudWxsO1xuICB9XG5cbiAgcmV0dXJuIHVybHNbTWF0aC5mbG9vcihNYXRoLnJhbmRvbSgpICogdXJscy5sZW5ndGgpXTtcbn1cblxuQ29tbWFuZHMucmVnaXN0ZXJDb21tYW5kKHtcbiAgdHlwZTogQ29tbWFuZFR5cGUuQ0hBVCxcbiAgaW5wdXRUeXBlOiBJbnB1dFR5cGUuQlVJTFRfSU5fVEVYVCxcbiAgaWQ6IFwiZ2lmcm91bGV0dGVcIixcbiAgZGVzY3JpcHRpb246IFwiU2VuZHMgYSByYW5kb20gZmF2b3JpdGVkIEdJRlwiLFxuICAvLyBSZXR1cm5pbmcgbm90aGluZyAocmF0aGVyIHRoYW4geyBjb250ZW50OiAuLi4gfSkgbWVhbnMgbm8gbWVzc2FnZSBpc1xuICAvLyBzZW50IHdoZW4gdGhpcyBmYWlscywgaW5zdGVhZCBvZiBwYXN0aW5nIGFuIGVycm9yIGludG8gdGhlIGNoYW5uZWwuXG4gIGV4ZWN1dGU6ICgpID0+IHtcbiAgICBjb25zdCB1cmwgPSBnZXRSYW5kb21GYXZvcml0ZUdpZlVybCgpO1xuICAgIGlmICh1cmwgPT0gbnVsbCkgcmV0dXJuIHVuZGVmaW5lZDtcbiAgICByZXR1cm4geyBjb250ZW50OiB1cmwgfTtcbiAgfVxufSk7XG4iXSwKICAibWFwcGluZ3MiOiAiOzs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O0FBQUEsK0JBQXFCO0FBRXJCLGlDQUFzQjtBQUt0QixTQUFTLDZCQUFrQztBQUN6QyxRQUFNLFFBQVEsMkJBQUFBLFFBQVU7QUFDeEIsYUFBVyxNQUFNLE9BQU87QUFDdEIsVUFBTSxVQUFVLE1BQU0sRUFBRSxHQUFHO0FBQzNCLFFBQUksU0FBUyxzQ0FBc0MsTUFBTTtBQUN2RCxhQUFPLFFBQVE7QUFBQSxJQUNqQjtBQUNBLFFBQUksU0FBUyxTQUFTLHNDQUFzQyxNQUFNO0FBQ2hFLGFBQU8sUUFBUSxRQUFRO0FBQUEsSUFDekI7QUFBQSxFQUNGO0FBQ0EsU0FBTztBQUNUO0FBTUEsU0FBUywwQkFBeUM7QUFDaEQsUUFBTSxpQkFBaUIsMkJBQTJCO0FBQ2xELE1BQUksa0JBQWtCLE1BQU07QUFDMUIsWUFBUSxNQUFNLHNGQUFzRjtBQUNwRyxXQUFPO0FBQUEsRUFDVDtBQUVBLFFBQU0sT0FBTyxlQUFlLGtCQUFrQixHQUFHLGNBQWM7QUFDL0QsTUFBSSxRQUFRLE1BQU07QUFDaEIsWUFBUSxNQUFNLCtEQUErRCxlQUFlLGtCQUFrQixDQUFDO0FBQy9HLFdBQU87QUFBQSxFQUNUO0FBRUEsUUFBTSxPQUFPLE9BQU8sS0FBSyxJQUFJO0FBQzdCLE1BQUksS0FBSyxXQUFXLEdBQUc7QUFDckIsWUFBUSxLQUFLLGlDQUFpQztBQUM5QyxXQUFPO0FBQUEsRUFDVDtBQUVBLFNBQU8sS0FBSyxLQUFLLE1BQU0sS0FBSyxPQUFPLElBQUksS0FBSyxNQUFNLENBQUM7QUFDckQ7QUFFQSx5QkFBQUMsUUFBUyxnQkFBZ0I7QUFBQSxFQUN2QjtBQUFBLEVBQ0E7QUFBQSxFQUNBLElBQUk7QUFBQSxFQUNKLGFBQWE7QUFBQTtBQUFBO0FBQUEsRUFHYixTQUFTLE1BQU07QUFDYixVQUFNLE1BQU0sd0JBQXdCO0FBQ3BDLFFBQUksT0FBTztBQUFNLGFBQU87QUFDeEIsV0FBTyxFQUFFLFNBQVMsSUFBSTtBQUFBLEVBQ3hCO0FBQ0YsQ0FBQzsiLAogICJuYW1lcyI6IFsic3BhY2VwYWNrIiwgIkNvbW1hbmRzIl0KfQo=
