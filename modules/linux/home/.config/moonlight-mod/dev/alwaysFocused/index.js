"use strict";

exports.patches = [
  {
    find: 'type:"WINDOW_VISIBILITY_CHANGE",windowId:',
    replace: [
      { match: /focused:\i\.hasFocus\(\)/, replacement: "focused:!0" },
      { match: /(type:"WINDOW_FOCUS",windowId:[^}]+?,focused:)\i/, replacement: (_, head) => `${head}!0` },
      { match: /visible:"visible"===[\w$.]+\.visibilityState/g, replacement: "visible:!0" }
    ]
  },
  {
    // The main process reports blur over IPC as well, and that handler also tells the native
    // side and arms a memory purge, neither of which goes through the dispatcher.
    find: '"MAIN_WINDOW_BLUR"',
    replace: {
      match: /"MAIN_WINDOW_BLUR",\(\)=>\{/,
      replacement: (orig) => `${orig}return;`
    }
  }
];

exports.webpackModules = {
  entrypoint: { entrypoint: true }
};
