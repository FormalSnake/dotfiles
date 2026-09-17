"""Point elementary's compiled stylesheet at matugen roles.

usage: recolor.py <light|dark> <in.css> <out.css>

The stylesheet is compiled Sass, so its greys are literals (#fafafa, #333)
rather than named colours. Each neutral literal is rewritten to a
@m3_<mode>_<role> name, chosen by what the declaration paints: #333 is text in
the light variant and the window background in the dark one. The file then
opens with a default for every name it uses (the original literal), so the
theme still renders without the matugen overrides that follow it. Hues (tag
colours, the strawberry destructive red) are left alone; the accent comes from
@accent_color, which the matugen template redefines.

Exits non-zero when a neutral literal has no mapping, so an upstream bump
that introduces a new grey fails the build instead of shipping unthemed.
"""
import re
import sys

MAPS = {
    "light": {
        "bg": {
            "#fafafa": "surface",
            "white": "surface_container_lowest",
            "#fdfdfd": "surface_container_lowest",
            "#f1f1f1": "surface_container",
            "#e8e8e8": "surface_container_high",
            "#dfdfdf": "surface_container_highest",
            "#b4b4b4": "outline_variant",
            "#333": "inverse_surface",
        },
        "fg": {
            "#333": "on_surface",
            "#979797": "on_surface_variant",
            "#999999": "on_surface_variant",
            "#666666": "on_surface_variant",
            "#5c5c5c": "on_surface_variant",
            "#b4b4b4": "on_surface_variant",
        },
        "border": {
            "#dfdfdf": "outline_variant",
        },
    },
    "dark": {
        "bg": {
            "#252525": "surface_container_lowest",
            "#2a2a2a": "surface_dim",
            "#2b2b2b": "surface_dim",
            "#313131": "surface",
            "#333": "surface_container_low",
            "#373737": "surface_container",
            "#3a3a3a": "surface_container",
            "#404040": "surface_container_high",
            "#5c5c5c": "outline_variant",
        },
        "fg": {
            "white": "on_surface",
            "#d8d8d8": "on_surface",
            "#cecece": "on_surface_variant",
            "#999999": "on_surface_variant",
            "#9d9d9d": "on_surface_variant",
            "#5c5c5c": "on_surface_variant",
        },
        "border": {},
    },
}

# Literals left as they are, per mode and class: white text on the accent and
# on destructive buttons, black shadows, the light switch knob gradient that
# both variants share, and dark text drawn on those light knobs.
KEEP = {
    "light": {
        "bg": {"black", "#d4d4d4", "#ededed"},
        "fg": {"white", "black"},
        "border": {"black", "white"},
    },
    "dark": {
        "bg": {"white", "black", "#d4d4d4", "#ededed"},
        "fg": {"black", "#3a3a3a"},
        "border": {"black", "white", "#252525"},
    },
}

LITERAL = re.compile(r"#[0-9a-fA-F]{3,8}\b|\bwhite\b|\bblack\b")
NEUTRAL = re.compile(r"^(#([0-9a-f])\2\2|#([0-9a-f]{2})\3\3|white|black)$")


def prop_class(prop):
    if prop in ("color", "caret-color", "-gtk-secondary-caret-color"):
        return "fg"
    if prop.startswith("background"):
        return "bg"
    if prop.startswith(("border", "outline", "box-shadow", "-gtk-outline")):
        return "border"
    return None


def define_class(name):
    if "fg" in name or "text" in name:
        return "fg"
    if "bg" in name or "base" in name or "primary" in name:
        return "bg"
    return None


def main():
    mode, src, dst = sys.argv[1:4]
    css = open(src).read()
    used = {}
    unmapped = set()

    def rewrite(cls, value):
        def sub(m):
            lit = m.group(0).lower()
            if not NEUTRAL.match(lit):
                return m.group(0)
            role = MAPS[mode][cls].get(lit)
            if role is None:
                if lit not in KEEP[mode][cls]:
                    unmapped.add((cls, lit))
                return m.group(0)
            name = f"m3_{mode}_{role}"
            used.setdefault(name, lit)
            return "@" + name

        return LITERAL.sub(sub, value)

    def define(m):
        name, value = m.group(1), m.group(2)
        cls = define_class(name)
        if cls is None or name.isupper():
            return m.group(0)
        return f"@define-color {name} {rewrite(cls, value)};"

    def declaration(m):
        prop, value = m.group(1), m.group(2)
        cls = prop_class(prop)
        if cls is None:
            return m.group(0)
        return f"{prop}:{rewrite(cls, value)}"

    css = re.sub(r"@define-color\s+([A-Za-z0-9_]+)\s+([^;]+);", define, css)
    css = re.sub(r"(?<![@\w-])([a-z-]+)\s*:([^;{}]*)", declaration, css)

    if unmapped:
        sys.exit(f"{src} ({mode}): unmapped neutral literals: {sorted(unmapped)}")

    defaults = "".join(f"@define-color {n} {lit};\n" for n, lit in sorted(used.items()))
    with open(dst, "w") as out:
        out.write(defaults + css)


main()
