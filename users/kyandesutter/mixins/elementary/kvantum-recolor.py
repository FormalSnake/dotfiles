"""Point Kvantum's KvMojaveLight at matugen roles.

usage: kvantum-recolor.py <in.svg> <in.kvconfig> <out.svg.tmpl> <out.kvconfig.tmpl>

The theme's SVG paints every widget from literals, so each one is rewritten
to a matugen token chosen by what the element draws: a white fill is a raised
face on a button, a sunken one in a line edit and the check glyph on a checked
box. Toggled and pressed buttons are pressed in, not accent filled, the way
elementary draws them. Black and white at an alpha are casts and lit rims and stay as they are,
as do the hues on the MDI buttons. One template serves both modes, since the
roles flip with the scheme.
"""
import re
import sys
import xml.etree.ElementTree as ET

SVG = "http://www.w3.org/2000/svg"
XLINK = "{http://www.w3.org/1999/xlink}href"
ET.register_namespace("", SVG)
ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")
ET.register_namespace("sodipodi", "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd")
ET.register_namespace("inkscape", "http://www.inkscape.org/namespaces/inkscape")
ET.register_namespace("rdf", "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
ET.register_namespace("cc", "http://creativecommons.org/ns#")
ET.register_namespace("dc", "http://purl.org/dc/elements/1.1/")


def token(role, suffix=""):
    return "{{colors.%s.default.hex%s}}" % (role, suffix)


RAISED = token("surface_bright", " | lighten: 2.0")
SUNKEN = token("surface_container_lowest")
# Darker than a raised face in both modes, which no container step is.
PRESSED = token("surface_dim")

ACCENTS = {
    "#245fc4", "#286adc", "#295e9f", "#2664d0", "#3273c3", "#0073e6",
    "#77aff1", "#81c0ff", "#3daee9",
}
ON_ACCENT = re.compile(r"checked|tristate|toggled|pressed|menuitem|progress-pattern|itemview")
SUNKEN_OWNER = re.compile(r"^(lineedit|le-|tlineedit|progress-normal|slider-normal|scrollbartrough|itemview-normal)")
POPOVER_OWNER = re.compile(r"^(menu-normal|menubar|dock-normal)")
# White at an alpha that is a face or a lit lower lip rather than a glint: left
# white it glares on a dark scheme.
LIT_LIP = re.compile(r"^(common-normal|checkbox-normal|radio-normal)")
# elementary presses a button into the sheet rather than filling it with the
# accent: a toggled button, a checked tool button and the chosen tab go a step
# darker and keep the text colour.
PRESSED_IN = re.compile(r"^(button|btn|tbutton|tab)-(toggled|pressed)")
PRESSED_IN_SECTIONS = {"PanelButtonCommand", "PanelButtonTool", "ToolbarButton", "Tab"}
KEEP_OWNER = re.compile(r"^(mdi-|tab-close|dock-close|.*shadow-hint)")
ANON = re.compile(r"^(path|rect|g|use|circle|ellipse|stop)[\d-]")
HEX = re.compile(r"#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b")


def norm(lit):
    lit = lit.lower()
    if len(lit) == 4:
        lit = "#" + "".join(c * 2 for c in lit[1:])
    return lit


def lightness(lit):
    r, g, b = (int(lit[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return (max(r, g, b) + min(r, g, b)) / 2


def is_grey(lit):
    r, g, b = (int(lit[i:i + 2], 16) for i in (1, 3, 5))
    return max(r, g, b) - min(r, g, b) <= 12


def role(lit, owner, translucent):
    if KEEP_OWNER.match(owner):
        return None
    if PRESSED_IN.match(owner) and (lit in ACCENTS or (is_grey(lit) and lightness(lit) < 0.9)):
        return PRESSED
    if lit in ACCENTS:
        return token("primary")
    if not is_grey(lit):
        return None
    light = lightness(lit)
    if "arrow" in owner:
        return token("on_primary") if light > 0.9 else token("on_surface")
    if LIT_LIP.match(owner) and light > 0.97:
        return RAISED
    if translucent and (light < 0.1 or light > 0.97):
        return None
    if owner.startswith("tooltip"):
        return token("inverse_surface")
    if ON_ACCENT.search(owner):
        return token("on_primary") if light > 0.9 else token("primary")
    if SUNKEN_OWNER.match(owner):
        if light >= 0.9:
            return SUNKEN
        return token("outline_variant") if light >= 0.6 else token("outline")
    if POPOVER_OWNER.match(owner):
        if light >= 0.85 or (owner.startswith("menubar") and light >= 0.6):
            return token("surface_container")
        return token("outline_variant") if light >= 0.5 else token("on_surface")
    if re.match(r"^(window|dialog)", owner):
        return token("surface")
    if light >= 0.94:
        return RAISED
    if light >= 0.84:
        return token("surface")
    if light >= 0.6:
        return token("outline_variant")
    if light >= 0.3:
        return token("on_surface_variant")
    return token("on_surface")


def alpha_of(style, keys):
    for key in keys:
        m = re.search(r"(?<![\w-])%s:([\d.]+)" % key, style)
        if m and float(m.group(1)) < 1:
            return True
    return False


def recolor_svg(src, dst):
    tree = ET.parse(src)
    root = tree.getroot()
    parent = {c: p for p in root.iter() for c in p}

    def owner(e):
        while e is not None:
            i = e.get("id", "")
            if i and not ANON.match(i):
                return i
            e = parent.get(e)
        return ""

    def faded(e):
        while e is not None:
            if alpha_of(e.get("style", ""), ["opacity"]):
                return True
            e = parent.get(e)
        return False

    def faded_out(e):
        return bool(re.search(r"(?<![\w-])opacity:0(;|$)", e.get("style", "")))

    grads = {e.get("id"): e for e in root.iter() if e.tag.endswith("Gradient")}
    grad_owner = {}
    for e in root.iter():
        if e.tag.endswith("Gradient") or e.tag.endswith("}stop"):
            continue
        for gid in re.findall(r"url\(#([^)]+)\)", e.get("style", "")):
            while gid in grads and gid not in grad_owner:
                grad_owner[gid] = owner(e)
                gid = (grads[gid].get(XLINK) or "#")[1:]

    def accent_gradient(gid):
        seen = set()
        while gid in grads and gid not in seen:
            seen.add(gid)
            for stop in grads[gid]:
                if any(norm(c) in ACCENTS for c in HEX.findall(stop.get("style", ""))):
                    return True
            gid = (grads[gid].get(XLINK) or "#")[1:]
        return False

    # Read before the stops below are rewritten to tokens.
    accent_grads = {gid for gid in grads if accent_gradient(gid)}

    def inherits_fill(e):
        while e is not None:
            if e.get("fill") or re.search(r"(?<![\w-])fill:", e.get("style", "")):
                return True
            e = parent.get(e)
        return False

    # A shape with no fill anywhere above it paints SVG's default black: the
    # arrow glyphs are drawn that way, and vanish on a dark scheme.
    for e in root.iter():
        if e.tag.split("}")[1] in ("path", "rect", "circle", "ellipse") and not inherits_fill(e):
            if not KEEP_OWNER.match(owner(e)) and owner(e) and not faded_out(e):
                e.set("style", (e.get("style", "") + ";fill:" + token("on_surface")).lstrip(";"))

    for e in root.iter():
        style = e.get("style")
        if not style:
            continue
        if e.tag.endswith("}stop"):
            own = grad_owner.get(parent[e].get("id"), "")
            fade = alpha_of(style, ["stop-opacity"])

            def sub(m, own=own, fade=fade):
                return role(norm(m.group(0)), own, fade) or m.group(0)

            e.set("style", re.sub(r"(?<=stop-color:)" + HEX.pattern, sub, style))
            continue
        own = owner(e)
        fade = faded(e)
        # The accent gradient is shared with the progress bar and the slider,
        # so a pressed-in face cannot recolour its stops: it drops the
        # gradient for a flat fill instead.
        if PRESSED_IN.match(own):
            def flat(m):
                return PRESSED if m.group(1) in accent_grads else m.group(0)

            style = re.sub(r"url\(#([^)]+)\)", flat, style)
        for prop in ("fill", "stroke"):
            translucent = fade or alpha_of(style, [prop + "-opacity"])

            def sub(m, own=own, translucent=translucent):
                return role(norm(m.group(0)), own, translucent) or m.group(0)

            style = re.sub(r"(?<![\w-])(?<=%s:)(%s)" % (prop, HEX.pattern), sub, style)
        e.set("style", style)

    tree.write(dst, xml_declaration=True, encoding="UTF-8")


GENERAL = {
    "window.color": token("surface"),
    "inactive.window.color": token("surface"),
    "base.color": SUNKEN,
    "inactive.base.color": SUNKEN,
    "alt.base.color": token("surface_container_low"),
    "inactive.alt.base.color": token("surface_container_low"),
    "button.color": RAISED,
    "light.color": RAISED,
    "mid.light.color": token("surface_container"),
    "dark.color": token("outline"),
    "mid.color": token("outline_variant"),
    "highlight.color": token("primary"),
    "inactive.highlight.color": token("primary"),
    "tooltip.base.color": token("inverse_surface"),
    "tooltip.text.color": token("inverse_on_surface"),
    "disabled.text.color": token("on_surface") + "73",
    "highlight.text.color": token("on_primary"),
    "inactive.highlight.text.color": token("on_primary"),
    "link.color": token("primary"),
    "link.visited.color": token("tertiary"),
    "progress.indicator.text.color": token("on_surface"),
}

# The shell draws no blur and no translucent window, so neither does this.
SWITCHES = {
    "translucent_windows": "false",
    "blurring": "false",
    "popup_blurring": "false",
    "composite": "true",
}

NAMED = {"white": "#ffffff", "black": "#000000"}


def recolor_config(src, dst):
    out = []
    section = ""
    for line in open(src):
        if line.startswith("["):
            section = line.strip().strip("[]")
        m = re.match(r"^([\w.]+)=(.*)$", line.rstrip("\n"))
        if not m:
            out.append(line)
            continue
        key, value = m.group(1), m.group(2)
        if key in SWITCHES:
            value = SWITCHES[key]
        elif key in GENERAL:
            value = GENERAL[key]
        elif key.endswith(".color") and key != "text.shadow.color":
            lit = NAMED.get(value.lower(), value)
            if HEX.fullmatch(lit):
                light = lightness(norm(lit))
                on_fill = "on_surface" if section in PRESSED_IN_SECTIONS else "on_primary"
                value = token(on_fill) if light > 0.6 else token("on_surface")
        out.append("%s=%s\n" % (key, value))
    with open(dst, "w") as f:
        f.writelines(out)


def main():
    svg, config, svg_out, config_out = sys.argv[1:5]
    recolor_svg(svg, svg_out)
    recolor_config(config, config_out)


main()
