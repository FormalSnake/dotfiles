# One fastfetch config for every host: its logo from logos/ and its hardware labels.

HARDWARE = {
    "e1504g": {"cpu": "Core i3-N305", "gpu": "UHD Graphics"},
    "g815": {"cpu": "Core Ultra 9 275HX", "gpu": "GeForce RTX 5070"},
    "macbook": {"cpu": "M1 Pro", "gpu": "M1 Pro"},
}

WIDTH = 24

def _row(key, type, format, text = None):
    row = {"format": format + " ┃", "key": "┃   " + key + " " * (7 - len(key))}
    if text:
        row["text"] = text
    row["type"] = type
    return row

def _label(key, text):
    return _row(key, "custom", " " * (WIDTH - len(text)) + text)

def _edge(left, right):
    return {"key": left + "━" * 37 + right, "type": "custom"}

def fastfetch(host):
    hw = HARDWARE[host]
    config = {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
        "display": {"color": "white", "separator": "  "},
        "logo": {
            "color": {"1": "white"},
            "padding": {"left": 1, "right": 2, "top": 1},
            "source": "~/.config/fastfetch/%s.txt" % host,
            "type": "file",
        },
        "modules": [
            "break",
            _edge("┏", "┓"),
            _row("user", "command", "{1>24}", text = "echo $USER@" + host),
            _row("distro", "os", "{name>24}"),
            _row("kernel", "kernel", "{release>24}"),
            _row("wm", "wm", "{pretty-name>24}"),
            _row("shell", "shell", "{pretty-name>24}"),
            _row("uptime", "uptime", "{days>15}d {hours>2}h {minutes>2}m"),
            _label("cpu", hw["cpu"]),
            _label("gpu", hw["gpu"]),
            _row("mem", "memory", "{used>12} / {total>9}"),
            _row("pkgs", "packages", "{all>24}"),
            _edge("┗", "┛"),
            "break",
        ],
    }
    return [
        file("~/.config/fastfetch/config.jsonc", content = config, format = "json"),
        file("~/.config/fastfetch/%s.txt" % host, src = "modules/fastfetch/logos/%s.txt" % host),
    ]
