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
- After `cookiy_report_status` when `report_status` is `PREVIEW` or `READY`: `["cookiy_report_share_link_get"]`

For recruitment truth, prefer evidence in this order:
1. `cookiy_interview_list`
2. `cookiy_recruit_status` (use `sync: true` when you need a fresh check)
3. The latest `cookiy_recruit_create` response
4. `cookiy_study_get.state`

### `status_message`

A server-composed directive describing the current state and what to do
next. Treat it as an executable instruction, not informational prose.
Examples:
- "Poll cookiy_report_status periodically until report_status=PREVIEW or READY"
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

Returned by `cookiy_guide_get`. Contains critical settings that affect
recruitment difficulty and cost. ALWAYS present these to the user for
confirmation before proceeding to recruitment or interviews:
- `mode_of_interview` — video, audio, or audio_optional_video
- `screen_share` / `in_home_visit` — questions requiring special setup
- `sample_size` — number of participants
- `interview_duration` — interview length in minutes (max 15 in MCP)

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
   `cookiy_recruit_status(sync=true)` -> `cookiy_interview_list` ->
   retry `cookiy_recruit_create` only if those checks still show that
   launch/configuration has not taken effect.
6. NEVER recalculate or restate prices from raw quote fields.

### Experience bonus rules

- New users may receive an `experience_bonus` allocation visible in
  `cookiy_balance_get`.
- Experience bonus is deducted at real product prices.
- Experience bonus covers eligible actions such as:
  - Discussion guide generation (`cookiy_study_create`)
  - AI-to-AI interview generation (`cookiy_simulated_interview_generate`)
  - Report access when retrieving the share link
    (`cookiy_report_share_link_get`)
- Experience bonus does NOT cover:
  - Recruitment of real participants (`cookiy_recruit_create`)
  - Recruitment requires paid credit or cash credit.
- `cookiy_balance_get` may also show `experience_bonus`. Eligible MCP
  actions use that bonus before purchased credits, so paid product
  counters may stay unchanged even when an action succeeded.
- If a covered operation fails before task dispatch, the credit is
  refunded automatically.
- Use `cookiy_balance_get` to check current experience bonus, cash
  credit, and per-product paid counters.

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

## Agent boundary rules

- Do not describe recruitment as started, paused, or failed from
  preview-only output.
- Do not promise background monitoring unless a real automation layer
  actually exists outside the MCP call you are making right now.
