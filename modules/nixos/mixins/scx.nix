{ lib, ... }:
{
  # sched-ext userspace scheduler. scx_bpfland handles hybrid P/E-core CPUs
  # (the 275HX has 8 P + 16 E cores) well and is a big part of the "CachyOS feel".
  #
  # NOTE: do NOT use scx_lavd on this host's kernel (6.19-cachyos). It busy-loops
  # a full core (~100% CPU → heat) and leaks ~20 GB of BPF map memory within a
  # minute on this Arrow Lake-HX hardware. bpfland is the stable choice here.
  #
  # Uses the module's default scx package (which bundles scx_bpfland). To track
  # the newest schedulers instead, set `package` to a git build on the hardware.
  services.scx = {
    enable = true;
    scheduler = lib.mkDefault "scx_bpfland";
  };
}
