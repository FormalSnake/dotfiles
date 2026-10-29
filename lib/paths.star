USER = "kyandesutter"
HOME = "/home/" + USER
BIN = HOME + "/.local/bin"
STORE = "/opt/fspec/current/bin"
LIBEXEC = "/usr/local/libexec"

# git() builds that link system libraries run in the target's distro, so the sonames match.
TUMBLEWEED = "registry.opensuse.org/opensuse/tumbleweed"

def home_of(host):
    return ("/Users/" if host.platform.is_darwin else "/home/") + USER
