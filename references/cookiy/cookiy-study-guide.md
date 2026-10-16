<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy — Study Guide Operations

Commands for retrieving, uploading media to, and updating discussion/interview guides.

---

## CLI Commands

### study guide get

Get the full discussion/interview guide. Returns JSON — convert it to a human-readable format
before showing to the user.

```
cookiy study guide get --study-id <uuid>
```

### study guide update

Partially update (patch) the discussion/interview guide. The patch is merged into the
`discussion_guide` returned by `study guide get`.

```
cookiy study guide update --study-id <uuid> --base-revision <n> --json '<patch>'
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--base-revision` | yes | The `revision` field from the `study guide get` response |
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
  "meta": {
    "project_name": "Coffee purchase habits"
  }
}
```

Dot notation (auto-expanded):

```json
{
  "meta.project_name": "Coffee purchase habits"
}
```

### Arrays — Important

- Arrays are **fully replaced**, not merged. There is no automatic append.
- To modify an array: read the existing array, modify it in memory, then submit the **full updated
  array** in the patch.

### Example

Read `study guide get` first. Preserve all existing sections, questions and fields (including IDs,
media and any `visibility_rule`); assign a fresh UUIDv7 to each new entity.
After saving, GET the guide to verify the update.
This example starts with one section containing Q1.

**Original — `discussion_guide` excerpt from GET:**

```json
{
  "interview_flow": {
    "sections": [
      {
        "id": "018f0f13-7b5a-7c2e-8f6a-111111111111",
        "description": "Warm-up",
        "additional_video_mode": "none",
        "questions": [
          { "id": "018f0f13-7b5a-7c2e-8f6a-222222222222", "question": "How do you buy coffee?", "followup_intensity": "standard", "followup_examples": [], "allow_keyboard_input": false, "media": [] }
        ]
      }
    ]
  }
}
```

**Correct — append Q2 (send the full updated array as the patch):**

```json
{
  "interview_flow": {
    "sections": [
      {
        "id": "018f0f13-7b5a-7c2e-8f6a-111111111111",
        "description": "Warm-up",
        "additional_video_mode": "none",
        "questions": [
          { "id": "018f0f13-7b5a-7c2e-8f6a-222222222222", "question": "How do you buy coffee?", "followup_intensity": "standard", "followup_examples": [], "allow_keyboard_input": false, "media": [] },
          { "id": "018f0f13-7b5a-7c2e-8f6a-333333333333", "question": "What matters when choosing coffee?", "followup_intensity": "standard", "followup_examples": [], "allow_keyboard_input": false, "media": [] }
        ]
      }
    ]
  }
}
```

**Wrong — sending only Q2 replaces the array and removes Q1:**

```json
{
  "interview_flow": {
    "sections": [
      {
        "id": "018f0f13-7b5a-7c2e-8f6a-111111111111",
        "description": "Warm-up",
        "additional_video_mode": "none",
        "questions": [
          { "id": "018f0f13-7b5a-7c2e-8f6a-333333333333", "question": "What matters when choosing coffee?", "followup_intensity": "standard", "followup_examples": [], "allow_keyboard_input": false, "media": [] }
        ]
      }
    ]
  }
}
```

### Rules Summary

> Merge objects, replace arrays.

- Use partial objects for updates.
- Dot notation is supported.
- Arrays are **replace-only** — always send the full array when modifying.
