{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          git
          just
          nixfmt
          nil
        ];
      };

      formatter = pkgs.nixfmt;
    };
}
