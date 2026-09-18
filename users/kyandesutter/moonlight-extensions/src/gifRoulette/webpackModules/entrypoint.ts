import Commands from "@moonlight-mod/wp/commands_commands";
import { CommandType, InputType } from "@moonlight-mod/types/coreExtensions/commands";
import spacepack from "@moonlight-mod/wp/spacepack_spacepack";

// Named exports survive Discord's minifier (only local variable names get
// mangled), so scanning the already-required module cache for this exact key
// is more reliable than matching against minified source via findByCode.
function findFrecencyActionCreators(): any {
  const cache = spacepack.cache;
  for (const id in cache) {
    const exports = cache[id]?.exports;
    if (exports?.FrecencyUserSettingsActionCreators != null) {
      return exports.FrecencyUserSettingsActionCreators;
    }
    if (exports?.default?.FrecencyUserSettingsActionCreators != null) {
      return exports.default.FrecencyUserSettingsActionCreators;
    }
  }
  return null;
}

// The favorites live on Discord's FrecencyUserSettings proto, already synced
// to the client and cached in memory, so this is a synchronous local lookup
// with no pagination: Object.keys() once, then one O(1) random index, however
// many thousand GIFs are favorited.
function getRandomFavoriteGifUrl(): string | null {
  const actionCreators = findFrecencyActionCreators();
  if (actionCreators == null) {
    console.error("[gifRoulette] could not find FrecencyUserSettingsActionCreators in the webpack cache");
    return null;
  }

  const gifs = actionCreators.getCurrentValue?.()?.favoriteGifs?.gifs;
  if (gifs == null) {
    console.error("[gifRoulette] FrecencyUserSettings has no favoriteGifs.gifs", actionCreators.getCurrentValue?.());
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
  // Returning nothing (rather than { content: ... }) means no message is
  // sent when this fails, instead of pasting an error into the channel.
  execute: () => {
    const url = getRandomFavoriteGifUrl();
    if (url == null) return undefined;
    return { content: url };
  }
});
