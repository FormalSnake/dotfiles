import Commands from "@moonlight-mod/wp/commands_commands";
import { CommandType, InputType } from "@moonlight-mod/types/coreExtensions/commands";
import spacepack from "@moonlight-mod/wp/spacepack_spacepack";

// The favorites live on Discord's FrecencyUserSettings proto, already synced
// to the client and cached in memory, so this is a synchronous local lookup
// with no pagination: Object.keys() once, then one O(1) random index, however
// many thousand GIFs are favorited.
function getRandomFavoriteGifUrl(): string | null {
  const modules = spacepack.findByCode('"FrecencyUserSettings"');

  for (const { exports } of modules) {
    const actionCreators = spacepack.findObjectFromKey(exports, "FrecencyUserSettingsActionCreators");
    const gifs = actionCreators?.FrecencyUserSettingsActionCreators?.getCurrentValue?.()?.favoriteGifs?.gifs;
    if (gifs == null) continue;

    const urls = Object.keys(gifs);
    if (urls.length === 0) return null;
    return urls[Math.floor(Math.random() * urls.length)];
  }

  return null;
}

Commands.registerCommand({
  type: CommandType.CHAT,
  inputType: InputType.BUILT_IN_TEXT,
  id: "gifroulette",
  description: "Sends a random favorited GIF",
  execute: () => {
    const url = getRandomFavoriteGifUrl();
    return { content: url ?? "No favorited GIFs found." };
  }
});
