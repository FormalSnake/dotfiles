{
  config,
  pkgs,
  inputs,
  ...
}: {
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = false;

    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      extensions = with pkgs.vscode-extensions; [
        vscodevim.vim
        yzhang.markdown-all-in-one
        astro-build.astro-vscode
      ];
    };
  };
}
