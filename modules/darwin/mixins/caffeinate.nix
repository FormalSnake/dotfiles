{
  # Keep the laptop permanently caffeinated — never idle-sleep (the macOS parallel
  # to the g815 staying "caffeinated", see the Noctalia idle notes on that host).
  # `caffeinate -i` holds an idle-sleep assertion on any power source; `-s` adds
  # the system-sleep assertion on AC. Display sleep is left alone. The process
  # blocks for as long as it runs, so it holds the assertion for the whole login;
  # KeepAlive respawns it if it ever exits.
  launchd.user.agents.caffeinate = {
    serviceConfig = {
      Label = "kyan.caffeinate";
      ProgramArguments = [ "/usr/bin/caffeinate" "-i" "-s" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };
}
