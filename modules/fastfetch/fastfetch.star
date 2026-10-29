# One fastfetch config for every host; only the logo in logos/ differs.

CPU = "{ sysctl -n machdep.cpu.brand_string 2>/dev/null || sed -n 's/^model name.*: //p' /proc/cpuinfo; } | head -1 | sed -E 's/\\((R|TM)\\)//g; s/^(Intel|Apple) +//'"

GPU = "if command -v lspci >/dev/null; then lspci -mm | sed -nE '/VGA|3D/s/.*\\[(.*)\\].*/\\1/p' | tail -1 | sed 's/ Max-Q.*//'; else %s; fi" % CPU

def _row(key, type, format, text = None):
    row = {"format": format + " ┃", "key": "┃   " + key + " " * (7 - len(key))}
    if text:
        row["text"] = text
    row["type"] = type
    return row

def _sh(key, text):
    return _row(key, "command", "{1>24}", text = text)

def _edge(left, right):
    return {"key": left + "━" * 37 + right, "type": "custom"}

def fastfetch(host):
    config = {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
        "display": {"color": "white", "separator": "  "},
        "logo": {
            "color": {"1": "white"},
            "padding": {"left": 1, "right": 2, "top": 1},
            "source": "~/.config/fastfetch/logo.txt",
            "type": "file",
        },
        "modules": [
            "break",
            _edge("┏", "┓"),
            _sh("user", "echo $USER@" + host),
            _row("distro", "os", "{name>24}"),
            _row("kernel", "kernel", "{release>24}"),
            _row("wm", "wm", "{pretty-name>24}"),
            _row("shell", "shell", "{pretty-name>24}"),
            _row("uptime", "uptime", "{days>15}d {hours>2}h {minutes>2}m"),
            _sh("cpu", CPU),
            _sh("gpu", GPU),
            _row("mem", "memory", "{used>12} / {total>9}"),
            _row("pkgs", "packages", "{all>24}"),
            _edge("┗", "┛"),
            "break",
        ],
    }
    return [
        file("~/.config/fastfetch/config.jsonc", content = config, format = "json"),
        file("~/.config/fastfetch/logo.txt", src = "modules/fastfetch/logos/%s.txt" % host),
    ]
