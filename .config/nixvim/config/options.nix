{ lib, pkgs, ... }:

{
  config.opts = {
    updatetime = 100; # Faster completion
   number = true;
   relativenumber = true;
   shiftwidth = 2;
  };
}
