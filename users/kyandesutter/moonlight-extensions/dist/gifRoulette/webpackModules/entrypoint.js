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
function getRandomFavoriteGifUrl() {
  const modules = import_spacepack_spacepack.default.findByCode('"FrecencyUserSettings"');
  for (const { exports } of modules) {
    const actionCreators = import_spacepack_spacepack.default.findObjectFromKey(exports, "FrecencyUserSettingsActionCreators");
    const gifs = actionCreators?.FrecencyUserSettingsActionCreators?.getCurrentValue?.()?.favoriteGifs?.gifs;
    if (gifs == null)
      continue;
    const urls = Object.keys(gifs);
    if (urls.length === 0)
      return null;
    return urls[Math.floor(Math.random() * urls.length)];
  }
  return null;
}
import_commands_commands.default.registerCommand({
  type: 1 /* CHAT */,
  inputType: 1 /* BUILT_IN_TEXT */,
  id: "gifroulette",
  description: "Sends a random favorited GIF",
  execute: () => {
    const url = getRandomFavoriteGifUrl();
    return { content: url ?? "No favorited GIFs found." };
  }
});
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vLi4vc3JjL2dpZlJvdWxldHRlL3dlYnBhY2tNb2R1bGVzL2VudHJ5cG9pbnQudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImltcG9ydCBDb21tYW5kcyBmcm9tIFwiQG1vb25saWdodC1tb2Qvd3AvY29tbWFuZHNfY29tbWFuZHNcIjtcbmltcG9ydCB7IENvbW1hbmRUeXBlLCBJbnB1dFR5cGUgfSBmcm9tIFwiQG1vb25saWdodC1tb2QvdHlwZXMvY29yZUV4dGVuc2lvbnMvY29tbWFuZHNcIjtcbmltcG9ydCBzcGFjZXBhY2sgZnJvbSBcIkBtb29ubGlnaHQtbW9kL3dwL3NwYWNlcGFja19zcGFjZXBhY2tcIjtcblxuLy8gVGhlIGZhdm9yaXRlcyBsaXZlIG9uIERpc2NvcmQncyBGcmVjZW5jeVVzZXJTZXR0aW5ncyBwcm90bywgYWxyZWFkeSBzeW5jZWRcbi8vIHRvIHRoZSBjbGllbnQgYW5kIGNhY2hlZCBpbiBtZW1vcnksIHNvIHRoaXMgaXMgYSBzeW5jaHJvbm91cyBsb2NhbCBsb29rdXBcbi8vIHdpdGggbm8gcGFnaW5hdGlvbjogT2JqZWN0LmtleXMoKSBvbmNlLCB0aGVuIG9uZSBPKDEpIHJhbmRvbSBpbmRleCwgaG93ZXZlclxuLy8gbWFueSB0aG91c2FuZCBHSUZzIGFyZSBmYXZvcml0ZWQuXG5mdW5jdGlvbiBnZXRSYW5kb21GYXZvcml0ZUdpZlVybCgpOiBzdHJpbmcgfCBudWxsIHtcbiAgY29uc3QgbW9kdWxlcyA9IHNwYWNlcGFjay5maW5kQnlDb2RlKCdcIkZyZWNlbmN5VXNlclNldHRpbmdzXCInKTtcblxuICBmb3IgKGNvbnN0IHsgZXhwb3J0cyB9IG9mIG1vZHVsZXMpIHtcbiAgICBjb25zdCBhY3Rpb25DcmVhdG9ycyA9IHNwYWNlcGFjay5maW5kT2JqZWN0RnJvbUtleShleHBvcnRzLCBcIkZyZWNlbmN5VXNlclNldHRpbmdzQWN0aW9uQ3JlYXRvcnNcIik7XG4gICAgY29uc3QgZ2lmcyA9IGFjdGlvbkNyZWF0b3JzPy5GcmVjZW5jeVVzZXJTZXR0aW5nc0FjdGlvbkNyZWF0b3JzPy5nZXRDdXJyZW50VmFsdWU/LigpPy5mYXZvcml0ZUdpZnM/LmdpZnM7XG4gICAgaWYgKGdpZnMgPT0gbnVsbCkgY29udGludWU7XG5cbiAgICBjb25zdCB1cmxzID0gT2JqZWN0LmtleXMoZ2lmcyk7XG4gICAgaWYgKHVybHMubGVuZ3RoID09PSAwKSByZXR1cm4gbnVsbDtcbiAgICByZXR1cm4gdXJsc1tNYXRoLmZsb29yKE1hdGgucmFuZG9tKCkgKiB1cmxzLmxlbmd0aCldO1xuICB9XG5cbiAgcmV0dXJuIG51bGw7XG59XG5cbkNvbW1hbmRzLnJlZ2lzdGVyQ29tbWFuZCh7XG4gIHR5cGU6IENvbW1hbmRUeXBlLkNIQVQsXG4gIGlucHV0VHlwZTogSW5wdXRUeXBlLkJVSUxUX0lOX1RFWFQsXG4gIGlkOiBcImdpZnJvdWxldHRlXCIsXG4gIGRlc2NyaXB0aW9uOiBcIlNlbmRzIGEgcmFuZG9tIGZhdm9yaXRlZCBHSUZcIixcbiAgZXhlY3V0ZTogKCkgPT4ge1xuICAgIGNvbnN0IHVybCA9IGdldFJhbmRvbUZhdm9yaXRlR2lmVXJsKCk7XG4gICAgcmV0dXJuIHsgY29udGVudDogdXJsID8/IFwiTm8gZmF2b3JpdGVkIEdJRnMgZm91bmQuXCIgfTtcbiAgfVxufSk7XG4iXSwKICAibWFwcGluZ3MiOiAiOzs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O0FBQUEsK0JBQXFCO0FBRXJCLGlDQUFzQjtBQU10QixTQUFTLDBCQUF5QztBQUNoRCxRQUFNLFVBQVUsMkJBQUFBLFFBQVUsV0FBVyx3QkFBd0I7QUFFN0QsYUFBVyxFQUFFLFFBQVEsS0FBSyxTQUFTO0FBQ2pDLFVBQU0saUJBQWlCLDJCQUFBQSxRQUFVLGtCQUFrQixTQUFTLG9DQUFvQztBQUNoRyxVQUFNLE9BQU8sZ0JBQWdCLG9DQUFvQyxrQkFBa0IsR0FBRyxjQUFjO0FBQ3BHLFFBQUksUUFBUTtBQUFNO0FBRWxCLFVBQU0sT0FBTyxPQUFPLEtBQUssSUFBSTtBQUM3QixRQUFJLEtBQUssV0FBVztBQUFHLGFBQU87QUFDOUIsV0FBTyxLQUFLLEtBQUssTUFBTSxLQUFLLE9BQU8sSUFBSSxLQUFLLE1BQU0sQ0FBQztBQUFBLEVBQ3JEO0FBRUEsU0FBTztBQUNUO0FBRUEseUJBQUFDLFFBQVMsZ0JBQWdCO0FBQUEsRUFDdkI7QUFBQSxFQUNBO0FBQUEsRUFDQSxJQUFJO0FBQUEsRUFDSixhQUFhO0FBQUEsRUFDYixTQUFTLE1BQU07QUFDYixVQUFNLE1BQU0sd0JBQXdCO0FBQ3BDLFdBQU8sRUFBRSxTQUFTLE9BQU8sMkJBQTJCO0FBQUEsRUFDdEQ7QUFDRixDQUFDOyIsCiAgIm5hbWVzIjogWyJzcGFjZXBhY2siLCAiQ29tbWFuZHMiXQp9Cg==
