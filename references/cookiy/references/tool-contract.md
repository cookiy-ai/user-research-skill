# Cookiy Tool Usage Contract

This document defines the universal behavior rules for all Cookiy
tool calls. Every workflow references this contract.

## Response envelope

All Cookiy tools return a consistent envelope:

```
{
  ok: boolean,
  status_code: number,
  data: object | null,
  error: { code, message, details } | null,
  request_id: string | null
}
```

The response is delivered through two channels simultaneously:
- `structuredContent` — the full typed envelope (preferred)
- `content[0].text` — a text rendering for clients that only read plain text

ALWAYS prefer `structuredContent`. Only fall back to parsing JSON from
`content[0].text` when structured output is unavailable.

## Server-provided guidance fields

These fields appear inside `data` on successful responses. They are
stable server-level signals, not just hints.

### `next_recommended_tools`

An array of **server operation identifiers** the service recommends next.
ALWAYS prefer this list over guessing. Identifiers are defined by the
hosted API; translate each to the matching **Cookiy CLI** invocation via
[`cli/commands.md`](../cli/commands.md) (or use the generic escape form
documented there). Do not invent alternate command paths when this field
is present.

For recruitment truth, prefer evidence in this order:
1. `cookiy interview list`
2. `cookiy recruit status`
3. The latest `cookiy recruit start` response
4. `cookiy study get.state`

`cookiy recruit status` is the billing-aware recruitment authority in
the current public contract. There is no separate `sync` flag; the
server already reconciles pending recruit checkout state before
reporting status.

### `status_message`

A server-composed directive describing the current state and what to do
next. Treat it as an executable instruction, not informational prose.
Examples:
- "Poll cookiy report status periodically until report_status=PREVIEW or READY"
- "Review the target group, language, and pricing with the user"

### `presentation_hint`

Formatting guidance for the response. Respect it when present:
- `presentation_hint` may be a structured object or a plain string
  instruction. If it is a string, follow it verbatim.
- `preferred_format: "markdown_table"` — render as a table
- `preferred_format: "markdown_link"` — render as a clickable link
- `columns` — defines table column order and labels
- `primary_markdown_field` — the field to display as the main link
- `primary_id_field` — the identifier column to preserve exactly
- `copyable_fields` — fields the user may want to copy
- `pagination_fields` — pagination keys to keep visible in list output
- `expires_at_field` — expiry metadata for time-limited links

### `important_field_review`

Returned by `cookiy study guide get`. Contains critical settings that affect
recruitment difficulty and cost. ALWAYS present these to the user for
confirmation before proceeding to recruitment or interviews:
- `mode_of_interview` — video, audio, or audio_optional_video
- `screen_share` / `in_home_visit` — questions requiring special setup
- `sample_size` — number of participants
- `interview_duration` — interview length in minutes (max 15 in Cookiy)

Each field includes an `edit_path` that can be used directly as a
dot-notation key in `cookiy study guide patch`.

## Identifier handling

| Identifier | Source | Rules |
|---|---|---|
| `study_id` | `cookiy study create`, `cookiy study list` | Never truncate. Use exactly as returned. |
| `job_id` | `cookiy interview simulate start` | Pass to `cookiy interview simulate status` exactly. |
| `interview_id` | `cookiy interview list` | Pass to `cookiy interview playback` exactly. |
| `base_revision` | `cookiy study guide get` | Must come from the most recent guide_get call. |
| `idempotency_key` | Client-generated | Reuse on retry. Generate a new one for each new operation. |
| `confirmation_token` | `cookiy recruit start` (preview) | Opaque, single-use. Bound to user + study + guide revision. |

## Unified activity summary (`cookiy study progress`)

Use **`cookiy study progress`** as the default entry point when the user asks
for study progress in natural language — for example recruitment status,
report readiness, or “what should happen next” — without manually comparing
every atomic status tool first.

- Pass **`study_id`** (required for study-scoped questions). **`job_id`** is
  for simulated-interview–specific drill-down when needed.
