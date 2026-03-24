# Recruitment Workflow

## Trigger

User wants to recruit real participants for AI-moderated interviews.

## Prerequisites

- Study exists (`study_id` is known)
- Discussion guide is ready (`cookiy_guide_status` returns ready)
- User understands that recruitment costs real money and is NOT
  covered by experience bonus

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
  execution_duration: <optional duration override in minutes>
  max_price_per_interview: <optional budget cap>
  channel_name: <optional supplier/channel hint>
  auto_launch: <optional auto-launch preference>
  force_reconfigure: <optional explicit reconfigure intent>
  recruit_mode: <optional; when the server supports it, e.g. quantitative survey recruitment>
  survey_public_url: <optional; public respondent URL for quant survey flows when required>
```

This does NOT launch recruitment. It returns a preview containing:
- `targeting_preview.target_group` — who will be recruited
- `targeting_preview.screener_criteria` — qualification questions
- `targeting_preview.derived_languages_canonical` — detected languages
- `targeting_preview.unsupported_languages` — languages that cannot
  be served (if any)
- `targeting_preview.payment_quote` — cost estimate
- `study_summary.sample_size` — participant target from the guide
- `study_summary.interview_duration_minutes` — per-interview duration
- `study_summary.screen_share` / `study_summary.in_home_visit` — setup
  requirements that make recruitment harder
- `source_language` — the study's source language
- `confirmation_token` — required for step 4
- `status` / `workflow_state` — `confirmation_required`, which means
  preview only and not "already started"

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
4. **Sample size and interview duration** — confirm the operational plan
5. **Screen share / in-home visit requirements** — these increase
   recruitment difficulty and should be intentional
6. **Interview mode intent** — `video`, `audio`, or
   `audio_optional_video` from the guide is the study intent, but final
   provider camera/device requirements may still differ until
   recruitment execution confirms them
7. **Cost** — amount due from the payment quote
8. **Unsupported languages** — if any languages cannot be served

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
verification guidance such as `cookiy_recruit_status` and possibly
`cookiy_interview_list`. Treat this as launch requested / updated, not
as proof that interviews have already started.

**Guide changed (confirmation_reason: "guide_changed"):**
The discussion guide was modified between the preview and confirmation.
The server returns a fresh preview with a new `confirmation_token`.
Go back to step 3 and ask the user to confirm again.

**402 Payment required:**
Display `payment_summary` and offer `checkout_url`.
After payment, do NOT mechanically retry `cookiy_recruit_create` first.
Instead:
1. Call `cookiy_recruit_status`
2. Call `cookiy_interview_list` if you need to verify actual interview activity
3. Retry `cookiy_recruit_create` only if those checks still show that
   launch/configuration has not taken effect

**409 target increase requires reconfigure:**
If recruitment is already launched and the user wants to increase
`target_participants`, call `cookiy_recruit_create` again with the
larger target and `force_reconfigure: true`.

**409 target shrink not allowed:**
Once recruitment is launched, `target_participants` cannot be reduced
through this tool.

**400 Invalid confirmation token:**
The server returns error code `INVALID_CONFIRMATION_TOKEN`. The token
has expired (24h) or does not match the current user/study. Go back to
step 2 to generate a new preview.

### 5. Monitor recruitment progress

```
cookiy_recruit_status
  study_id: <study_id>
```

Poll every 30-60 seconds. Recruitment is a slow process — real
participants need time to respond.

The current public contract does not expose a separate `sync` parameter
on this tool. The server already reconciles pending recruit checkout
state before returning the billing-aware status view.

Use the returned progress counters directly:
- `target_participants` — intended recruitment target
- `current_participants` — completed recruited participants so far only;
  this does NOT include every talking, paused, or otherwise in-flight interview
- `click_count` — upstream click volume when available
- `payment_state` — billing-aware recruitment payment status when available
- `configured_scope` — whether supplier-side configuration has actually been created
- `current_participants_semantics` — explicitly indicates that
  `current_participants` counts completed respondents only

When real participants exist, the runtime may explicitly recommend:
- `cookiy_interview_list`
- then `cookiy_interview_playback_get` for completed interviews

## Rules

- Recruitment is ALWAYS a two-step process: preview then confirm.
  NEVER try to bypass the preview step.
- Truth-source priority for recruitment is:
  `cookiy_interview_list` > `cookiy_recruit_status` >
  latest `cookiy_recruit_create` response > `cookiy_study_get.state`.
- Recruitment does NOT use experience bonus. It requires paid credit or
  cash credit. Make this clear to the user before starting.
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
- Once recruitment is launched:
  - `target_participants` cannot be reduced through this tool
  - increasing the target requires `force_reconfigure: true`
- If the user asks for "watch this in the background for 20 minutes"
  or similar, do not promise that unless a real automation system is
  actually available. Offer a fresh status check now instead.

## Error handling

| Situation | Action |
|---|---|
| 402 on confirm | Display payment_summary, offer checkout_url |
| confirmation_reason: "guide_changed" | Show new preview, ask user to confirm again |
| 400 invalid token | Token expired or mismatched. Re-generate preview from step 2. |
| 409 target increase requires reconfigure | Retry with `force_reconfigure: true` if the user approves the increase. |
| 409 target shrink not allowed | Keep the current target, increase it, or create a new recruitment. |
| 409 generic conflict state | Recruitment may already be active. Check recruit_status first. |
