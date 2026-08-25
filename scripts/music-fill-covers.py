#!/usr/bin/env python3
"""Give every artless album a cover.

Two sources, tried in order. A remix or an edit takes the original release's
art, so "Nevada - Slowed & Reverb" ends up with Vicetone's Nevada cover; the
title is matched with the same progressive suffix stripping the playlist and
listens agents use. Whatever is left gets a generated cover: the album title
over a mesh gradient whose colours are hashed from artist and album, so a
re-run repaints the same one.

Which albums have no art comes from Navidrome rather than from a directory
walk, because embedded pictures count and half this library is loose singles
under Non-Album/ and _edits/ where the folder name says nothing about art.

No file and no embedded picture does not mean blank, though: CoverArtPriority
ends in `external`, so the metadata agents supply the real cover for anything
they can match. Every candidate is asked for over the Subsonic API first and
skipped if a real image comes back, because writing a placeholder over a cover
Apple Music or Deezer already found is a straight downgrade.

Writes cover.jpg and leaves folder.jpg alone, same as music-safe-covers.sh:
cover.* outranks folder.* in Navidrome's CoverArtPriority and Lidarr's Kodi
consumer only ever writes folder.jpg, so an artist refresh cannot undo this and
reverting is deleting the cover.jpg files.
"""
import argparse
import colorsys
import concurrent.futures
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

LIBRARY = os.environ.get("MUSIC_LIBRARY", "/Volumes/Music/library")
NAVIDROME = os.environ.get("NAVIDROME_URL", "http://localhost:4533")
# Navidrome does not fail an artwork request for an album it has nothing for:
# it answers with the grey note it embeds in the binary. Bytes are the only
# thing separating that from a real cover. If upstream ever changes the asset
# every album reads as covered and this script writes nothing, which is the
# harmless way for it to be wrong.
PLACEHOLDER_MD5 = "83d193cefca2810f217cffd533241508"
FONT_TITLE = os.path.expanduser("~/Library/Fonts/SpotifyMix-Black.otf")
FONT_META = os.path.expanduser("~/Library/Fonts/SpotifyMix-Medium.otf")
# SpotifyMix is Latin only, so a Cyrillic title renders as a row of blanks.
# ImageMagick has no font fallback of its own; this is the substitute.
FONT_UNICODE = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"

SIZE = 1200
MARGIN = 90
TITLE_BOX = SIZE - MARGIN * 2
TITLE_MAX_H = 560

# Same rule as the listens agent's NOISE, plus the suffixes only this library's
# hardstyle and nightcore rips carry. It exists here to find the *original* of
# an edit, so over-stripping costs a wrong cover, not a wrong scrobble.
NOISE = re.compile(
    r"\s*[-(\[]\s*(slowed.*|super slowed|sped up.*|speed up.*|nightcore.*|"
    r"hardstyle.*|hardtekk.*|jumpstyle.*|edit|remix|vip|instrumental|"
    r"extended mix|radio edit|club mix|bassline club mix|the dark triad|"
    r"viral version.*|feat\..*|ft\..*|with .*)\s*[)\]]?\s*$",
    re.I)

IMAGE_PRIORITY = ("cover", "front", "folder", "album")


def norm(s):
    s = unicodedata.normalize("NFKD", s or "")
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.replace("’", "'").replace("&", "and")
    return re.sub(r"[^a-z0-9]", "", s.lower())


def variants(title):
    """Progressively stripped forms of a title, most specific first."""
    out, t = [], title
    for _ in range(4):
        out.append(t)
        stripped = NOISE.sub("", t).strip(" -–")
        if stripped == t or not stripped:
            break
        t = stripped
    out.append(re.sub(r"\s*\(.*?\)\s*", " ", title).strip())
    return [v for v in dict.fromkeys(out) if v]


