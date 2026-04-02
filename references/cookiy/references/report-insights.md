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
cookiy report status
  study_id: <study_id>
```

The response contains two key fields:
- `report_status`: `NOT_READY` | `PREVIEW` | `READY`
- `request_state`: `never_requested` | `queued` | `processing` |
  `event_failed` | `completed`

**PREVIEW vs READY (product expectation):**

- **PREVIEW** — Early snapshot you can open and share. It may **not** yet reflect every interview completed afterward (e.g. new simulated runs); whether content is up to date is judged from **what the user sees on the page**, not from `report_id` / timestamps alone.
- **READY** — Final report (non-preview). Typically appears only after the study’s **configured completion bar** is met (usually the **planned analyzed completed interviews** / study target from setup—see recruit or study summary) **and** the report pipeline has finished. Until then, the product may keep serving PREVIEW.

Follow the decision tree below.

### 2. Decision tree

```
report_status = READY
  → Go to step 3 (get share link)

report_status = PREVIEW
  → Go to step 3 (get share link)
  → Tell the user in plain language: a **preview** is available now (early read).
    The **final** report replaces it when the study meets its **planned completion
    target** (analyzed interviews) and the platform finishes generation—not simply
    “every ad-hoc interview,” and not by echoing internal field names. If they
    added interviews later, the preview might lag; they should confirm coverage
    from the opened report.

report_status = NOT_READY
  → Do NOT try to manually trigger report generation from the API
  → Continue polling `cookiy report status`
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
cookiy report share-link
  study_id: <study_id>
```

Returns:
- `share_url` — the publicly accessible report link
- `share_password` — password for the report (if set)

Present both to the user. Use **only** `share_url` from the tool—do not
hand-build URLs. If the report is a PREVIEW, note the early-read behavior
and that final **READY** follows the study completion bar + pipeline (as above).

If this call returns 402:
- Display `payment_summary`
- Offer `checkout_url`
- Follow any `retry_input_hint` / `retry_tool_name` guidance in the
  response after payment

## Rules

- Reports are generated automatically after interviews complete.
- Cookiy does not expose a supported manual report-generation step.
- If `report_status` is `NOT_READY`, keep polling `cookiy report status`
  until it changes to `PREVIEW` or `READY`.
- Payment, if required, happens at `cookiy report share-link`.
- PREVIEW means "viewable now" — it is NOT "still generating."
  A preview report contains early results and can be shared, but may omit or lag
  the latest interviews until the pipeline catches up or **READY** is produced.
- **READY** implies the final report path, usually after the configured study
  interview target / completion criteria are satisfied (not a vague “all done”).
- The server's `next_recommended_tools` and `status_message` fields
  are authoritative. Always follow them.

## Auxiliary tools

**Check balance before retrieving access:**
```
cookiy billing balance
```
Returns current balance including experience bonus, cash credit, and
per-product paid counters. Report generation does not charge here from
Cookiy because manual generation is not exposed. Experience bonus may still
apply when retrieving report access via `cookiy report share-link`.

**Browse studies:**
```
cookiy study list
  query: <optional search term>
  status: <optional filter>
  limit: <1-100>
  cursor: <pagination cursor>
```
Results include `presentation_hint` requesting markdown table format.
Preserve exact `studyId` values for subsequent tool calls.

**Get study details:**
```
cookiy study get
  study_id: <study_id>
```
Returns study summary and metadata, including
`completed_interview_count` for quick readiness checks.

## Error handling

| Situation | Action |
|---|---|
| 402 on report_share_link_get | Display payment_summary, offer checkout_url |
| Report stays NOT_READY | Continue polling and check interview count via `cookiy study get` |
| `request_state=event_failed` persists for several minutes | Explain that background processing may be stalled and try `cookiy report status` again later |
