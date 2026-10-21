# Native chat completions — `POST /api/llm/complete`

**Queued.** Returns a `queueId`; poll `/api/llm/queue/result` or stream
`/api/llm/queue/stream`. (For a simple synchronous chat where you just want text
back, prefer the compat layer in `compat-endpoints.md` instead.)

Use this native endpoint when you need CanaryLLM-specific controls: thinking
budgets, web search, prompt caching, JSON-schema output, multimodal content
parts (images, PDFs, video), or usage tags.

## Request body

| Field | Type | Notes |
|---|---|---|
| `provider` | string **(required)** | `openai`, `gemini`, `vertex`, `anthropic`, `xai`, `lmstudio`, `perplexity` |
| `messages` | array **(required)** | 1–100 `Message` objects (see below) |
| `model` | string | provider-specific model id; omit to use the provider default |
| `temperature` | number | 0–2 |
| `maxTokens` | integer | ≥1 |
| `topP` | number | 0–1 |
| `frequencyPenalty` / `presencePenalty` | number | −2 to 2 |
| `stop` | string[] | stop sequences |
| `stream` | boolean | stream chunks (consume via `/api/llm/queue/stream`) |
| `responseFormat` | string | `text`, `json`, or `json_schema` |
| `jsonSchema` | object | the schema, when `responseFormat: json_schema` |
| `tools` | array | `ToolDefinition[]` for function calling (see below) |
| `toolChoice` | string or object | `auto` \| `none` \| `required`, or `{type:"function", function:{name}}` |
| `thinkingMode` | object | `{ enabled: bool, budget?: number }` — `budget` in tokens, `-1` = dynamic |
| `webSearch` | object | `{ enabled: bool, maxUses?, allowedDomains?, blockedDomains?, recencyFilter?, userLocation?, xSearch? }` |
| `cache` | object | `{ enabled: bool, ttl?: number }` — prompt caching, `ttl` in seconds |
| `tag` | string | ≤100 chars, usage label |
| `service` | string | named service/key routing |
| `timeout` | integer | 1000–300000 ms |

### `Message`
```jsonc
{
  "role": "system" | "user" | "assistant" | "tool",
  "content": "string"        // OR an array of content parts (below)
  // assistant tool calls:
  "toolCalls": [{ "id": "...", "type": "function", "function": { "name": "...", "arguments": "{...}" } }],
  "toolCallId": "..."         // on a role:"tool" message, the call it answers
}
```

### Multimodal content parts (`content` as an array)
- **Text:** `{ "type": "text", "text": "..." }` (≤100k chars)
- **Image:** `{ "type": "image", "data": "<base64>", "mimeType": "image/png" }` (≤10 MB)
- **Document (PDF):** `{ "type": "document", "data": "<base64>", "mimeType": "application/pdf" }` (≤10 MB)
- **Video:** `{ "type": "video", "data": "<base64>", "mimeType": "video/mp4" }` (≤20 MB)
  — or reference an uploaded video: `{ "type": "video", "fileId": "<uuid>" }`
  (upload first via `POST /api/llm/upload-video`, multipart field `video`).

### `ToolDefinition`
```json
{ "type": "function", "function": { "name": "get_weather", "description": "...", "parameters": { "type": "object", "properties": { } } } }
```

### `webSearch` extras
- `recencyFilter`: `month` | `week` | `day` | `hour`
- `userLocation`: `{ country, city, region, timezone }`
- `xSearch` (xAI): `{ allowedHandles[], excludedHandles[], fromDate, toDate, enableImageUnderstanding, enableVideoUnderstanding }`

## Examples

Basic completion — submit, then poll `/api/llm/queue/result` with the returned
`queueId` (see SKILL.md for the loop):
```bash
curl -s "$CANARYLLM_BASE_URL/api/llm/complete" \
  -H "Authorization: Bearer $CANARYLLM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "anthropic",
    "model": "claude-sonnet-4-5",
    "messages": [{ "role": "user", "content": "Summarize the CAP theorem in 2 sentences." }],
    "maxTokens": 300
  }'
```

With extended thinking + web search:
```json
{
  "provider": "gemini",
  "messages": [{ "role": "user", "content": "What changed in the news this week about X?" }],
  "thinkingMode": { "enabled": true, "budget": -1 },
  "webSearch": { "enabled": true, "recencyFilter": "week", "maxUses": 3 }
}
```

Structured JSON output:
```json
{
  "provider": "openai",
  "messages": [{ "role": "user", "content": "Extract name and age." }],
  "responseFormat": "json_schema",
  "jsonSchema": { "type": "object", "properties": { "name": {"type":"string"}, "age": {"type":"integer"} }, "required": ["name","age"] }
}
```

Vision (describe an image):
```json
{
  "provider": "anthropic",
  "messages": [{ "role": "user", "content": [
    { "type": "text", "text": "What's in this image?" },
    { "type": "image", "data": "<base64>", "mimeType": "image/jpeg" }
  ]}]
}
```

The completed `data.result` is the provider's completion payload (text, tool
calls, usage). For streaming, set `"stream": true` and read SSE events from
`POST /api/llm/queue/stream` with the `queueId`.