def sql(query):
    # sqlite3 runs inside the container: reading navidrome.db from macOS across
    # OrbStack's virtiofs destroys it (docs/music.md).
    r = subprocess.run(["docker", "exec", "navidrome", "sqlite3",
                        "-separator", "\x1f", "/data/navidrome.db", query],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("navidrome is not answering, nothing written\n" + r.stderr.strip())
    return [l.split("\x1f") for l in r.stdout.splitlines() if l]


def albums():
    """Every present album, with its folders and whatever art it already has."""
    rows = sql("""
        select a.id, a.album_artist, a.name, a.max_year, a.embed_art_path,
               f.path, f.name, f.image_files
        from album a
        join json_each(a.folder_ids) fi
        join folder f on f.id = fi.value
        where a.missing = 0 and f.missing = 0
    """)
    out = {}
    for aid, artist, name, year, embed, fpath, fname, images in rows:
        album = out.setdefault(aid, {
            "id": aid, "artist": artist, "name": name,
            "year": year if year not in ("0", "") else "",
            "embed": embed, "dirs": [], "images": [],
        })
        rel = fname if fpath == "." else os.path.join(fpath, fname)
        album["dirs"].append(rel)
        album["images"] += [os.path.join(rel, i) for i in json.loads(images or "[]")]
    for album in out.values():
        album["dirs"].sort()
    return out


def nd_auth():
    """Subsonic credentials for the art check, read out of the audiomuse
    container: it is the one part of the stack seeded with a real Navidrome
    login rather than an API key, and this check has to ask as a client does."""
    env = subprocess.run(["docker", "exec", "audiomuse-flask", "env"],
                         capture_output=True, text=True)
    creds = dict(l.split("=", 1) for l in env.stdout.splitlines() if "=" in l)
    user, password = creds.get("NAVIDROME_USER"), creds.get("NAVIDROME_PASSWORD")
    if not user or not password:
        sys.exit("no Navidrome login in the audiomuse container, so there is no "
                 "way to tell a blank album from one the agents already cover")
    salt = hashlib.sha1(user.encode()).hexdigest()[:16]
    return {"u": user, "s": salt, "v": "1.16.1", "c": "fill-covers",
            "t": hashlib.md5((password + salt).encode()).hexdigest()}


def agent_art(album, auth):
    """Whether Navidrome already shows a real cover for this album, fetched from
    its metadata agents. An unreachable server counts as covered, so a stack
    that is half up cannot paint placeholders over albums that have art."""
    q = urllib.parse.urlencode(dict(auth, id="al-" + album["id"], size="300"))
    try:
        with urllib.request.urlopen(
                NAVIDROME + "/rest/getCoverArt.view?" + q, timeout=60) as r:
            if not r.headers.get_content_type().startswith("image/"):
                return False
            return hashlib.md5(r.read()).hexdigest() != PLACEHOLDER_MD5
    except urllib.error.URLError:
        return True


def art_source(album, work):
    """A host path to this album's existing art, extracting it if it is only
    embedded in a track."""
    for want in IMAGE_PRIORITY:
        for rel in album["images"]:
            if os.path.splitext(os.path.basename(rel))[0].lower() == want:
                return os.path.join(LIBRARY, rel)
    if album["images"]:
        return os.path.join(LIBRARY, album["images"][0])
    if album["embed"]:
        out = os.path.join(work, "embedded.jpg")
        subprocess.run(["ffmpeg", "-v", "error", "-y",
                        "-i", os.path.join(LIBRARY, album["embed"]),
                        "-an", "-c:v", "copy", out],
                       capture_output=True)
        if os.path.exists(out) and os.path.getsize(out):
            return out
    return None


def build_index(pool):
    """Normalised title (and each stripped form of it) to the albums that have
    art under that title."""
    index = {}
    for aid, album in pool.items():
        for v in variants(album["name"]):
            key = norm(v)
            if key:
                index.setdefault(key, []).append(aid)
    return index


def find_original(target, index, pool):
    """The album an edit was made from: same artist first, then a title that
    only one artist in the library claims."""
    for v in variants(target["name"]):
        key = norm(v)
        cands = [pool[i] for i in index.get(key, [])]
        if not cands:
            continue
        same = [c for c in cands if norm(c["artist"]) == norm(target["artist"])]
        if same:
            return same[0]
        if len({norm(c["artist"]) for c in cands}) == 1:
            return cands[0]
    return None


def font_for(text, latin):
    """`latin` unless the text needs a script SpotifyMix does not draw.
    Letters only: the curly apostrophe and the dashes are covered."""
    if any(ord(c) > 0x2AF and unicodedata.category(c).startswith("L") for c in text):
        return FONT_UNICODE
    return latin


def ink_for(bg):
    """Palettes run from near-black to washed-out pastel, so the ink follows
    the background and the background is pushed away from it."""
    lum = float(subprocess.run(
        ["magick", bg, "-colorspace", "Gray", "-format", "%[fx:mean]", "info:"],
        capture_output=True, text=True, check=True).stdout)
    if lum > 0.5:
        return "#12100Ee6", "#12100Ea6", "14x0"
    return "#FFFFFFf2", "#FFFFFFb3", "-14x0"


def hexc(h, s, l):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360.0, l, s)
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))


