#!/bin/bash
# Puts formalboot in the initrd, so the boot screen is up before the root is mounted.

check() {
	[ -x /opt/fspec/current/bin/formalboot ] || return 1
	return 0
}

depends() {
	echo drm systemd
}

install() {
	# The store path is a chain of links; the initrd gets the binary under the name the units run.
	inst "$(readlink -f /opt/fspec/current/bin/formalboot)" /opt/fspec/current/bin/formalboot
	inst_multiple /usr/local/share/formalos-boot/logo.png /usr/local/share/formalos-boot/wordmark.png \
		/usr/local/share/formalos-boot/theme.env
	inst_simple /etc/systemd/system/formalboot.service
	inst_simple "$moddir/formalboot-switch-root.service" "$systemdsystemunitdir/formalboot-switch-root.service"
	$SYSTEMCTL -q --root "$initdir" add-wants sysinit.target formalboot.service
	$SYSTEMCTL -q --root "$initdir" add-wants initrd-switch-root.target formalboot-switch-root.service
}
