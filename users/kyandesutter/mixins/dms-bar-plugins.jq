# Idempotently splice the plugin bar widgets into every DankBar config's
# rightWidgets, matching the fresh-install seed in dms.nix: the GPU pair
# (nvidiaGpuMonitor, dgpuStatus) right after cpuUsage — i.e. between CPU and RAM
# usage — and asusControlCenter just before the battery widget. Each id is added
# only when it's absent from the whole bar (left+center+right), so re-running on
# every home-manager switch never duplicates a widget and never fights a widget
# the user has since moved. A missing anchor (cpuUsage / battery) is a no-op.
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
  | (["nvidiaGpuMonitor", "dgpuStatus"] - $have) as $gpu
  | (["asusControlCenter"] - $have) as $asus
  | .rightWidgets = insertAfter(.rightWidgets // []; "cpuUsage"; $gpu)
  | .rightWidgets = insertBefore(.rightWidgets; "battery"; $asus)
)