def gradient(album, out):
    """A four-point mesh gradient keyed to the album, so the same album always
    comes out the same colour and neighbouring ones never do."""
    seed = hashlib.sha1(("%s/%s" % (album["artist"], album["name"])).encode()).digest()
    n = list(seed)
    hue = n[0] / 255.0 * 360
    # A second hue a fifth of the wheel away, either side, keeps the blend from
    # going muddy the way complementaries do. Lightness stays under half so the
    # ink is white on every cover and the title never fights the background.
    spread = 40 + n[1] / 255.0 * 50
    if n[2] & 1:
        spread = -spread
    stops = [
        (hue, 0.70 + n[3] / 255.0 * 0.20, 0.42 + n[4] / 255.0 * 0.10),
        (hue + spread, 0.72 + n[5] / 255.0 * 0.20, 0.34 + n[6] / 255.0 * 0.10),
        (hue + spread * 1.8, 0.65 + n[7] / 255.0 * 0.25, 0.24 + n[8] / 255.0 * 0.10),
        (hue - spread * 0.4, 0.80, 0.12 + n[9] / 255.0 * 0.08),
    ]
    corners = [(30, 40), (360, 25), (35, 365), (370, 355)]
    points = " ".join(
        "%d,%d %s" % (x + n[10 + i] % 40 - 20, y + n[14 + i] % 40 - 20, hexc(*c))
        for i, ((x, y), c) in enumerate(zip(corners, stops)))
    # Rendered at 400px and enlarged, the same trick the blurred wash in
    # music-safe-covers.sh uses: a mesh this soft carries no detail worth the
    # cost of computing it at full size.
    subprocess.run(["magick", "-size", "400x400", "xc:", "-sparse-color",
                    "shepards", points, "-blur", "0x14",
                    "-resize", "%dx%d!" % (SIZE, SIZE), out], check=True)


