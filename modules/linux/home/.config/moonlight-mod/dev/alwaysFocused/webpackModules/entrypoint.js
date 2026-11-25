"use strict";

// Covers the code that asks the DOM directly instead of WindowStore.
document.hasFocus = () => true;
Object.defineProperty(document, "visibilityState", { get: () => "visible" });
Object.defineProperty(document, "hidden", { get: () => false });

// Capture listeners on window run before any listener Discord adds, whatever the order.
window.addEventListener("blur", (event) => {
  if (event.target === window) event.stopImmediatePropagation();
}, true);
window.addEventListener("visibilitychange", (event) => event.stopImmediatePropagation(), true);
