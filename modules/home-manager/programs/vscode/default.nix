{
  config,
  pkgs,
  inputs,
  ...
}: {
  programs.vscode = {
    enable = false;
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
      userSettings = {
        "editor.fontFamily" = "GeistMono Nerd Font";
        "terminal.integrated.fontFamily" = "GeistMono Nerd Font";
        "debug.console.fontFamily" = "GeistMono Nerd Font";
        "editor.codeLensFontFamily" = "GeistMono Nerd Font";
      };
    };
  };
}