- The response includes **`narration_brief`** (facts and angles for you to
  paraphrase in the user’s chat language) and orchestration hints such as
  **`agent.next_recommended_tools`**. Compose a concise user-facing answer;
  do not dump raw JSON or snake_case stage names unless the user asked for
  technical detail.
- Set **`include_debug=true`** only when you need the full payload in
  `contentText` for debugging.
- This tool does **not** replace atomic tools for deep debugging; drill into
  `cookiy study guide status`, `cookiy recruit status`, `cookiy report status`, etc.
  only when subsystem detail is required.

## Cash credit checkout (`cookiy billing checkout`)

Use **`cookiy billing checkout`** when the user wants to add **cash
credit** before paid workflows. It creates a Stripe Checkout session for an
arbitrary amount in **USD cents** (integer, at or above the Stripe minimum,
typically 100 cents = $1.00). There are no preset tiers; the server may cap
very large amounts via configuration.

- After the user completes payment in Stripe, confirm updated balance with
  **`cookiy billing balance`** (or continue with the paid workflow).
- This tool starts checkout only; it does not credit balance until payment
  succeeds.

## Payment handling (HTTP 402)

When any tool returns status_code 402:

1. Prefer `structuredContent.data.payment_summary` — a human-readable
   cost explanation already composed by the server. If it is absent,
   fall back to `error.details.payment_summary`.
2. Prefer `structuredContent.data.checkout_url` as the payment link.
   `checkout_url_short` may also be present for copy-friendly display.
3. Read `structuredContent.data.payment_breakdown` when present for
   structured cost details (unit price, required units, covered units,
   deficit).
4. If `retry_same_tool`, `retry_tool_name`, or `retry_input_hint` are
   present in `structuredContent.data`, follow them for the post-payment
   retry path.
5. For recruitment specifically, after payment prefer this sequence:
   `cookiy recruit status` -> `cookiy interview list` ->
   retry `cookiy recruit start` only if those checks still show that
   launch/configuration has not taken effect.
6. To add cash credit before retrying a paid action, use
   `cookiy billing checkout`, then confirm with `cookiy billing balance`.
7. NEVER recalculate or restate prices from raw quote fields.

### Cash credit rules

- New OAuth users may receive signup cash credit in the same wallet shown
  by `cookiy billing balance`.
- Cash credit is deducted at real product prices.
- Cash credit covers eligible actions such as:
  - Discussion guide generation (`cookiy study create`)
  - AI-to-AI interview generation (`cookiy interview simulate start`)
  - Report access when retrieving the share link
    (`cookiy report share-link`)
- Recruitment of real participants (`cookiy recruit start`) may also use
  available cash credit from the same wallet.
- `cookiy billing balance` does not expose a separate `experience_bonus`
  field anymore. Historical usage rows may still fold legacy bonus usage
  into cash-credit display values.
- Eligible Cookiy actions use product-specific paid credits before cash
  credit, so paid counters decrease first when both are available.
- If a covered operation fails before task dispatch, the credit is
  refunded automatically.
- Use `cookiy billing balance` to check current cash credit and per-product
  paid counters.

### Balance display rules

When presenting `cookiy billing balance` output:
- Prefer `consumer_balance_overview`.
- Prefer `recent_purchases[].display_line` and
  `recent_usage[].display_line` for user-facing billing statements.
- Quote the exact money strings returned by the server.
- Do NOT recompute amounts from cents, drop leading dollar digits, or
  merge purchase rows with usage rows.
- Treat usage rows as historical consumption, not as remaining
  purchasable recruit credit.

## Error handling by status code

