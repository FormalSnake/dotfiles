{ inputs, ... }:
{
  imports = [ inputs.catppuccin.homeModules.catppuccin ];

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
  };
}
