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

// src/streamdeckBridge/webpackModules/keybinds.ts
var keybinds_exports = {};
__export(keybinds_exports, {
  capture: () => capture,
  trigger: () => trigger
});
module.exports = __toCommonJS(keybinds_exports);
var table = null;
function capture(keybinds) {
  table = keybinds;
  return keybinds;
}
function trigger(action) {
  const entry = table?.[action];
  if (entry == null)
    return false;
  entry.onTrigger(true, {});
  return true;
}
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vLi4vc3JjL3N0cmVhbWRlY2tCcmlkZ2Uvd2VicGFja01vZHVsZXMva2V5YmluZHMudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbInR5cGUgS2V5YmluZEFjdGlvbiA9IHsgb25UcmlnZ2VyOiAoLi4uYXJnczogdW5rbm93bltdKSA9PiB1bmtub3duIH07XG5cbmxldCB0YWJsZTogUmVjb3JkPHN0cmluZywgS2V5YmluZEFjdGlvbj4gfCBudWxsID0gbnVsbDtcblxuZXhwb3J0IGZ1bmN0aW9uIGNhcHR1cmU8VCBleHRlbmRzIFJlY29yZDxzdHJpbmcsIEtleWJpbmRBY3Rpb24+PihrZXliaW5kczogVCk6IFQge1xuICB0YWJsZSA9IGtleWJpbmRzO1xuICByZXR1cm4ga2V5YmluZHM7XG59XG5cbmV4cG9ydCBmdW5jdGlvbiB0cmlnZ2VyKGFjdGlvbjogc3RyaW5nKTogYm9vbGVhbiB7XG4gIGNvbnN0IGVudHJ5ID0gdGFibGU/LlthY3Rpb25dO1xuICBpZiAoZW50cnkgPT0gbnVsbCkgcmV0dXJuIGZhbHNlO1xuICBlbnRyeS5vblRyaWdnZXIodHJ1ZSwge30pO1xuICByZXR1cm4gdHJ1ZTtcbn1cbiJdLAogICJtYXBwaW5ncyI6ICI7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O0FBQUE7QUFBQTtBQUFBO0FBQUE7QUFBQTtBQUFBO0FBRUEsSUFBSSxRQUE4QztBQUUzQyxTQUFTLFFBQWlELFVBQWdCO0FBQy9FLFVBQVE7QUFDUixTQUFPO0FBQ1Q7QUFFTyxTQUFTLFFBQVEsUUFBeUI7QUFDL0MsUUFBTSxRQUFRLFFBQVEsTUFBTTtBQUM1QixNQUFJLFNBQVM7QUFBTSxXQUFPO0FBQzFCLFFBQU0sVUFBVSxNQUFNLENBQUMsQ0FBQztBQUN4QixTQUFPO0FBQ1Q7IiwKICAibmFtZXMiOiBbXQp9Cg==
