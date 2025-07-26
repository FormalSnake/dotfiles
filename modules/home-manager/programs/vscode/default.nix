{
  config,
  pkgs,
  inputs,
  ...
}: {
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;

    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      extensions = with pkgs.vscode-extensions; [
        vscodevim.vim
        yzhang.markdown-all-in-one
        astro-build.astro-vscode
        bradlc.vscode-tailwindcss
        esbenp.prettier-vscode
        jnoortheen.nix-ide
      ];
    };
  };
}
