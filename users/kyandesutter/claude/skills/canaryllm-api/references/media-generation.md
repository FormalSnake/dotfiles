# Media generation & audio

All endpoints here are **queued** (`POST` → `queueId` → poll
`/api/llm/queue/result`). The finished `data.result` holds the provider payload —
typically base64 data and/or URLs plus metadata. All accept optional `tag`
(≤100) and `service`. Auth: Bearer token.

---

## Images — `POST /api/llm/generate-image`

| Field | Type | Notes |
|---|---|---|
| `provider` | string **(req)** | `openai`, `gemini`, `vertex`, `xai`, `ollama` |
| `prompt` | string **(req)** | 1–10000 chars |
| `model` | string | provider default if omitted |
| `n` | integer | 1–10 images |
| `size` | string | e.g. `1024x1024` (provider-specific) |
| `aspectRatio` | string | e.g. `16:9` |
| `quality` | string | `standard` \| `hd` \| `ultra` |

```bash
curl -s "$CANARYLLM_BASE_URL/api/llm/generate-image" \
  -H "Authorization: Bearer $CANARYLLM_API_KEY" -H "Content-Type: application/json" \
  -d '{"provider":"openai","prompt":"a watercolor fox","n":1,"quality":"hd"}'
```

---

## Video — `POST /api/llm/generate-video`

| Field | Type | Notes |
|---|---|---|
| `provider` | string **(req)** | `gemini`, `vertex`, `xai` |
| `prompt` | string **(req)** | 1–10000 chars |
| `model`, `aspectRatio`, `resolution` | string | provider-specific |
| `durationSeconds` | integer | 1–60 |
| `numberOfVideos` | integer | 1–4 |
| `imageUrl` | string (uri) | image-to-video seed |

### Upload a video — `POST /api/llm/upload-video`
`multipart/form-data` with a `video` file field. Returns `{ data: { fileId, mimeType } }`.
Use the `fileId` in a chat `content` part: `{ "type": "video", "fileId": "<uuid>" }`.

---

## Text-to-speech — `POST /api/llm/generate-audio`

| Field | Type | Notes |
|---|---|---|
| `provider` | string **(req)** | `elevenlabs`, `mlxaudio` |
| `text` | string **(req)** | 1–100000 chars |
| `model`, `voiceId` | string | discover voices via `/api/llm/voices?provider=` or `/api/public/voices` |
| `outputFormat` | string | `mp3_44100_128`, `mp3_44100_192`, `pcm_16000`, `pcm_22050`, `pcm_24000`, `pcm_44100` |
| `voiceSettings` | object | `{ stability 0–1, similarityBoost 0–1, style 0–1, useSpeakerBoost bool }` |
| `languageCode` | string | ≤10 |
| `previousText` / `nextText` | string | ≤5000, context for prosody |
| `applyTextNormalization` | string | `auto` \| `on` \| `off` |
| `previousRequestIds` | string[] | ≤3 ElevenLabs request IDs for prosody continuity |

---

## Speech-to-text — `POST /api/llm/transcribe`

| Field | Type | Notes |
|---|---|---|
| `provider` | string **(req)** | `elevenlabs`, `mlxaudio` |
| `audio` | string **(req)** | base64-encoded audio |
| `mimeType` | string **(req)** | e.g. `audio/mp3`, `audio/wav` |
| `model`, `language` | string | optional |

---

## Sound effects — `POST /api/llm/generate-sound-effect`

| Field | Type | Notes |
|---|---|---|
| `text` | string **(req)** | 1–10000 chars |
| `model` | string | |
| `durationSeconds` | number | 0.5–30 |
| `promptInfluence` | number | 0–1 |
| `loop` | boolean | seamless loop |

---

## Music — `POST /api/llm/generate-music`

| Field | Type | Notes |
|---|---|---|
| `prompt` | string **(req)** | 1–10000 chars |
| `model` | string | |
| `durationMs` | integer | 3000–600000 |
| `forceInstrumental` | boolean | |

---

## Multi-speaker dialogue — `POST /api/llm/generate-dialogue`

Each turn carries its own `voiceId`. **Only `eleven_v3` is supported**; max 10
unique voice IDs per request.

| Field | Type | Notes |
|---|---|---|
| `inputs` | array **(req)** | 1–100 turns, each `{ text (1–50000), voiceId }` |
| `model` | string | `eleven_v3` only |
| `outputFormat` | string | same enum as TTS |
| `languageCode` | string | ≤10 |
| `voiceSettings` | object | `{ stability, similarityBoost, style, useSpeakerBoost }` |
| `seed` | integer | 0–4294967295 |
| `applyTextNormalization` | string | `auto` \| `on` \| `off` |

```json
{
  "model": "eleven_v3",
  "inputs": [
    { "text": "Hey, did it finish?", "voiceId": "voiceA" },
    { "text": "Yep, just rendered. [laughs]", "voiceId": "voiceB" }
  ]
}
```

---

## Discovering voices & models
- `GET /api/public/voices` (no auth) / `GET /api/llm/voices?provider=elevenlabs` — `VoiceInfo`: `id, name, provider, category, gender, accent, age, language, description, preview_url, labels`.
- `POST /api/public/voices/preview` (no auth) — preview a voice; **`provider` must be `mlxaudio`**, plus `voiceId`. Returns base64 `audio`.
- `GET /api/public/models` (no auth) — providers, `ModelInfo` (`id, name, contextWindow, maxOutputTokens`, cost fields, `capabilities`).
