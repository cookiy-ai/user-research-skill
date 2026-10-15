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
