{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          git
          just
          nixfmt-rfc-style
          nil
        ];
      };

      formatter = pkgs.nixfmt-rfc-style;
    };
}
