{
  # Device firmware updates via LVFS. Vendors publish signed BIOS/EC/Thunderbolt
  # /NVMe firmware there; fwupd stages a UEFI capsule in the ESP and the
  # firmware applies it on the next boot. `fwupdmgr get-devices` shows what this
  # chassis actually has an update path for, `fwupdmgr update` takes it.
  #
  # Both hosts are ASUS laptops. The g815 could flash from the Windows side of
  # its dual boot; the e1504g has no other route to a BIOS update at all.
  services.fwupd.enable = true;
}
