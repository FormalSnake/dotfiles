{
  # sched-ext userspace scheduler. scx_bpfland handles hybrid P/E-core CPUs
  # (the 275HX has 8 P + 16 E cores) well and is a big part of the "CachyOS feel".
  # Uses the module's default scx package (which bundles scx_bpfland). To track
  # the newest schedulers instead, set `package` to a git build on the hardware.
  services.scx = {
    enable = true;
    scheduler = "scx_bpfland";
  };
}
