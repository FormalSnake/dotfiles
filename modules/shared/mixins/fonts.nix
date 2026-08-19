{ pkgs, ... }:
let
  # MEK.txt's typefaces (mek.gallery/mektype). The .otf files are vendored in
  # ../mek-fonts rather than fetched: upstream's only distribution is a Google
  # Drive folder linked from the third page of a PDF minted as a Tezos NFT on
  # objkt: no stable URL a build can pin. All three are released CC0 by the
  # designer (stated in each font's own release PDF), so redistributing them
  # from this repo is fine.
  #
  # MEK Mono: monospace, pixel-grid, 450/1000em advance (25% narrower than
  #              GeistMono, hence the larger point sizes at the call sites).
  # MEK Sans: proportional, full West/Central/South-East European Latin.
  # GROUT Display: display face, 108 glyphs, no `|` `~` or backtick. Installed
  #              so it's available by name; deliberately not a fontconfig
  #              default (it can't render code or UI chrome).
  #
  # None of them carry box-drawing, powerline or Nerd Font glyphs, which is why
  # every consumer keeps Geist/GeistMono behind them in the fallback chain.
  mek-fonts = pkgs.runCommandLocal "mek-fonts" { } ''
    install -Dm444 -t $out/share/fonts/opentype ${../mek-fonts}/*.otf
  '';
in
{
  fonts.packages = [ mek-fonts ];
}
