load("//lib/tree.star", "merge")

def oneshot(name, exec, description = None, user = False, remain = True, unit = {}, install = None, **keys):
    systemd = {"Type": "oneshot"}
    if remain:
        systemd["RemainAfterExit"] = True
    systemd.update(keys)
    if unit:
        systemd["unit"] = unit
    if install:
        systemd["install"] = install
    return service(name, exec = exec, user = user, description = description, systemd = systemd)

def gui(name, exec, description, restart = "no", hyprland = False, needs = None, unit = {}, env = {}, **keys):
    """A user service that runs with the graphical session."""

    # The target can be up without the compositor's environment (a bare Hyprland session), where
    # Restart= would loop the app, so it skips instead.
    u = {"After": "graphical-session.target", "PartOf": "graphical-session.target", "ConditionEnvironment": ["WAYLAND_DISPLAY"]}
    if hyprland:
        u["ConditionEnvironment"] = ["WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP=Hyprland"]
    if needs:
        u["ConditionPathExists"] = needs
    systemd = merge({"unit": merge(u, unit), "install": {"WantedBy": "graphical-session.target"}}, keys)
    return service(name, exec = exec, user = True, restart = restart, description = description, env = env, systemd = systemd)

def autostart(name, exec, description, unit = {}, **kw):
    """Started once with the session; closing the window does not respawn it."""
    return gui(name, exec, description, unit = merge({"RefuseManualStart": True, "RefuseManualStop": True}, unit), **kw)
