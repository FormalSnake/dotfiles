# Nix Configuration Refactoring Plan

This document outlines a series of changes to refactor the Nix configuration for improved clarity, consistency, and maintainability across both macOS and NixOS platforms. The changes are grouped by area of concern, with specific file-by-file instructions.

## 1. Global Configuration & Unification

### 1.1. Standardize on Fish Shell

The configuration contains setups for both Zsh and Fish, but the default shell for the NixOS user is still Zsh. These changes will make Fish the consistent default shell across all systems.

-   **File to modify:** `flake.nix`
    -   **Action:** In the `mkNixosConfig` function, change the user's default shell from `zsh` to `fish`.
    -   **Find this line:** `shell = nixpkgs.legacyPackages.${system}.zsh;`
    -   **Replace with:** `shell = nixpkgs.legacyPackages.${system}.fish;`

-   **File to delete:** `modules/programs/zsh.nix`
    -   **Action:** This file is no longer needed.

-   **File to modify:** `hosts/homelab/default.nix`
    -   **Action:** Remove the system-level Zsh enablement.
    -   **Remove this line:** `programs.zsh.enable = true;`

-   **File to modify:** `hosts/homelab/home.nix`
    -   **Action:** Remove the home-manager Zsh enablement.
    -   **Remove this line:** `programs.zsh.enable = true;`

### 1.2. Centralize Common Packages & Handle Platform-Specifics

Packages like `firefox` can be centralized. However, `brave` needs to be installed via Homebrew on macOS due to system issues, so it must be handled on a per-platform basis. This section adjusts the package management strategy accordingly.

-   **File to modify:** `modules/common/home.nix`
    -   **Action:** Remove `brave` from the common packages list. It will be managed per-platform. `firefox` will remain.

-   **File to modify:** `modules/nixos/default.nix`
    -   **Action:** In the `environment.systemPackages` list, remove `firefox` as it is being moved to `modules/common/home.nix`. `brave` should remain in this list for NixOS systems.

-   **File to modify:** `hosts/homelab/default.nix`
    -   **Action:** In the `environment.systemPackages` list, remove both `firefox` and `brave` to avoid duplication with the platform-level configurations defined in `modules/common/home.nix` and `modules/nixos/default.nix`.

-   **File to modify:** `modules/darwin/homebrew.nix`
    -   **Action:** The instruction to remove `"brave-browser"` was incorrect and has been removed from this plan. It should remain in the `casks` list for macOS-specific installation. No change is needed for this file.

### 1.3. Clean up `flake.nix`

-   **File to modify:** `flake.nix`
    -   **Action:** Remove the backward compatibility alias for `FormalBook` to simplify the flake.
    -   **Remove this entire block:**
        ```nix
        # Backward compatibility alias
        FormalBook = mkDarwinConfig {
          username = "kyandesutter";
          hostname = "macbook";
          system = "aarch64-darwin";
        };
        ```

### 1.4. Make Darwin Platform Dynamic

-   **File to modify:** `modules/darwin/default.nix`
    -   **Action:** The platform is hardcoded. Make it dynamic to better support other architectures in the future.
    -   **Find this line:** `nixpkgs.hostPlatform = "aarch64-darwin";`
    -   **Replace with:** `nixpkgs.hostPlatform = config.nixpkgs.system;`

## 2. Neovim Configuration Refactoring

The Neovim setup is overly complex, with significant code duplication, dead code, and conflicting strategies for managing plugins and LSPs. These changes will drastically simplify it.

### 2.1. Remove Dead and Unused Code

-   **Action:** Delete the following files, as they are either unused, fully commented out, or their functionality is redundant and will be merged elsewhere:
    -   `modules/programs/nvim/core/keymaps.lua`
    -   `modules/programs/nvim/core/config/init.lua`
    -   `modules/programs/nvim/core/config/dashboard/headers.lua`
    -   `modules/programs/nvim/plugins/lsp.lua`
    -   `modules/programs/nvim/core/config/lsp_config.lua`
    -   `modules/programs/nvim/core/config/ghostty.lua`
    -   `modules/programs/nvim/core/config/yank.lua`

### 2.2. Consolidate Options and Keymaps

All options and keymaps are scattered and duplicated. They will be consolidated into `options.lua`, which will be loaded correctly before plugins.

-   **File to modify:** `modules/programs/nvim/options.lua`
    -   **Action:** Replace its entire content with a clean, unified set of options and keymaps. This file will become the single source of truth for Neovim settings. The complex clipboard mappings will be replaced by the standard `unnamedplus`.

-   **File to modify:** `modules/programs/neovim.nix`
    -   **Action:** Remove the `extraLuaConfig` block. The configurations it loads (`options.lua`, `globals.lua`) will be loaded via the main `lazy.nvim` entrypoint.
    -   **Remove this entire block:**
        ```nix
        extraLuaConfig = ''
          ${builtins.readFile ./nvim/options.lua}
          ${builtins.readFile ./nvim/core/globals.lua}
        '';
        ```

-   **File to modify:** `modules/programs/nvim/core/lazy.lua`
    -   **Action:** Modify this file to load `globals.lua` and `options.lua` before setting up `lazy.nvim`. This ensures all settings are applied correctly before plugins are loaded. Remove the duplicated options that were already in this file.

### 2.3. Simplify LSP and Plugin Configuration

The current setup has multiple conflicting LSP management strategies and commented-out plugins.

-   **File to modify:** `modules/programs/neovim.nix`
    -   **Action:** Clean up the `plugins` list by removing commented-out sections.
    -   **Remove:** The commented-out plugin blocks for `nvim-lspconfig`, `statuscol-nvim`, `own-base16`, and the `bg` plugin's `pcall` wrapper, which is unnecessary with lazy.nvim.

-   **File to modify:** `modules/programs/nvim/plugins/cmp.lua`
    -   **Action:** Remove the large commented-out section at the top of the file to improve readability.

## 3. Host-Specific Configuration Cleanup

### 3.1. macOS Dock Path Best Practices

-   **File:** `hosts/macbook/default.nix`
    -   **Suggestion:** The current configuration for `persistent-apps` is correct for Homebrew Casks. However, if you add an application installed via `nixpkgs` to the dock in the future, ensure you reference it by its Nix store path (e.g., `${pkgs.some-app}/Applications/Some.app`) rather than a hardcoded path in `/Applications` to ensure robustness. No immediate change is needed for the current setup.
