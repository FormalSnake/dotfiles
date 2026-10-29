"use strict";
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// src/streamdeckBridge/index.ts
var streamdeckBridge_exports = {};
__export(streamdeckBridge_exports, {
  patches: () => patches,
  webpackModules: () => webpackModules
});
module.exports = __toCommonJS(streamdeckBridge_exports);
var patches = [
  {
    // The table behind Discord's own keybinds (TOGGLE_MUTE, TOGGLE_CAMERA,
    // TOGGLE_GO_LIVE_STREAMING, ...) lives in a module-local variable that is
    // only ever handed to this dispatch, so capture it on the way past.
    find: 'type:"KEYBINDS_REGISTER_GLOBAL_KEYBIND_ACTIONS",keybinds:',
    replace: {
      match: /(?<=type:"KEYBINDS_REGISTER_GLOBAL_KEYBIND_ACTIONS",keybinds:)(\i)/,
      replacement: (_, table) => `require("streamdeckBridge_keybinds").capture(${table})`
    }
  }
];
var webpackModules = {
  keybinds: {},
  entrypoint: {
    dependencies: [
      { ext: "common", id: "stores" },
      { ext: "spacepack", id: "spacepack" },
      { ext: "streamdeckBridge", id: "keybinds" }
    ],
    entrypoint: true
  }
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vc3JjL3N0cmVhbWRlY2tCcmlkZ2UvaW5kZXgudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImltcG9ydCB7IEV4dGVuc2lvbldlYkV4cG9ydHMgfSBmcm9tIFwiQG1vb25saWdodC1tb2QvdHlwZXNcIjtcblxuZXhwb3J0IGNvbnN0IHBhdGNoZXM6IEV4dGVuc2lvbldlYkV4cG9ydHNbXCJwYXRjaGVzXCJdID0gW1xuICB7XG4gICAgLy8gVGhlIHRhYmxlIGJlaGluZCBEaXNjb3JkJ3Mgb3duIGtleWJpbmRzIChUT0dHTEVfTVVURSwgVE9HR0xFX0NBTUVSQSxcbiAgICAvLyBUT0dHTEVfR09fTElWRV9TVFJFQU1JTkcsIC4uLikgbGl2ZXMgaW4gYSBtb2R1bGUtbG9jYWwgdmFyaWFibGUgdGhhdCBpc1xuICAgIC8vIG9ubHkgZXZlciBoYW5kZWQgdG8gdGhpcyBkaXNwYXRjaCwgc28gY2FwdHVyZSBpdCBvbiB0aGUgd2F5IHBhc3QuXG4gICAgZmluZDogJ3R5cGU6XCJLRVlCSU5EU19SRUdJU1RFUl9HTE9CQUxfS0VZQklORF9BQ1RJT05TXCIsa2V5YmluZHM6JyxcbiAgICByZXBsYWNlOiB7XG4gICAgICBtYXRjaDogLyg/PD10eXBlOlwiS0VZQklORFNfUkVHSVNURVJfR0xPQkFMX0tFWUJJTkRfQUNUSU9OU1wiLGtleWJpbmRzOikoXFxpKS8sXG4gICAgICByZXBsYWNlbWVudDogKF8sIHRhYmxlKSA9PiBgcmVxdWlyZShcInN0cmVhbWRlY2tCcmlkZ2Vfa2V5YmluZHNcIikuY2FwdHVyZSgke3RhYmxlfSlgXG4gICAgfVxuICB9XG5dO1xuXG5leHBvcnQgY29uc3Qgd2VicGFja01vZHVsZXM6IEV4dGVuc2lvbldlYkV4cG9ydHNbXCJ3ZWJwYWNrTW9kdWxlc1wiXSA9IHtcbiAga2V5YmluZHM6IHt9LFxuICBlbnRyeXBvaW50OiB7XG4gICAgZGVwZW5kZW5jaWVzOiBbXG4gICAgICB7IGV4dDogXCJjb21tb25cIiwgaWQ6IFwic3RvcmVzXCIgfSxcbiAgICAgIHsgZXh0OiBcInNwYWNlcGFja1wiLCBpZDogXCJzcGFjZXBhY2tcIiB9LFxuICAgICAgeyBleHQ6IFwic3RyZWFtZGVja0JyaWRnZVwiLCBpZDogXCJrZXliaW5kc1wiIH1cbiAgICBdLFxuICAgIGVudHJ5cG9pbnQ6IHRydWVcbiAgfVxufTtcbiJdLAogICJtYXBwaW5ncyI6ICI7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O0FBQUE7QUFBQTtBQUFBO0FBQUE7QUFBQTtBQUFBO0FBRU8sSUFBTSxVQUEwQztBQUFBLEVBQ3JEO0FBQUE7QUFBQTtBQUFBO0FBQUEsSUFJRSxNQUFNO0FBQUEsSUFDTixTQUFTO0FBQUEsTUFDUCxPQUFPO0FBQUEsTUFDUCxhQUFhLENBQUMsR0FBRyxVQUFVLGdEQUFnRCxLQUFLO0FBQUEsSUFDbEY7QUFBQSxFQUNGO0FBQ0Y7QUFFTyxJQUFNLGlCQUF3RDtBQUFBLEVBQ25FLFVBQVUsQ0FBQztBQUFBLEVBQ1gsWUFBWTtBQUFBLElBQ1YsY0FBYztBQUFBLE1BQ1osRUFBRSxLQUFLLFVBQVUsSUFBSSxTQUFTO0FBQUEsTUFDOUIsRUFBRSxLQUFLLGFBQWEsSUFBSSxZQUFZO0FBQUEsTUFDcEMsRUFBRSxLQUFLLG9CQUFvQixJQUFJLFdBQVc7QUFBQSxJQUM1QztBQUFBLElBQ0EsWUFBWTtBQUFBLEVBQ2Q7QUFDRjsiLAogICJuYW1lcyI6IFtdCn0K