def render(album, bg, dest):
    """Title over the background, artist and year along the bottom."""
    title = album["name"]
    font_title = font_for(title, FONT_TITLE)
    ink, ink_meta, wash = ink_for(bg)

    # caption: wraps at the box width but grows unbounded in height, so step the
    # size down until a long title fits rather than letting it run off the cover.
    for pointsize in (132, 120, 108, 96, 84, 72, 64, 56, 48):
        h = int(subprocess.run(
            ["magick", "-background", "none", "-font", font_title,
             "-pointsize", str(pointsize), "-size", "%dx" % TITLE_BOX,
             "caption:" + title, "-format", "%[fx:h]", "info:"],
            capture_output=True, text=True, check=True).stdout)
        if h <= TITLE_MAX_H:
            break

    work = os.path.dirname(bg)
    title_png = os.path.join(work, "title.png")
    # Its own invocation because -size is global in ImageMagick and survives the
    # parentheses: sharing a command line with the meta text makes annotate
    # auto-fit both lines to the title box.
    subprocess.run(["magick", "-background", "none", "-fill", ink,
                    "-font", font_title, "-pointsize", str(pointsize),
                    "-size", "%dx" % TITLE_BOX, "caption:" + title, title_png],
                   check=True)

    byline = album["artist"].upper()
    kerning = "8" if len(byline) <= 26 else "3"
    subprocess.run([
        "magick", bg, "-brightness-contrast", wash,
        title_png, "-gravity", "northwest",
        "-geometry", "+%d+%d" % (MARGIN, MARGIN), "-composite",
        "-font", font_for(byline, FONT_META), "-pointsize", "34", "-fill", ink_meta,
        "-kerning", kerning, "-gravity", "southwest",
        "-annotate", "+%d+%d" % (MARGIN, MARGIN), byline,
        "-kerning", "0", "-gravity", "southeast",
        "-annotate", "+%d+%d" % (MARGIN, MARGIN), album["year"],
        "-quality", "92", dest], check=True)
    return pointsize


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("artists", nargs="*",
                    help="limit to these album artists (default: the whole library)")
    ap.add_argument("--dry-run", action="store_true",
                    help="list what would be written and why")
    ap.add_argument("--force", action="store_true",
                    help="overwrite a cover.jpg that is already there")
    args = ap.parse_args()

    for font in (FONT_TITLE, FONT_META):
        if not os.path.isfile(font):
            sys.exit("missing font: " + font)

    pool = albums()
    artless = {i: a for i, a in pool.items() if not a["images"] and not a["embed"]}
    withart = {i: a for i, a in pool.items() if i not in artless}
    index = build_index(withart)

    wanted = {norm(a) for a in args.artists}
    targets = sorted(artless.values(), key=lambda a: (a["artist"].lower(), a["name"].lower()))
    if wanted:
        targets = [t for t in targets if norm(t["artist"]) in wanted]
    if not targets:
        print("nothing without a cover")
        return

    auth = nd_auth()
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        covered = list(ex.map(lambda t: agent_art(t, auth), targets))
    for album, has in zip(targets, covered):
        if has and args.dry_run:
            print("  %-6s %s - %s" % ("agent", album["artist"], album["name"]))
    targets = [t for t, has in zip(targets, covered) if not has]
    if any(covered):
        print("  %d album(s) left alone: navidrome already shows an agent cover"
              % sum(covered))
    if not targets:
        return

    work = tempfile.mkdtemp()
    try:
        for album in targets:
            label = "%s - %s" % (album["artist"], album["name"])
            dirs = [d for d in album["dirs"]
                    if args.force or not os.path.exists(
                        os.path.join(LIBRARY, d, "cover.jpg"))]
            if not dirs:
                # Loose singles share a folder under Non-Album/, and a folder
                # holds one cover: the first album to claim it covers the rest.
                print("  share  %s" % label)
                continue

            original = find_original(album, index, withart)
            source = art_source(original, work) if original else None
            # A track that exists in both _edits/ and Non-Album/ is one album
            # over two folders, and each folder needs its own copy.
            copies = " x%d" % len(dirs) if len(dirs) > 1 else ""

            if args.dry_run:
                print("  %-6s %-58s %s" % (
                    "carry" if source else "gen", label,
                    "from %s - %s%s" % (original["artist"], original["name"], copies)
                    if source else copies.strip()))
                continue

            built = os.path.join(work, "cover.jpg")
            if source:
                if os.path.splitext(source)[1].lower() in (".jpg", ".jpeg"):
                    shutil.copyfile(source, built)
                else:
                    subprocess.run(["magick", source, "-quality", "92", built],
                                   check=True)
                note = "from %s - %s%s" % (original["artist"], original["name"], copies)
            else:
                bg = os.path.join(work, "bg.png")
                gradient(album, bg)
                note = "%spt%s" % (render(album, bg, built), copies)

            for d in dirs:
                shutil.copyfile(built, os.path.join(LIBRARY, d, "cover.jpg"))
            print("  %-6s %-58s %s" % ("carry" if source else "gen", label, note))
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
