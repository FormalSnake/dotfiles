{ ... }:
{
  # Spread device interrupts across cores instead of leaving them on CPU0,
  # the Fedora/Ubuntu default. Cheap on a laptop, and keeps the NVMe and
  # Wi-Fi IRQs off whichever core scx just handed the foreground task.
  services.irqbalance.enable = true;
}
