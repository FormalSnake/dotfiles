{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.waydroid;
in
{
  options.kyan.waydroid.enable = lib.mkEnableOption "Waydroid Android container";

  # Android in a container, sharing the host kernel (binder + ashmem), rendering
  # into the running Wayland session. Here it exists for one reason: streaming
  # services whose Widevine licence servers reject desktop Linux outright.
  # Rakuten TV is the case in hand — its player loads fine in Chrome with a
  # Windows UA, then prod-widevine.rakuten.tv answers the licence challenge with
  # 426, because the challenge carries the CDM's own client info (ChromeCDM on
  # Linux) which no UA flag can touch. The Android app sends an Android client
  # info instead, which they do accept, at L3 (so 480p-720p, not HD).
  #
  # The image is NOT declarative: `waydroid init` downloads a system/vendor pair
  # into /var/lib/waydroid at runtime. Use the WayDroid-ATV Android TV builds,
  # which bake in Widevine L3 and libhoudini (both x86-64 only, which is what
  # this host is), rather than the stock LineageOS images that ship neither:
  #
  #   sudo waydroid init -f -s GAPPS -r lineage \
  #     -c https://waydroid-atv.github.io/ota/a16-tv/system \
  #     -v https://waydroid-atv.github.io/ota/a16-tv/vendor
  #   sudo systemctl start waydroid-container
  #   waydroid session start && waydroid show-full-ui
  #
  # A GAPPS image starts uncertified, so the Play Store refuses to sign in until
  # the device is registered: read the ID with
  # `sudo waydroid shell -- sh -c 'ANDROID_RUNTIME_ROOT=/apex/com.android.runtime ANDROID_DATA=/data ANDROID_TZDATA_ROOT=/apex/com.android.tzdata ANDROID_I18N_ROOT=/apex/com.android.i18n sqlite3 /data/data/com.google.android.gsf/databases/gservices.db "select * from main where name = \"android_id\""'`
  # and submit it at https://google.com/android/uncertified.
  config = lib.mkIf cfg.enable {
    virtualisation.waydroid.enable = true;

    # `waydroid init` fetches the images over https and the ATV OTA server is a
    # plain static host, so nothing else is needed at the network layer. sqlite3
    # is for the certification step above; the container ships no shell tooling.
    environment.systemPackages = [ pkgs.sqlite ];
  };
}
