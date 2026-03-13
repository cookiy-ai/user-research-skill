# Discussion Guide Editing Workflow

## Trigger

User wants to view, modify, or refine the discussion guide (interview
script) for an existing study.

## Prerequisites

- Study exists (`study_id` is known)
- Discussion guide has been generated (guide_status is ready)

## Workflow

### 1. Get current guide

```
cookiy_guide_get
  study_id: <study_id>
```

From the response, save:
- `revision` — required for the optimistic lock in step 3
- `important_field_review` — critical settings to highlight
- The full guide structure for reference

Present the guide contents and `important_field_review` fields to
the user.

### 2. Preview the edit impact (recommended)

Before applying changes, preview their impact:

```
cookiy_guide_impact
  study_id: <study_id>
  patch: { <dot-notation changes> }
```

Example patches using dot-notation:
```json
{ "research_overview.sample_size": 8 }
{ "research_overview.mode_of_interview": "audio" }
{ "research_overview.interview_duration": 10 }
```

The server auto-expands dot-notation to nested objects.
This step does NOT save any changes.

Present the impact preview to the user for confirmation.

### 3. Apply the edit

```
cookiy_guide_patch
  study_id: <study_id>
  base_revision: <revision from step 1>
  idempotency_key: <generate a unique key for this edit>
  patch: { <same patch as step 2> }
  change_message: <optional human-readable description>
```

Rules:
- `base_revision` MUST come from the most recent `cookiy_guide_get`.
- `idempotency_key` MUST be unique per new edit operation.
  Reuse the same key only when retrying a failed attempt of the
  same edit.
- `interview_duration` must be 15 minutes or less in MCP context.

### 4. Handle conflicts

**409 Revision conflict:**
The guide was modified since you last fetched it. Go back to step 1:
re-fetch the guide with `cookiy_guide_get`, get the new `revision`,
and retry the patch with the same `idempotency_key`.

**Recruit reconfigure required:**
If the guide change affects active recruitment (e.g., changing sample
size, target group, or screening criteria), the server may require
confirmation. Re-submit the patch with:
```
recruit_reconfigure_confirmed: true
```

Only set this after explaining the impact to the user and getting
their approval.

### 5. Verify the update (optional)

Call `cookiy_guide_get` again to confirm the patch was applied
correctly.

## Rules

- ALWAYS follow the sequence: `guide_get` -> `guide_impact` -> `guide_patch`.
  Do not skip `guide_get` — you need the current `revision`.
- ALWAYS use dot-notation for simple field changes.
- NEVER reuse a `base_revision` from a previous session or a
  different guide_get call.
- Generate a new `idempotency_key` for each distinct edit operation.
  Reuse the key only on retry of the exact same operation.

## Common edit paths

| What to change | Dot-notation path | Allowed values |
|---|---|---|
| Interview mode | `research_overview.mode_of_interview` | `video`, `audio`, `audio_optional_video` |
| Sample size | `research_overview.sample_size` | Positive integer |
| Interview duration | `research_overview.interview_duration` | 1-15 (minutes) |
| Screen share on a question | `interview_flow.sections[N].question_list[M].required_screen_share` | `true` / `false` |
| In-home visit on a question | `interview_flow.sections[N].question_list[M].required_in_home_visit` | `true` / `false` |

## Error handling

| Situation | Action |
|---|---|
| 409 revision conflict | Re-fetch guide, get new revision, retry with same idempotency_key |
| 422 invalid patch | Check error.details for field-level errors, fix and retry |
| Recruit reconfigure needed | Explain impact to user, retry with recruit_reconfigure_confirmed: true |
