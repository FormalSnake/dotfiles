# sketchybar -m --set disk_percentage label=$(df -lh | grep /dev/disk1s2 | awk '{print $5}')
sketchybar -m --set disk_percentage label=$(memory_pressure | grep "System-wide memory free percentage:" | awk '{ printf("%02.0f\n", 100-$5"%") }')%
