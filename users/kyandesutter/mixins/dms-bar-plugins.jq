# Reconcile every DankBar config against the Nix-managed plugin set: first
# strip the widgets we don't want, then idempotently splice the kept plugin
# widgets into rightWidgets in the same order as the fresh-install seed in
# dms.nix. Each insert fires only when its id is absent from the whole bar
# (left+center+right), so re-running on every home-manager switch never
# duplicates and never fights a widget the user has since moved.
#
# Removals ARE unconditional — these ids are stripped from every bar on every
# switch: clipboard by preference, and discordVoice/displayManager/dgpuStatus
# because their plugins are disabled (a stale id would render as an empty/broken
# widget once the plugin source is gone).
#
# Placement of the kept widgets (matching settingsSeed.rightWidgets in dms.nix):
#   githubNotifier        after  systemTray
#   nvidiaGpuMonitor      after  cpuUsage
#   claudeCodeUsage       after  nvidiaGpuMonitor
#   gameControllerBattery after  memUsage
#   asusControlCenter     before battery
def allWidgets: (.leftWidgets // []) + (.centerWidgets // []) + (.rightWidgets // []);

def without($drop): map(select(IN($drop[]) | not));

def insertAfter($arr; $anchor; $new):
  ($arr | index($anchor)) as $i
  | if $i == null or ($new | length) == 0 then $arr
    else $arr[0:$i + 1] + $new + $arr[$i + 1:] end;

def insertBefore($arr; $anchor; $new):
  ($arr | index($anchor)) as $i
  | if $i == null or ($new | length) == 0 then $arr
    else $arr[0:$i] + $new + $arr[$i:] end;

(["discordVoice", "displayManager", "dgpuStatus", "clipboard"]) as $remove
| .barConfigs |= map(
    .leftWidgets   = ((.leftWidgets   // []) | without($remove))
  | .centerWidgets = ((.centerWidgets // []) | without($remove))
  | .rightWidgets  = ((.rightWidgets  // []) | without($remove))
  | (allWidgets) as $have
  | (["githubNotifier"] - $have) as $github
  | (["nvidiaGpuMonitor"] - $have) as $gpu
  | (["claudeCodeUsage"] - $have) as $claude
  | (["gameControllerBattery"] - $have) as $controller
  | (["asusControlCenter"] - $have) as $asus
  | .rightWidgets = insertAfter(.rightWidgets; "systemTray"; $github)
  | .rightWidgets = insertAfter(.rightWidgets; "cpuUsage"; $gpu)
  | .rightWidgets = insertAfter(.rightWidgets; "nvidiaGpuMonitor"; $claude)
  | .rightWidgets = insertAfter(.rightWidgets; "memUsage"; $controller)
  | .rightWidgets = insertBefore(.rightWidgets; "battery"; $asus)
)
