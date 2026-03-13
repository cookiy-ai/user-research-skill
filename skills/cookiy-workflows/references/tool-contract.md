# Cookiy MCP Tool Usage Contract

This document defines the universal behavior rules for all Cookiy MCP
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

An array of tool names the server recommends calling next. ALWAYS prefer
this over guessing the next step. Examples:
- After `cookiy_study_list` success: `["cookiy_study_get"]`
- After `cookiy_recruit_create` preview: `["cookiy_recruit_create"]`
- After `cookiy_report_generate`: `["cookiy_report_status"]`

### `status_message`

A server-composed directive describing the current state and what to do
next. Treat it as an executable instruction, not informational prose.
Examples:
- "Do NOT call cookiy_report_generate again — poll this endpoint periodically"
- "Review the target group, language, and pricing with the user"

### `presentation_hint`

Formatting guidance for the response. Respect it when present:
- `preferred_format: "markdown_table"` — render as a table
- `preferred_format: "markdown_link"` — render as a clickable link
- `columns` — defines table column order and labels
- `primary_markdown_field` — the field to display as the main link
- `copyable_fields` — fields the user may want to copy

### `important_field_review`

Returned by `cookiy_guide_get`. Contains critical settings that affect
recruitment difficulty and cost. ALWAYS present these to the user for
confirmation before proceeding to recruitment or interviews:
- `mode_of_interview` — video, audio, or audio_optional_video
- `screen_share` / `in_home_visit` — questions requiring special setup
- `sample_size` — number of participants

Each field includes an `edit_path` that can be used directly as a
dot-notation key in `cookiy_guide_patch`.

## Identifier handling

| Identifier | Source | Rules |
|---|---|---|
| `study_id` | `cookiy_study_create`, `cookiy_study_list` | Never truncate. Use exactly as returned. |
| `job_id` | `cookiy_simulated_interview_generate` | Pass to `cookiy_simulated_interview_status` exactly. |
| `interview_id` | `cookiy_interview_list` | Pass to `cookiy_interview_playback_get` exactly. |
| `base_revision` | `cookiy_guide_get` | Must come from the most recent guide_get call. |
| `idempotency_key` | Client-generated | Reuse on retry. Generate a new one for each new operation. |
| `confirmation_token` | `cookiy_recruit_create` (preview) | Opaque, single-use. Bound to user + study + guide revision. |

## Payment handling (HTTP 402)

When any tool returns status_code 402:

1. Read `error.details.payment_summary` — a human-readable cost explanation
   already composed by the server. Display it to the user.
2. Read `error.details.checkout_url` — the payment link. Offer it.
3. Read `error.details.payment_breakdown` — structured cost data
   (unit price, required units, covered units, deficit).
4. NEVER recalculate or restate prices from raw quote fields.

### Trial balance rules

- New users receive a trial balance (typically $3.00).
- Trial balance is deducted at real product prices.
- Trial balance covers:
  - Discussion guide generation (`cookiy_study_create`)
  - AI-to-AI interview generation (`cookiy_simulated_interview_generate`)
  - Report generation (`cookiy_report_generate`)
- Trial balance does NOT cover:
  - Recruitment of real participants (`cookiy_recruit_create`)
  - Recruitment is always a separate paid charge.
- If a covered operation fails before task dispatch, the credit is
  refunded automatically.
- Use `cookiy_balance_get` to check current trial balance.

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
| 503 | Unavailable | Temporary. Wait and retry once. |

## URL rules

- All URLs in responses have been rewritten to public-facing addresses.
- Internal API endpoint URLs (`/v1/...`) are stripped from responses.
- `recruit_url` fields are removed to prevent panel provider leakage.
- NEVER construct URLs manually. ONLY use URLs from tool responses.

## Dot-notation patch support

`cookiy_guide_patch` and `cookiy_guide_impact` accept flat dot-notation
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
- `cookiy_guide_status`: every 3-5 seconds after study creation
- `cookiy_simulated_interview_status`: every 5-10 seconds
- `cookiy_report_status`: every 10-30 seconds (reports take longer)
- `cookiy_recruit_status`: every 30-60 seconds (recruitment is slow)
