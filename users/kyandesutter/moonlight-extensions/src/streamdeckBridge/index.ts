import { ExtensionWebExports } from "@moonlight-mod/types";

export const patches: ExtensionWebExports["patches"] = [
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

export const webpackModules: ExtensionWebExports["webpackModules"] = {
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
