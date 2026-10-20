type KeybindAction = { onTrigger: (...args: unknown[]) => unknown };

let table: Record<string, KeybindAction> | null = null;

export function capture<T extends Record<string, KeybindAction>>(keybinds: T): T {
  table = keybinds;
  return keybinds;
}

export function trigger(action: string): boolean {
  const entry = table?.[action];
  if (entry == null) return false;
  entry.onTrigger(true, {});
  return true;
}