| Code | Meaning | Action |
|---|---|---|
| 200 | Success | Read `data` and follow `next_recommended_tools`. |
| 202 | Async accepted | Operation started. Poll the corresponding status tool. |
| 400 | Validation error | Read `error.message`. Fix input and retry. |
| 401 | Auth failure | Re-authenticate. Do NOT remove and reinstall the server. |
| 402 | Payment required | Display `payment_summary` and `checkout_url`. |
| 404 | Not found | Verify the identifier. It may have been deleted or never existed. |
| 409 | Conflict | Revision mismatch or state conflict. Re-fetch current state and retry. |
| 422 | Invalid payload | Read `error.details` for field-level errors. |
| 429 | Rate limited | Back off and retry later. |
| 500 | Internal failure | Treat as transient and retry with backoff. |
| 502 | Upstream dependency failure | Retry later; dependency may be unavailable. |
| 503 | Unavailable | Temporary. Wait and retry once. |

## URL rules

- All URLs in responses have been rewritten to public-facing addresses.
- Internal API endpoint URLs (`/v1/...`) are stripped from responses.
- `recruit_url` fields are removed to prevent panel provider leakage.
- NEVER construct URLs manually. ONLY use URLs from tool responses.

## Dot-notation patch support

`cookiy study guide patch` and `cookiy study guide impact` accept flat dot-notation
keys in the `patch` parameter. The server expands them automatically:

```json
{ "research_overview.sample_size": 8 }
```

is equivalent to:

```json
{ "research_overview": { "sample_size": 8 } }
```

Use dot-notation for simpler patches. Nested objects also work.

## Polling guidelines

For async operations, poll at reasonable intervals:
- `cookiy study guide status`: every 3-5 seconds after study creation
- `cookiy interview simulate status`: every 5-10 seconds
- `cookiy report status`: every 10-30 seconds (reports take longer)
- `cookiy recruit status`: every 30-60 seconds (recruitment is slow)


## Report PREVIEW vs READY (Cookiy behavior)

- **PREVIEW** — Viewable early snapshot; may not include every interview
  completed afterward until the pipeline updates. Users judge freshness from
  the opened page.
- **READY** — Final (non-preview) report; usually after the study's **configured
  completed-interview / analysis completion target** is met and generation
  finishes. Do not tell users that PREVIEW "becomes final as soon as any new
  interview exists" without reference to that bar.
- Share links must come **only** from `cookiy report share-link` (`share_url`),
  never self-constructed URLs.

## Quantitative survey tools (optional)

When the API operator has configured quantitative survey integration,
these tools are available **in parallel** with qualitative workflows
(study, guide, interview, recruit, report). They do not replace
discussion guides or qualitative reports.

| Tool | Role |
|---|---|
| `cookiy quant list` | Discover survey IDs and titles |
| `cookiy quant create` | Create a structured questionnaire |
| `cookiy quant detail` | Public respondent URLs and optional structure; `include_structure=false` for link-only; `structure_presentation` = `markdown`, `json`, or `both` |
| `cookiy quant patch` | Non-destructive questionnaire edits: wording, requiredness, relevance, and quota-shell fields only |
| `cookiy quant report` | Default summary/report entrypoint after responses arrive; optional raw JSON/CSV preview |
| `cookiy quant results` | Raw JSON/CSV response payloads (`results_preview`, optional `results_json` when format is JSON) |
| `cookiy quant stats` | Legacy lightweight stats view kept for compatibility |

Recommended workflow:

1. Create a new questionnaire with `cookiy quant create`, or discover an existing one with `cookiy quant list`.
2. Call `cookiy quant detail` to get `survey_public_url`, activation state, and exact group/question ids.
3. If the questionnaire needs edits, call `cookiy quant patch`.
4. After responses arrive, call `cookiy quant report` for the default analysis path.
5. Only call `cookiy quant results` when raw row-level payloads are explicitly needed.

If the server returns 503 with a setup hint, quantitative tools are not
configured for that deployment.

## Agent boundary rules

- Do not describe recruitment as started, paused, or failed from
  preview-only output.
- Do not promise background monitoring unless a real automation layer
  actually exists outside the current request call you are making right now.
- When questionnaire recruitment is involved, say Cookiy is recruiting.
  Do not name downstream recruitment suppliers or the underlying
  questionnaire engine.
