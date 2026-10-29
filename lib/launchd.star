load("//lib/paths.star", "STORE", "USER")

# The macbook's launchd shorthands, the counterpart of units.star.

HOME = "/Users/" + USER
BIN = HOME + "/.local/bin"
BREW = "/opt/homebrew/bin"
LOGS = HOME + "/Library/Logs"
PATH = ":".join([BIN, STORE, BREW, "/opt/homebrew/opt/node@24/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"])

def logs(name, extra = {}):
    d = {"StandardOutPath": LOGS + "/" + name + ".log", "StandardErrorPath": LOGS + "/" + name + ".log"}
    d.update(extra)
    return d

def agent(name, exec, env = {"PATH": PATH}, log = None, **launchd):
    """A user agent kept alive, logging to ~/Library/Logs."""
    return service(name, exec = exec, user = True, restart = "always", env = env, launchd = logs(log or name, launchd))

def poll(name, exec, interval, env = {"PATH": PATH}, **launchd):
    return service(name, exec = exec, user = True, env = env, launchd = logs(name, dict({"StartInterval": interval}, **launchd)))
