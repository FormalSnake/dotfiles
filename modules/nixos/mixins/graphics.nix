{
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # required for Steam / 32-bit Proton titles
  };

  # Firmware for Intel BE200 (iwlwifi/iwlmld), NVIDIA Blackwell, and other devices.
  hardware.enableRedistributableFirmware = true;
}
