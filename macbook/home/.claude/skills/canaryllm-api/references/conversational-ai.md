# Conversational AI (voice agents)

Build interview/conversation voice agents on top of ElevenLabs Conversational AI.
The flow: **create a template** (the agent's persona + behaviour) → **create a
session** from it (returns a short-lived signed WebRTC URL the client connects to).
These endpoints respond directly (not queued). Bearer auth required.

---

## Templates — `/api/convagents/templates`

### Create — `POST` (→ 201)
Required: `name` (1–255), `type` (`interview` | `conversation`),
`systemPrompt` (1–10000).

Common optional fields:
| Field | Notes |
|---|---|
| `description` | ≤2000 |
| `firstMessage` | ≤1000, agent's opening line |
| `voiceId`, `voiceModel` | ElevenLabs voice (≤100 each) |
| `voiceSettings` | `{ stability 0–1, speed 0.7–1.2, similarityBoost 0–1 }` — lower stability renders audio tags like `[laughs]` more expressively |
| `language` | ≤100 |
| `languagePresets` | map of lang → `{ firstMessage }` |
| `llmProvider` | `gemini, vertex, openai, anthropic, xai, perplexity, lmstudio` |
| `llmModel` | ≤100 |
| `clientWebhookUrl` | uri; `webhookSecret` ≤255 |
| `maxDurationSeconds` | 30–3600 |
| `tag` | ≤100 |
| `questions` | ≤50 × `{ question (1–2000), context?, isRequired? }` — for `interview` type |
| `tools` | ≤7, each `{ name, description? }`; `name` ∈ `end_call`, `language_detection`, `transfer_to_agent`, `transfer_to_number`, `skip_turn`, `play_keypad_touch_tone`, `voicemail_detection` |

### List — `GET /api/convagents/templates`
### Get — `GET /api/convagents/templates/{id}`
### Update — `PUT /api/convagents/templates/{id}`
Same fields as create; most are nullable so you can clear them. `{id}` is an integer.
### Delete — `DELETE /api/convagents/templates/{id}`

```bash
curl -s "$CANARYLLM_BASE_URL/api/convagents/templates" \
  -H "Authorization: Bearer $CANARYLLM_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "name": "Screening interview",
    "type": "interview",
    "systemPrompt": "You are a friendly technical screener.",
    "firstMessage": "Hi! Ready to start?",
    "llmProvider": "anthropic",
    "questions": [{ "question": "Tell me about a recent project.", "isRequired": true }]
  }'
```

---

## Sessions — `/api/convagents/sessions`

### Create — `POST` (→ 201)
Body: `templateId` (integer ≥1, required), optional `metadata` (free-form object).
Returns `{ data: { session, signedUrl, expiresIn: 900 } }` — `signedUrl` is the
WebRTC URL the client uses to talk to the agent; it expires in 900 s.

### List — `GET /api/convagents/sessions?templateId=<id>` (templateId optional)
### Get — `GET /api/convagents/sessions/{id}`

---

## Signed URL for an existing agent — `POST /api/agents/signed-url`
For an ElevenLabs agent you already have. Body: `agentId` (1–100, required),
optional `sessionId` (integer). Returns `{ data: { signedUrl, expiresIn: 900, sessionId } }`.
