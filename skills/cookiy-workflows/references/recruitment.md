# Recruitment Workflow

## Trigger

User wants to recruit real participants for AI-moderated interviews.

## Prerequisites

- Study exists (`study_id` is known)
- Discussion guide is ready (`cookiy_guide_status` returns ready)
- User understands that recruitment costs real money and is NOT
  covered by trial balance

## Workflow

### 1. Confirm guide readiness

```
cookiy_guide_status
  study_id: <study_id>
```

Only proceed if the guide is ready. Recruitment depends on a finalized
discussion guide.

### 2. Request recruitment preview (first call)

Call `cookiy_recruit_create` WITHOUT a `confirmation_token`:

```
cookiy_recruit_create
  study_id: <study_id>
  plain_text: <optional additional targeting description>
  target_participants: <optional override>
```

This does NOT launch recruitment. It returns a preview containing:
- `targeting_preview.target_group` — who will be recruited
- `targeting_preview.screener_criteria` — qualification questions
- `targeting_preview.derived_languages_canonical` — detected languages
- `targeting_preview.unsupported_languages` — languages that cannot
  be served (if any)
- `targeting_preview.payment_quote` — cost estimate
- `source_language` — the study's source language
- `confirmation_token` — required for step 4

Rules for `plain_text`:
- You do NOT need to pass `plain_text` in most cases. The server
  automatically extracts targeting information from the discussion
  guide's screener criteria and target group.
- Only pass `plain_text` when the user wants additional constraints
  beyond what the guide specifies (e.g., geographic region, age range).
- If you do pass `plain_text`, it will be COMBINED with the
  auto-extracted screener data, not replace it.
- Do NOT manually extract screener criteria from the guide and
  restate them in `plain_text` — the server already does this.

### 3. Present preview to user

Show the user:
1. **Target group** — who will be recruited
2. **Target languages** — which languages are supported
3. **Screener criteria** — qualification/disqualification rules
4. **Cost** — amount due from the payment quote
5. **Unsupported languages** — if any languages cannot be served

The user must explicitly confirm before proceeding.

If the user wants to adjust targeting, either:
- Go back to Guide Editing workflow to change the guide, or
- Re-call step 2 with different `plain_text` or `target_participants`

### 4. Confirm and launch recruitment (second call)

Call `cookiy_recruit_create` WITH the `confirmation_token`:

```
cookiy_recruit_create
  study_id: <study_id>
  confirmation_token: <from step 2>
```

Possible outcomes:

**Success:** Recruitment is launched. The response includes
`next_recommended_tools: ["cookiy_recruit_status"]`.

**Guide changed (confirmation_reason: "guide_changed"):**
The discussion guide was modified between the preview and confirmation.
The server returns a fresh preview with a new `confirmation_token`.
Go back to step 3 and ask the user to confirm again.

**402 Payment required:**
Display `payment_summary` and offer `checkout_url`.

**400 Invalid confirmation token:**
The token has expired (24h) or does not match the current user/study.
Go back to step 2 to generate a new preview.

### 5. Monitor recruitment progress

```
cookiy_recruit_status
  study_id: <study_id>
  sync: true  (optional — forces a fresh status fetch)
```

Poll every 30-60 seconds. Recruitment is a slow process — real
participants need time to respond.

## Rules

- Recruitment is ALWAYS a two-step process: preview then confirm.
  NEVER try to bypass the preview step.
- Recruitment does NOT use trial balance. It is always a separate
  paid charge. Make this clear to the user before starting.
- `confirmation_token` is:
  - Opaque — do not parse or modify it
  - Bound to the current user, study, and guide revision
  - Valid for 24 hours
  - NOT reusable across different studies
- If the guide changes after the preview, the server automatically
  invalidates the token and returns a new preview.
- The `recruit_url` field is intentionally stripped from all
  responses. There is no supported path to manually manage
  recruitment outside of Cookiy MCP tools.

## Error handling

| Situation | Action |
|---|---|
| 402 on confirm | Display payment_summary, offer checkout_url |
| confirmation_reason: "guide_changed" | Show new preview, ask user to confirm again |
| 400 invalid token | Token expired or mismatched. Re-generate preview from step 2. |
| 409 conflict state | Recruitment may already be active. Check recruit_status first. |
