sketchybar -m --set disk_percentage label=$(df -lh | grep /dev/disk1s2 | awk '{print $5}')
