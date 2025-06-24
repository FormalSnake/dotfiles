{inputs, ...}: [
  # Custom overlays for Neovim plugins
  (final: prev: {
    vimPlugins =
      prev.vimPlugins
      // {
        own-auto-dark-mode = prev.vimUtils.buildVimPlugin {
          name = "auto-dark-mode.nvim";
          src = inputs.plugin-auto-dark-mode;
        };
        own-visual-whitespace = prev.vimUtils.buildVimPlugin {
          name = "visual-whitespace.nvim";
          src = inputs.plugin-visual-whitespace;
        };
        own-tidy = prev.vimUtils.buildVimPlugin {
          name = "tidy.nvim";
          src = inputs.plugin-tidy;
        };
        own-base16 = prev.vimUtils.buildVimPlugin {
          name = "base16.nvim";
          src = inputs.plugin-base16;
        };
        own-aider = prev.vimUtils.buildVimPlugin {
          name = "aider.nvim";
          src = inputs.plugin-aider;
        };
        own-bg = prev.vimUtils.buildVimPlugin {
          name = "bg.nvim";
          src = inputs.plugin-bg;
        };
        own-transparent = prev.vimUtils.buildVimPlugin {
          name = "transparent.nvim";
          src = inputs.plugin-transparent;
        };
      };
  })
]