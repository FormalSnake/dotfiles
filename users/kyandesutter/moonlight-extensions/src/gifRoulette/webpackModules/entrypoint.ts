import Commands from "@moonlight-mod/wp/commands_commands";
import { CommandType, InputType } from "@moonlight-mod/types/coreExtensions/commands";
import spacepack from "@moonlight-mod/wp/spacepack_spacepack";

// Discord's minifier renames every export key (the FrecencyUserSettings
// action creators export showed up as plain "bW", not anything readable), so
// there's no stable name to look up. Instead this scans every already-loaded
// module's exports for anything shaped like a Flux-style action creator
// (a .getCurrentValue() function) whose resolved value actually has
// favoriteGifs.gifs, which is self-describing and survives minification.
function findFavoriteGifs(): Record<string, unknown> | null {
  const cache = spacepack.cache;
  for (const id in cache) {
    const exports = cache[id]?.exports;
    if (exports == null) continue;

    for (const key of Object.keys(exports)) {
      const candidate = exports[key];
      if (typeof candidate?.getCurrentValue !== "function") continue;

      try {
        const gifs = candidate.getCurrentValue()?.favoriteGifs?.gifs;
        if (gifs != null && typeof gifs === "object") return gifs;
      } catch {
        // Some action creators (i18n message lookups) throw without their
        // normal call context; irrelevant here, keep scanning.
      }
    }
  }
  return null;
}

// The favorites live on Discord's FrecencyUserSettings proto, already synced
// to the client and cached in memory, so this is a synchronous local lookup
// with no pagination: Object.keys() once, then one O(1) random index, however
// many thousand GIFs are favorited.
function getRandomFavoriteGifUrl(): string | null {
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

Commands.registerCommand({
  type: CommandType.CHAT,
  inputType: InputType.BUILT_IN_TEXT,
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
    if (url == null) return undefined;
    return { content: url };
  }
});
