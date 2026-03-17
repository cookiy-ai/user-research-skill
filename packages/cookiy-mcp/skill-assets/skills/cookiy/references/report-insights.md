# Report & Insights Workflow

## Trigger

User wants to check report status, get a shareable report link, or
review study-level reporting information.

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
  → Go to step 3 (get share link)

report_status = PREVIEW
  → Go to step 3 (get share link)
  → Tell the user: "A preview report is available now. The final
    version will replace it automatically once all interviews
    are analyzed."

report_status = NOT_READY
  → Do NOT try to manually trigger report generation from MCP
  → Continue polling `cookiy_report_status`
  → Use `request_state` only as lifecycle context:
     - `never_requested` / `queued` / `processing`:
       report generation has not produced a viewable report yet
     - `event_failed`:
       background processing may have hit a transient issue; wait and poll again
     - `completed` with `NOT_READY`:
       there may still be insufficient interview coverage for a report
```

### 3. Get share link

```
cookiy_report_share_link_get
  study_id: <study_id>
```

Returns:
- `share_url` — the publicly accessible report link
- `share_password` — password for the report (if set)

Present both to the user. If the report is a PREVIEW, note that the
final version will replace it automatically.

If this call returns 402:
- Display `payment_summary`
- Offer `checkout_url`
- Follow any `retry_input_hint` / `retry_tool_name` guidance in the
  response after payment

## Rules

- Reports are generated automatically after interviews complete.
- MCP does NOT expose a supported manual report-generation step.
- If `report_status` is `NOT_READY`, keep polling `cookiy_report_status`
  until it changes to `PREVIEW` or `READY`.
- Payment, if required, happens at `cookiy_report_share_link_get`.
- PREVIEW means "viewable now" — it is NOT "still generating."
  A preview report contains early results and can be shared.
- The server's `next_recommended_tools` and `status_message` fields
  are authoritative. Always follow them.

## Auxiliary tools

**Check balance before retrieving access:**
```
cookiy_balance_get
```
Returns current balance including experience bonus, cash credit, and
per-product paid counters. Report generation does not charge here from
MCP because manual generation is not exposed. Experience bonus may still
apply when retrieving report access via `cookiy_report_share_link_get`.

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
Returns study summary and metadata, including
`completed_interview_count` for quick readiness checks.

## Error handling

| Situation | Action |
|---|---|
| 402 on report_share_link_get | Display payment_summary, offer checkout_url |
| Report stays NOT_READY | Continue polling and check interview count via `cookiy_study_get` |
| `request_state=event_failed` persists for several minutes | Explain that background processing may be stalled and try `cookiy_report_status` again later |
