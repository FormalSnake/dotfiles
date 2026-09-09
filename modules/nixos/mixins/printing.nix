{ ... }:
{
  # CUPS with driverless IPP Everywhere, no vendor drivers. Network printers
  # are found over mDNS: cups-browsed follows services.avahi.enable, and
  # nssmdns4 resolves the printer.local names its URIs use. avahi is enabled
  # here so printing does not depend on the AirPlay mixin being on.
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
}
