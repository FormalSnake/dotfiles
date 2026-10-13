{
  # A flake's `pkgs.mkShell` on darwin carries the whole darwin stdenv: nixpkgs'
  # apple-sdk as SDKROOT/DEVELOPER_DIR, xcbuild's xcrun, and nix clang/cctools
  # ahead of /usr/bin. System swift then builds against the wrong SDK, xcrun
  # cannot find Xcode tools, and nix cctools `strip` fails release builds with
  # "mis-aligned LINKEDIT". Every shell or agent born inside the dir inherits
  # it. After nix-direnv loads a flake (or shell.nix), drop that toolchain so
  # Xcode's clang/ld/strip/xcrun/SDK answer. rustup's proxies also go ahead of
  # a nix rustc: rust-toolchain.toml is honoured, and a nix rustc linking
  # through Apple's ld loses proc-macro crates ("can't find crate for
  # zerofrom_derive" building NativeDesktop's nd-adblock). Everything else the
  # shell provides (zig, bun, pkg-config, libraries) stays.
  #
  # Opt out per project with `export DIRENV_NIX_TOOLCHAIN=1` in .envrc, above
  # `use flake`.
  #
  # direnv sources lib/*.sh (nix-direnv) before direnvrc, so use_flake and
  # use_nix already exist here and can be wrapped.
  programs.direnv.stdlib = ''
    _apple_toolchain_scrub() {
      [[ -n ''${DIRENV_NIX_TOOLCHAIN:-} ]] && return 0

      unset SDKROOT DEVELOPER_DIR MACOSX_DEPLOYMENT_TARGET \
        CC CXX LD AR AS NM RANLIB STRIP OBJCOPY OBJDUMP SIZE STRINGS \
        LD_DYLD_PATH
      local var
      for var in $(compgen -e); do
        case $var in
          NIX_APPLE_SDK_*|NIX_CC*|NIX_BINTOOLS*|NIX_CFLAGS_*|NIX_LDFLAGS*|NIX_HARDENING_*|NIX_DONT_SET_RPATH*|NIX_NO_SELF_RPATH|NIX_IGNORE_LD_THROUGH_GCC|NIX_ENFORCE_NO_NATIVE)
            unset "$var" ;;
        esac
      done

      local dir kept="" has_nix_rust=""
      local IFS=:
      for dir in $PATH; do
        case $dir in
          /nix/store/*-clang-wrapper-*|/nix/store/*-clang-[0-9]*|/nix/store/*-cctools-*|/nix/store/*-xcbuild-*|/nix/store/*-ld64-*)
            continue ;;
        esac
        [[ $dir == /nix/store/* && -x $dir/rustc ]] && has_nix_rust=1
        kept=''${kept:+$kept:}$dir
      done
      if [[ -n $has_nix_rust && -x $HOME/.cargo/bin/rustup ]]; then
        kept=$HOME/.cargo/bin:$kept
      fi
      export PATH=$kept
    }

    eval "_nix_direnv_use_flake() $(declare -f use_flake | tail -n +2)"
    use_flake() { _nix_direnv_use_flake "$@" && _apple_toolchain_scrub; }

    eval "_nix_direnv_use_nix() $(declare -f use_nix | tail -n +2)"
    use_nix() { _nix_direnv_use_nix "$@" && _apple_toolchain_scrub; }
  '';
}
