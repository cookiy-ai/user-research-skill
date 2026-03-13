# Report & Insights Workflow

## Trigger

User wants to generate a research report, check report status, get a
shareable report link, or review study-level information.

## Prerequisites

- Study exists (`study_id` is known)
- At least some interviews have been completed (real or simulated)

## Workflow

### 1. Check report status

```
cookiy_report_status
  study_id: <study_id>
```

The response contains two key fields:
- `report_status`: `NOT_READY` | `PREVIEW` | `READY`
- `request_state`: `never_requested` | `queued` | `processing` |
  `event_failed` | `completed`

Follow the decision tree below.

### 2. Decision tree

```
report_status = READY
  → Go to step 5 (get share link)

report_status = PREVIEW
  → Go to step 5 (get share link)
  → Tell the user: "A preview report is available now. The final
    version will replace it automatically once all interviews
    are analyzed."

report_status = NOT_READY
  │
  ├─ request_state = never_requested
  │    → Go to step 3 (generate report)
  │
  ├─ request_state = queued
  │    → Do NOT call report_generate
  │    → Go to step 4 (poll)
  │
  ├─ request_state = processing
  │    → Do NOT call report_generate
  │    → Go to step 4 (poll)
  │
  ├─ request_state = event_failed
  │    → Wait several minutes
  │    → May retry report_generate ONCE
  │    → Go to step 4 (poll)
  │
  └─ request_state = completed (but NOT_READY)
       → Not enough interview data for a report
       → Inform user: more interviews may be needed
```

### 3. Generate report (single trigger)

```
cookiy_report_generate
  study_id: <study_id>
```

CRITICAL RULES:
- This call consumes ONE report credit IMMEDIATELY.
- It is NOT idempotent. Each call costs another credit.
- Call it ONLY when `request_state` is `never_requested`.
- Call it at MOST once after `event_failed` (and only after waiting).
- NEVER call it when `request_state` is `queued` or `processing`.
- The response says "queued" — this does NOT mean the report is ready.
  Report generation runs in the background and may take several minutes.

On 402: display `payment_summary` and `checkout_url`.

### 4. Poll for completion

```
cookiy_report_status
  study_id: <study_id>
```

Poll every 10-30 seconds. Reports may take several minutes depending
on the number of interviews.

During polling:
- NEVER call `cookiy_report_generate` again.
- Continue polling until `report_status` changes to `PREVIEW` or `READY`.

### 5. Get share link

```
cookiy_report_share_link_get
  study_id: <study_id>
```

Returns:
- `share_url` — the publicly accessible report link
- `share_password` — password for the report (if set)

Present both to the user. If the report is a PREVIEW, note that the
final version will replace it automatically.

## Rules

- `cookiy_report_generate` is a SINGLE-TRIGGER action, not an
  idempotent refresh button. Treat it like "press once and wait."
- PREVIEW means "viewable now" — it is NOT "still generating."
  A preview report contains early results and can be shared.
- The server's `next_recommended_tools` and `status_message` fields
  encode the exact decision tree above. Always follow them.

## Auxiliary tools

**Check balance before generating:**
```
cookiy_balance_get
```
Returns current balance including trial credits. Report generation
can be covered by trial balance.

**Browse studies:**
```
cookiy_study_list
  query: <optional search term>
  status: <optional filter>
  limit: <1-100>
  cursor: <pagination cursor>
```
Results include `presentation_hint` requesting markdown table format.
Preserve exact `studyId` values for subsequent tool calls.

**Get study details:**
```
cookiy_study_get
  study_id: <study_id>
```
Returns study summary and metadata.

## Error handling

| Situation | Action |
|---|---|
| 402 on report_generate | Display payment_summary, offer checkout_url |
| 503 on report_generate | Temporary unavailability. Wait and retry once. |
| Report stays NOT_READY after generation | May need more interviews. Check interview count. |
| event_failed persists | Wait several minutes, then retry report_generate once |
