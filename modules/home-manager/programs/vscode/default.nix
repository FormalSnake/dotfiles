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
        ms-vscode.vscode-typescript-next
        bradlc.vscode-tailwindcss
        esbenp.prettier-vscode
        ms-vscode.vscode-json
        jnoortheen.nix-ide
        mkhl.direnv
      ];
    };
  };

  # Ensure VSCode directories exist before activation
  home.activation.createVSCodeDirs = config.lib.dag.entryBefore ["writeBoundary"] ''
    run mkdir -p "$HOME/Library/Application Support/Code/User/globalStorage"
  '';
}
