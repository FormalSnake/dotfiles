# Compatibility endpoints (`/v1/*`) — synchronous drop-in APIs

These mirror the OpenAI, Anthropic, and OpenAI-Responses APIs so you can point an
existing SDK, CLI, or tool at the gateway with no code changes. **They are
synchronous**: the HTTP response *is* the completion (or an SSE stream if you set
`stream: true`). No queue, no polling.

The model field always uses **`provider/model`** format, e.g.
`anthropic/claude-sonnet-4-5`, `openai/gpt-5`, `gemini/gemini-2.5-pro`.

All three require the Bearer token (`Authorization: Bearer $CANARYLLM_API_KEY`).

---

## `POST /v1/chat/completions` — OpenAI Chat Completions

Drop-in for the OpenAI chat completions API. Compatible with pi.dev via a custom
provider in `~/.pi/agent/models.json`.

Key body fields: `model` (required, `provider/model`), `messages` (required,
1–5000; roles `system|developer|user|assistant|tool`; content is a string or an
array of `{type:"text"}` / `{type:"image_url", image_url:{url, detail}}` parts),
`stream`, `temperature` (0–2), `max_tokens`, `top_p`, `frequency_penalty`,
`presence_penalty`, `stop`, `tools`, `tool_choice`, `response_format`
(`{type: "text" | "json_object"}`), and `reasoning_effort`
(`minimal|low|medium|high|xhigh` — maps to extended-thinking budgets;
`xhigh` clamps to `high` where unsupported).

Response: standard `chat.completion` object with `choices[].message`. The
assistant message may include `reasoning_content` (Gemini/Anthropic/xAI thinking;
omitted for providers that hide reasoning, e.g. OpenAI o-series). Streaming emits
`chat.completion.chunk` SSE objects terminated by `data: [DONE]`.

```bash
curl -s "$CANARYLLM_BASE_URL/v1/chat/completions" \
  -H "Authorization: Bearer $CANARYLLM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-sonnet-4-5",
    "messages": [{ "role": "user", "content": "Hello!" }]
  }'
```

Point an OpenAI SDK at it:
```python
from openai import OpenAI
client = OpenAI(base_url="https://canaryllm.canarycoders.es/v1",
                api_key=os.environ["CANARYLLM_API_KEY"])
client.chat.completions.create(model="openai/gpt-5",
                               messages=[{"role": "user", "content": "hi"}])
```

---

## `POST /v1/messages` — Anthropic Messages

Drop-in for the Anthropic Messages API. **Compatible with Claude Code via
`ANTHROPIC_BASE_URL`** — set `ANTHROPIC_BASE_URL=https://canaryllm.canarycoders.es`
and `ANTHROPIC_API_KEY=$CANARYLLM_API_KEY`, then use `provider/model` model ids.

Body: `model` (required), `messages` (required, roles `user|assistant`; content is
a string or blocks: `text`, `image` with `source:{type:"base64",media_type,data}`,
`tool_use`, `tool_result`), `max_tokens` (required), `system` (string or text
blocks), `stream`, `temperature` (0–1), `top_p`, `top_k`, `stop_sequences`,
`tools` (`{name, description, input_schema}`), `tool_choice`
(`{type:"auto"|"any"}` or `{type:"tool", name}`), `metadata.user_id`.

Optional header `anthropic-version` is accepted but not enforced.

Response: a `message` object with `content` blocks (`text` / `tool_use`),
`stop_reason` (`end_turn|max_tokens|stop_sequence|tool_use`), and `usage`.
Streaming emits named SSE events: `message_start`, `content_block_start`, `ping`,
`content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`.
Errors use the Anthropic shape: `{type:"error", error:{type, message}}`.

```bash
curl -s "$CANARYLLM_BASE_URL/v1/messages" \
  -H "Authorization: Bearer $CANARYLLM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-sonnet-4-5",
    "max_tokens": 1024,
    "messages": [{ "role": "user", "content": "Hello!" }]
  }'
```

---

## `POST /v1/responses` — OpenAI Responses

Drop-in for the OpenAI Responses API. **Compatible with Codex CLI** (which dropped
Chat Completions support in 0.125), **Cursor**, and the OpenAI Responses SDK.

Body: `model` (required, `provider/model`), `input` (required — a string or an
array of message / `function_call` / `function_call_output` items; message content
parts use `input_text`, `input_image`, `output_text`), `instructions`, `stream`,
`temperature` (0–2), `top_p`, `max_output_tokens`, `tools`
(`{type:"function", name, description, parameters, strict}`), `tool_choice`
(`auto|required|none` or `{type:"function", name}`), `parallel_tool_calls`,
`metadata`.

Response: a `response` object with `status`
(`completed|failed|in_progress|incomplete`), an `output` array (message /
function_call items), a convenience `output_text` string, and `usage`. Streaming
emits the canonical Responses event sequence (`response.created`,
`response.output_text.delta`, `response.completed`, `error`, etc.).

```bash
curl -s "$CANARYLLM_BASE_URL/v1/responses" \
  -H "Authorization: Bearer $CANARYLLM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "model": "openai/gpt-5", "input": "Write a haiku about queues." }'
```
