# Idempotently splice the plugin bar widgets into every DankBar config's
# rightWidgets, matching the fresh-install seed in dms.nix. Each id is added
# only when it's absent from the whole bar (left+center+right), so re-running on
# every home-manager switch never duplicates a widget and never fights a widget
# the user has since moved. A missing anchor is a no-op.
#
# Placement (matching settingsSeed.rightWidgets in dms.nix):
#   discordVoice        after  systemTray
#   githubNotifier      after  clipboard
#   nvidiaGpuMonitor,   after  cpuUsage        (the GPU pair, CPU→RAM)
#     dgpuStatus
#   claudeCodeUsage     after  dgpuStatus
#   gameControllerBatt. after  memUsage
#   asusControlCenter   before battery
#   displayManager      before controlCenterButton
def allWidgets: (.leftWidgets // []) + (.centerWidgets // []) + (.rightWidgets // []);

def insertAfter($arr; $anchor; $new):
  ($arr | index($anchor)) as $i
  | if $i == null or ($new | length) == 0 then $arr
    else $arr[0:$i + 1] + $new + $arr[$i + 1:] end;

def insertBefore($arr; $anchor; $new):
  ($arr | index($anchor)) as $i
  | if $i == null or ($new | length) == 0 then $arr
    else $arr[0:$i] + $new + $arr[$i:] end;

.barConfigs |= map(
  (allWidgets) as $have
  | (["discordVoice"] - $have) as $discord
  | (["githubNotifier"] - $have) as $github
  | (["nvidiaGpuMonitor", "dgpuStatus"] - $have) as $gpu
  | (["claudeCodeUsage"] - $have) as $claude
  | (["gameControllerBattery"] - $have) as $controller
  | (["asusControlCenter"] - $have) as $asus
  | (["displayManager"] - $have) as $display
  | .rightWidgets = insertAfter(.rightWidgets // []; "systemTray"; $discord)
  | .rightWidgets = insertAfter(.rightWidgets; "clipboard"; $github)
  | .rightWidgets = insertAfter(.rightWidgets; "cpuUsage"; $gpu)
  | .rightWidgets = insertAfter(.rightWidgets; "dgpuStatus"; $claude)
  | .rightWidgets = insertAfter(.rightWidgets; "memUsage"; $controller)
  | .rightWidgets = insertBefore(.rightWidgets; "battery"; $asus)
  | .rightWidgets = insertBefore(.rightWidgets; "controlCenterButton"; $display)
)
