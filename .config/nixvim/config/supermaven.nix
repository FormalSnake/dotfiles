{ pkgs, ... }:

{
  extraPlugins = with pkgs.vimPlugins; [
   supermaven-nvim
  ];
}
