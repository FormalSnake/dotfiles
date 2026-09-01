#!/usr/bin/env python3
"""CanaryLLM client for the appstore-screenshots skill.

Talks to the gateway's async queue: submit to /api/llm/generate-image, poll
/api/llm/queue/result until HTTP 200, write the returned base64 PNGs.

  enhance   image-to-image: scaffold + prompt -> enhanced screenshot(s)
  generate  text-to-image (backgrounds, decoration experiments)
  resize    centre-crop + resize a PNG to exact App Store dimensions

Key resolution: ~/.claude/secrets/canaryllm-api-key, else $CANARYLLM_API_KEY.
The key is never printed.
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = os.environ.get("CANARYLLM_BASE_URL", "https://canaryllm.canarycoders.es").rstrip("/")
KEY_FILE = Path.home() / ".claude/secrets/canaryllm-api-key"
DEFAULT_MODEL = "gemini-3-pro-image"


def api_key():
    # KEY_FILE first: the fish-env CANARYLLM_API_KEY is a different gateway key
    key = (KEY_FILE.read_text().strip() if KEY_FILE.exists() else "") or os.environ.get(
        "CANARYLLM_API_KEY", ""
    )
    if not key:
        sys.exit(f"canaryllm: no API key: set $CANARYLLM_API_KEY or create {KEY_FILE}")
    return key


def post(path, body, key):
    req = urllib.request.Request(
        f"{BASE}{path}",
        data=json.dumps(body).encode(),
        # Cloudflare fronts the gateway and 403s the default python-urllib agent
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                 "User-Agent": "appstore-screenshots-skill/1.0"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, {"error": raw.decode(errors="replace")[:500]}


def run_task(body, key, timeout_s, attempts=3):
    # Gemini image models 503 under load; resubmitting after a pause usually lands
    for attempt in range(1, attempts + 1):
        code, resp = post("/api/llm/generate-image", body, key)
        if code != 200 or not resp.get("success"):
            sys.exit(f"canaryllm: submit failed ({code}): {resp.get('error', resp)}")
        qid = resp["data"]["queueId"]
        print(f"queued {qid} (attempt {attempt})", file=sys.stderr)
        deadline = time.time() + timeout_s
        while time.time() < deadline:
            code, resp = post("/api/llm/queue/result", {"queueId": qid}, key)
            if code == 200:
                return resp["data"]["result"]
            if code != 202:
                err = str(resp.get("error", resp))
                if code >= 500 and attempt < attempts:
                    print(f"transient failure, retrying in 25s: {err[:160]}", file=sys.stderr)
                    time.sleep(25)
                    break
                sys.exit(f"canaryllm: task failed ({code}): {err}")
            time.sleep(3)
        else:
            sys.exit(f"canaryllm: timed out after {timeout_s}s (queueId {qid})")


def write_images(result, out_dir, basename):
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    images = result.get("images", [])
    if not images:
        sys.exit(f"canaryllm: no images in result: {json.dumps(result)[:300]}")
    for i, img in enumerate(images, 1):
        suffix = "" if len(images) == 1 else f"-{i}"
        p = out_dir / f"{basename}{suffix}.png"
        p.write_bytes(base64.b64decode(img["data"]))
        paths.append(p)
        print(p)
    return paths


def do_resize(src, dst, size):
    from PIL import Image  # lazy: only this subcommand needs Pillow

    tw, th = (int(v) for v in size.lower().split("x"))
    im = Image.open(src).convert("RGB")
    scale = max(tw / im.width, th / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    left, top = (im.width - tw) // 2, (im.height - th) // 2
    im.crop((left, top, left + tw, top + th)).save(dst, "PNG")
    print(f"{dst} ({tw}x{th})")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    en = sub.add_parser("enhance")
    en.add_argument("--image", required=True, help="scaffold PNG to enhance")
    en.add_argument("--prompt", help="prompt text (or use --prompt-file)")
    en.add_argument("--prompt-file")
    en.add_argument("--model", default=DEFAULT_MODEL)
    en.add_argument("--n", type=int, default=1)
    en.add_argument("--out", default=".", help="output directory")
    en.add_argument("--basename", default="v1")
    en.add_argument("--resize", metavar="WxH", help="also write <basename>-resized.png")
    en.add_argument("--timeout", type=int, default=420)

    ge = sub.add_parser("generate")
    ge.add_argument("--prompt", required=True)
    ge.add_argument("--model", default=DEFAULT_MODEL)
    ge.add_argument("--n", type=int, default=1)
    ge.add_argument("--aspect", help="e.g. 9:16")
    ge.add_argument("--out", default=".")
    ge.add_argument("--basename", default="generated")
    ge.add_argument("--timeout", type=int, default=420)

    rs = sub.add_parser("resize")
    rs.add_argument("--image", required=True)
    rs.add_argument("--size", required=True, metavar="WxH")
    rs.add_argument("--out", required=True)

    args = ap.parse_args()

    if args.cmd == "resize":
        do_resize(args.image, args.out, args.size)
        return

    key = api_key()
    prompt = args.prompt or (Path(args.prompt_file).read_text() if getattr(args, "prompt_file", None) else "")
    if not prompt:
        sys.exit("canaryllm: --prompt or --prompt-file required")

    body = {"provider": "gemini", "model": args.model, "prompt": prompt, "n": args.n,
            "tag": "appstore-screenshots"}
    if args.cmd == "enhance":
        body["referenceImages"] = [base64.b64encode(Path(args.image).read_bytes()).decode()]
    elif args.aspect:
        body["aspectRatio"] = args.aspect

    result = run_task(body, key, args.timeout)
    paths = write_images(result, Path(args.out), args.basename)
    if args.cmd == "enhance" and args.resize:
        for p in paths:
            do_resize(p, p.with_name(p.stem + "-resized.png"), args.resize)


if __name__ == "__main__":
    main()
