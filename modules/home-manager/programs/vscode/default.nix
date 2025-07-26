{
  config,
  pkgs,
  inputs,
  ...
}: {
  programs.vscode = {
    enable = true;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      vscodevim.vim
      yzhang.markdown-all-in-one
      astro-build.astro-vscode
    ];
  };
}
