# Reconcile every DankBar config against the Nix-managed plugin set: first
# strip the widgets we don't want, then idempotently splice the kept plugin
# widgets into rightWidgets in the same order as the fresh-install seed in
# dms.nix. Each insert fires only when its id is absent from the whole bar
# (left+center+right), so re-running on every home-manager switch never
# duplicates and never fights a widget the user has since moved.
#
# Removals ARE unconditional — these ids are stripped from every bar on every
# switch: clipboard by preference, and discordVoice/displayManager/dgpuStatus/
# gameControllerBattery/asusControlCenter because their plugins are disabled (a
# stale id would render as an empty/broken widget once the source is gone).
#
# Placement of the kept plugin widgets (matching settingsSeed.rightWidgets):
#   hiddenBar             after  systemTray        (insert-if-absent)
#   nvidiaGpuMonitor      after  cpuUsage          (insert-if-absent)
#   claudeCodeUsage       after  memUsage          (repositioned)
#   githubNotifier        before notificationButton (repositioned)
#
# githubNotifier and claudeCodeUsage are *repositioned* — stripped first, then
# re-inserted — so a copy already on the live bar at the old spot actually
# moves rather than being left in place (insert-if-absent can't relocate an
# existing widget). Their anchors (memUsage, notificationButton) are core
# seeded widgets, so they're always present.
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

(["discordVoice", "displayManager", "dgpuStatus", "gameControllerBattery", "asusControlCenter", "clipboard"]) as $remove
| (["githubNotifier", "claudeCodeUsage"]) as $reposition
| .barConfigs |= map(
    .leftWidgets   = ((.leftWidgets   // []) | without($remove) | without($reposition))
  | .centerWidgets = ((.centerWidgets // []) | without($remove) | without($reposition))
  | .rightWidgets  = ((.rightWidgets  // []) | without($remove) | without($reposition))
  | (allWidgets) as $have
  | (["hiddenBar"] - $have) as $hidden
  | (["nvidiaGpuMonitor"] - $have) as $gpu
  | .rightWidgets = insertAfter(.rightWidgets; "systemTray"; $hidden)
  | .rightWidgets = insertAfter(.rightWidgets; "cpuUsage"; $gpu)
  | .rightWidgets = insertAfter(.rightWidgets; "memUsage"; ["claudeCodeUsage"])
  | .rightWidgets = insertBefore(.rightWidgets; "notificationButton"; ["githubNotifier"])
)
