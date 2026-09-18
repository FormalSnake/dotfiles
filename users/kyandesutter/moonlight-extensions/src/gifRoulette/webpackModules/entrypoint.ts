import Commands from "@moonlight-mod/wp/commands_commands";
import { CommandType, InputType } from "@moonlight-mod/types/coreExtensions/commands";
import spacepack from "@moonlight-mod/wp/spacepack_spacepack";

// Named exports survive Discord's minifier (only local variable names get
// mangled), so scanning the already-required module cache for this exact key
// is more reliable than matching against minified source via findByCode.
//
// A plain `!= null` check on the property isn't enough: several webpack
// modules (i18n string catalogs) export catch-all Proxies that return a
// truthy value for *any* key, including this one, so every candidate has to
// be validated by shape (a real getCurrentValue() call that resolves to a
// favoriteGifs.gifs map) before being accepted.
function extractFavoriteGifs(candidate: any): Record<string, unknown> | null {
  if (typeof candidate?.getCurrentValue !== "function") return null;

  try {
    const gifs = candidate.getCurrentValue()?.favoriteGifs?.gifs;
    return gifs != null && typeof gifs === "object" ? gifs : null;
  } catch {
    return null;
  }
}

function findFavoriteGifs(): Record<string, unknown> | null {
  const cache = spacepack.cache;
  for (const id in cache) {
    const exports = cache[id]?.exports;
    if (exports == null) continue;

    const gifs =
      extractFavoriteGifs(exports.FrecencyUserSettingsActionCreators) ??
      extractFavoriteGifs(exports.default?.FrecencyUserSettingsActionCreators);
    if (gifs != null) return gifs;
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
    console.error("[gifRoulette] could not find a validated FrecencyUserSettingsActionCreators.getCurrentValue().favoriteGifs.gifs in the webpack cache");
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
