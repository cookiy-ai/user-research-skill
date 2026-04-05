# Cookiy — Study Guide Operations

Commands for retrieving, uploading media to, and updating discussion/interview guides.

---

## CLI Commands

### study guide get

Get the full discussion/interview guide. Returns JSON — convert it to a human-readable format
before showing to the user.

```
scripts/cookiy.sh study guide get --study-id <uuid>
```

### study guide wait

Wait until the discussion/interview guide has been generated for the study.

```
scripts/cookiy.sh study guide wait --study-id <uuid>
```

### study guide update

Partially update (patch) the discussion/interview guide. The patch is merged into the JSON returned
by `study guide get`.

```
scripts/cookiy.sh study guide update --study-id <uuid> --base-revision <s> --idempotency-key <s> [--change-message <s>] --json '<patch>'
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--base-revision` | yes | The `revision` field from the `study guide get` response |
| `--idempotency-key` | yes | Client-generated unique key (generate one yourself) |
| `--change-message` | no | Human-readable description of the change |
| `--json` | yes | Incremental patch JSON to merge into the original. See patch guide below. |

---

## JSON Patch Guide

### Core Idea

A patch is a **partial JSON object** merged into the original:
- Provided keys are **updated / overwritten**
- Missing keys are **unchanged**

### Updating Nested Fields

Standard:
```json
{
  "research_overview": {
    "interview_topic": "Updated Topic"
  }
}
```

Dot notation (auto-expanded):
```json
{
  "research_overview.interview_topic": "Updated Topic"
}
```

### Arrays — Important

- Arrays are **fully replaced**, not merged. There is no automatic append.
- To modify an array: read the existing array, modify it in memory, then submit the **full updated
  array** in the patch.

### Example

**Original:**
```json
{
  "interview_flow": {
    "sections": [
      {
        "description": "Warm-up",
        "question_list": [
          { "question": "Q1", "type": "free_response", "followups": [], "media": [] }
        ]
      }
    ]
  }
}
```

**Correct — append Q2 (send full array):**
```json
{
  "interview_flow": {
    "sections": [
      {
        "description": "Warm-up",
        "question_list": [
          { "question": "Q1", "type": "free_response", "followups": [], "media": [] },
          { "question": "Q2 New", "type": "free_response", "followups": [], "media": [] }
        ]
      }
    ]
  }
}
```

**Wrong — overwrites the array with only Q2:**
```json
{
  "question_list": [
    { "question": "Q2 New", "type": "free_response", "followups": [], "media": [] }
  ]
}
```

### Rules Summary

> Merge objects, replace arrays.

- Use partial objects for updates
- Dot notation is supported
- Arrays are **replace-only** — always send the full array when modifying
