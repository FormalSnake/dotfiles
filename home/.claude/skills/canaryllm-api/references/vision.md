# Vision

Detection endpoints are **queued** (`POST` → `queueId` → poll
`/api/llm/queue/result`). Training, listing, auto-label, and model management
return directly. All take Bearer auth; detection endpoints accept optional `tag`
and `service`. Images are **base64-encoded** (max 50 MB per image unless noted).

---

## Object detection — `POST /api/vision/detect`

| Field | Type | Notes |
|---|---|---|
| `image` | string **(req)** | base64, ≤50 MB |
| `model` | string | detection model id |
| `confidence` | number | 0–1 threshold |
| `classes` | integer[] | restrict to class indices |

## Zero-shot detection — `POST /api/vision/detect/zero-shot`

Detect arbitrary objects described in text (no training).

| Field | Type | Notes |
|---|---|---|
| `image` | string **(req)** | base64, ≤50 MB |
| `prompt` | string **(req)** | 1–1000 chars — what to find |
| `confidence` | number | 0–1 |

## Face detection — `POST /api/vision/detect/faces`

Detects faces, optionally blurs them.

| Field | Type | Notes |
|---|---|---|
| `image` | string **(req)** | base64, ≤50 MB |
| `model` | string | `haarcascade`, `mediapipe`, `yolo-face` |
| `blur` | boolean | blur detected faces |
| `blurStrength` | integer | 1–255 |
| `confidence` | number | 0–1 |
| `minSize` | integer | min face size px |
| `scaleFactor` | number | 1–2 (haarcascade) |
| `minNeighbors` | integer | 1–20 (haarcascade) |

---

## Custom model training

### Start a job — `POST /api/vision/train`
Provide a dataset via `datasetB64` (base64 archive) **or** `datasetUrl`.
Optional: `baseModel`, `classes` (string[]), `epochs` (1–1000),
`imageSize` (32–1280), `tag`. Returns a job (see status fields below).

### List jobs — `GET /api/vision/train`
### Job status — `GET /api/vision/train/{jobId}`
Returns `status` (`pending|training|completed|failed`), `baseModel`, `classes`,
`epochs`, `imageSize`, `progress`, `currentEpoch`, `metrics`, `outputModel`,
`error`, and timestamps.

### Auto-label — `POST /api/vision/auto-label`
Label images with zero-shot detection to bootstrap a dataset.
`images` (base64[], 1–1000) **and** `classes` (string[], 1–100) required; optional
`confidence`, `outputFormat`, `valSplit` (0.05–0.5), `tag`.

### Auto-label + train — `POST /api/vision/auto-train`
One shot: auto-label then start training. `images` (base64[], **10**–1000) and
`classes` (1–100) required; optional `baseModel`, `confidence`,
`imageSize` (32–1280), `epochs` (1–1000), `tag`.

---

## Model management
- `GET /api/vision/models` — list available vision models (`ModelInfo`).
- `DELETE /api/vision/models/{modelId}` — delete a custom model.
