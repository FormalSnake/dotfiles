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
function findFavoriteGifs() {
  const cache = import_spacepack_spacepack.default.cache;
  for (const id in cache) {
    const exports = cache[id]?.exports;
    if (exports == null)
      continue;
    for (const key of Object.keys(exports)) {
      const candidate = exports[key];
      if (typeof candidate?.getCurrentValue !== "function")
        continue;
      try {
        const gifs = candidate.getCurrentValue()?.favoriteGifs?.gifs;
        if (gifs != null && typeof gifs === "object")
          return gifs;
      } catch {
      }
    }
  }
  return null;
}
function getRandomFavoriteGifUrl() {
  const gifs = findFavoriteGifs();
  if (gifs == null) {
    console.error("[gifRoulette] could not find a getCurrentValue().favoriteGifs.gifs in the webpack cache");
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
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vLi4vc3JjL2dpZlJvdWxldHRlL3dlYnBhY2tNb2R1bGVzL2VudHJ5cG9pbnQudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImltcG9ydCBDb21tYW5kcyBmcm9tIFwiQG1vb25saWdodC1tb2Qvd3AvY29tbWFuZHNfY29tbWFuZHNcIjtcbmltcG9ydCB7IENvbW1hbmRUeXBlLCBJbnB1dFR5cGUgfSBmcm9tIFwiQG1vb25saWdodC1tb2QvdHlwZXMvY29yZUV4dGVuc2lvbnMvY29tbWFuZHNcIjtcbmltcG9ydCBzcGFjZXBhY2sgZnJvbSBcIkBtb29ubGlnaHQtbW9kL3dwL3NwYWNlcGFja19zcGFjZXBhY2tcIjtcblxuLy8gRGlzY29yZCdzIG1pbmlmaWVyIHJlbmFtZXMgZXZlcnkgZXhwb3J0IGtleSAodGhlIEZyZWNlbmN5VXNlclNldHRpbmdzXG4vLyBhY3Rpb24gY3JlYXRvcnMgZXhwb3J0IHNob3dlZCB1cCBhcyBwbGFpbiBcImJXXCIsIG5vdCBhbnl0aGluZyByZWFkYWJsZSksIHNvXG4vLyB0aGVyZSdzIG5vIHN0YWJsZSBuYW1lIHRvIGxvb2sgdXAuIEluc3RlYWQgdGhpcyBzY2FucyBldmVyeSBhbHJlYWR5LWxvYWRlZFxuLy8gbW9kdWxlJ3MgZXhwb3J0cyBmb3IgYW55dGhpbmcgc2hhcGVkIGxpa2UgYSBGbHV4LXN0eWxlIGFjdGlvbiBjcmVhdG9yXG4vLyAoYSAuZ2V0Q3VycmVudFZhbHVlKCkgZnVuY3Rpb24pIHdob3NlIHJlc29sdmVkIHZhbHVlIGFjdHVhbGx5IGhhc1xuLy8gZmF2b3JpdGVHaWZzLmdpZnMsIHdoaWNoIGlzIHNlbGYtZGVzY3JpYmluZyBhbmQgc3Vydml2ZXMgbWluaWZpY2F0aW9uLlxuZnVuY3Rpb24gZmluZEZhdm9yaXRlR2lmcygpOiBSZWNvcmQ8c3RyaW5nLCB1bmtub3duPiB8IG51bGwge1xuICBjb25zdCBjYWNoZSA9IHNwYWNlcGFjay5jYWNoZTtcbiAgZm9yIChjb25zdCBpZCBpbiBjYWNoZSkge1xuICAgIGNvbnN0IGV4cG9ydHMgPSBjYWNoZVtpZF0/LmV4cG9ydHM7XG4gICAgaWYgKGV4cG9ydHMgPT0gbnVsbCkgY29udGludWU7XG5cbiAgICBmb3IgKGNvbnN0IGtleSBvZiBPYmplY3Qua2V5cyhleHBvcnRzKSkge1xuICAgICAgY29uc3QgY2FuZGlkYXRlID0gZXhwb3J0c1trZXldO1xuICAgICAgaWYgKHR5cGVvZiBjYW5kaWRhdGU/LmdldEN1cnJlbnRWYWx1ZSAhPT0gXCJmdW5jdGlvblwiKSBjb250aW51ZTtcblxuICAgICAgdHJ5IHtcbiAgICAgICAgY29uc3QgZ2lmcyA9IGNhbmRpZGF0ZS5nZXRDdXJyZW50VmFsdWUoKT8uZmF2b3JpdGVHaWZzPy5naWZzO1xuICAgICAgICBpZiAoZ2lmcyAhPSBudWxsICYmIHR5cGVvZiBnaWZzID09PSBcIm9iamVjdFwiKSByZXR1cm4gZ2lmcztcbiAgICAgIH0gY2F0Y2gge1xuICAgICAgICAvLyBTb21lIGFjdGlvbiBjcmVhdG9ycyAoaTE4biBtZXNzYWdlIGxvb2t1cHMpIHRocm93IHdpdGhvdXQgdGhlaXJcbiAgICAgICAgLy8gbm9ybWFsIGNhbGwgY29udGV4dDsgaXJyZWxldmFudCBoZXJlLCBrZWVwIHNjYW5uaW5nLlxuICAgICAgfVxuICAgIH1cbiAgfVxuICByZXR1cm4gbnVsbDtcbn1cblxuLy8gVGhlIGZhdm9yaXRlcyBsaXZlIG9uIERpc2NvcmQncyBGcmVjZW5jeVVzZXJTZXR0aW5ncyBwcm90bywgYWxyZWFkeSBzeW5jZWRcbi8vIHRvIHRoZSBjbGllbnQgYW5kIGNhY2hlZCBpbiBtZW1vcnksIHNvIHRoaXMgaXMgYSBzeW5jaHJvbm91cyBsb2NhbCBsb29rdXBcbi8vIHdpdGggbm8gcGFnaW5hdGlvbjogT2JqZWN0LmtleXMoKSBvbmNlLCB0aGVuIG9uZSBPKDEpIHJhbmRvbSBpbmRleCwgaG93ZXZlclxuLy8gbWFueSB0aG91c2FuZCBHSUZzIGFyZSBmYXZvcml0ZWQuXG5mdW5jdGlvbiBnZXRSYW5kb21GYXZvcml0ZUdpZlVybCgpOiBzdHJpbmcgfCBudWxsIHtcbiAgY29uc3QgZ2lmcyA9IGZpbmRGYXZvcml0ZUdpZnMoKTtcbiAgaWYgKGdpZnMgPT0gbnVsbCkge1xuICAgIGNvbnNvbGUuZXJyb3IoXCJbZ2lmUm91bGV0dGVdIGNvdWxkIG5vdCBmaW5kIGEgZ2V0Q3VycmVudFZhbHVlKCkuZmF2b3JpdGVHaWZzLmdpZnMgaW4gdGhlIHdlYnBhY2sgY2FjaGVcIik7XG4gICAgcmV0dXJuIG51bGw7XG4gIH1cblxuICBjb25zdCB1cmxzID0gT2JqZWN0LmtleXMoZ2lmcyk7XG4gIGlmICh1cmxzLmxlbmd0aCA9PT0gMCkge1xuICAgIGNvbnNvbGUud2FybihcIltnaWZSb3VsZXR0ZV0gbm8gZmF2b3JpdGVkIEdJRnNcIik7XG4gICAgcmV0dXJuIG51bGw7XG4gIH1cblxuICByZXR1cm4gdXJsc1tNYXRoLmZsb29yKE1hdGgucmFuZG9tKCkgKiB1cmxzLmxlbmd0aCldO1xufVxuXG5Db21tYW5kcy5yZWdpc3RlckNvbW1hbmQoe1xuICB0eXBlOiBDb21tYW5kVHlwZS5DSEFULFxuICBpbnB1dFR5cGU6IElucHV0VHlwZS5CVUlMVF9JTl9URVhULFxuICBpZDogXCJnaWZyb3VsZXR0ZVwiLFxuICBkZXNjcmlwdGlvbjogXCJTZW5kcyBhIHJhbmRvbSBmYXZvcml0ZWQgR0lGXCIsXG4gIC8vIG9wdGlvbnMgbXVzdCBiZSBhbiBleHBsaWNpdCBlbXB0eSBhcnJheSwgbm90IG9taXR0ZWQ6IERpc2NvcmQncyBvd25cbiAgLy8gY29tbWFuZC1zdWJtaXQgaGFuZGxpbmcgdHJlYXRzIGEgY29tbWFuZCB3aXRoIG9wdGlvbnM6IHVuZGVmaW5lZCBhc1xuICAvLyB1bmNvbmZpcm1lZCBhbmQgZmFsbHMgYmFjayB0byBzZW5kaW5nIHRoZSB0eXBlZCB0ZXh0IGxpdGVyYWxseS5cbiAgb3B0aW9uczogW10sXG4gIC8vIFJldHVybmluZyBub3RoaW5nIChyYXRoZXIgdGhhbiB7IGNvbnRlbnQ6IC4uLiB9KSBtZWFucyBubyBtZXNzYWdlIGlzXG4gIC8vIHNlbnQgd2hlbiB0aGlzIGZhaWxzLCBpbnN0ZWFkIG9mIHBhc3RpbmcgYW4gZXJyb3IgaW50byB0aGUgY2hhbm5lbC5cbiAgZXhlY3V0ZTogKCkgPT4ge1xuICAgIGNvbnN0IHVybCA9IGdldFJhbmRvbUZhdm9yaXRlR2lmVXJsKCk7XG4gICAgaWYgKHVybCA9PSBudWxsKSByZXR1cm4gdW5kZWZpbmVkO1xuICAgIHJldHVybiB7IGNvbnRlbnQ6IHVybCB9O1xuICB9XG59KTtcbiJdLAogICJtYXBwaW5ncyI6ICI7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7QUFBQSwrQkFBcUI7QUFFckIsaUNBQXNCO0FBUXRCLFNBQVMsbUJBQW1EO0FBQzFELFFBQU0sUUFBUSwyQkFBQUEsUUFBVTtBQUN4QixhQUFXLE1BQU0sT0FBTztBQUN0QixVQUFNLFVBQVUsTUFBTSxFQUFFLEdBQUc7QUFDM0IsUUFBSSxXQUFXO0FBQU07QUFFckIsZUFBVyxPQUFPLE9BQU8sS0FBSyxPQUFPLEdBQUc7QUFDdEMsWUFBTSxZQUFZLFFBQVEsR0FBRztBQUM3QixVQUFJLE9BQU8sV0FBVyxvQkFBb0I7QUFBWTtBQUV0RCxVQUFJO0FBQ0YsY0FBTSxPQUFPLFVBQVUsZ0JBQWdCLEdBQUcsY0FBYztBQUN4RCxZQUFJLFFBQVEsUUFBUSxPQUFPLFNBQVM7QUFBVSxpQkFBTztBQUFBLE1BQ3ZELFFBQVE7QUFBQSxNQUdSO0FBQUEsSUFDRjtBQUFBLEVBQ0Y7QUFDQSxTQUFPO0FBQ1Q7QUFNQSxTQUFTLDBCQUF5QztBQUNoRCxRQUFNLE9BQU8saUJBQWlCO0FBQzlCLE1BQUksUUFBUSxNQUFNO0FBQ2hCLFlBQVEsTUFBTSx5RkFBeUY7QUFDdkcsV0FBTztBQUFBLEVBQ1Q7QUFFQSxRQUFNLE9BQU8sT0FBTyxLQUFLLElBQUk7QUFDN0IsTUFBSSxLQUFLLFdBQVcsR0FBRztBQUNyQixZQUFRLEtBQUssaUNBQWlDO0FBQzlDLFdBQU87QUFBQSxFQUNUO0FBRUEsU0FBTyxLQUFLLEtBQUssTUFBTSxLQUFLLE9BQU8sSUFBSSxLQUFLLE1BQU0sQ0FBQztBQUNyRDtBQUVBLHlCQUFBQyxRQUFTLGdCQUFnQjtBQUFBLEVBQ3ZCO0FBQUEsRUFDQTtBQUFBLEVBQ0EsSUFBSTtBQUFBLEVBQ0osYUFBYTtBQUFBO0FBQUE7QUFBQTtBQUFBLEVBSWIsU0FBUyxDQUFDO0FBQUE7QUFBQTtBQUFBLEVBR1YsU0FBUyxNQUFNO0FBQ2IsVUFBTSxNQUFNLHdCQUF3QjtBQUNwQyxRQUFJLE9BQU87QUFBTSxhQUFPO0FBQ3hCLFdBQU8sRUFBRSxTQUFTLElBQUk7QUFBQSxFQUN4QjtBQUNGLENBQUM7IiwKICAibmFtZXMiOiBbInNwYWNlcGFjayIsICJDb21tYW5kcyJdCn0K
