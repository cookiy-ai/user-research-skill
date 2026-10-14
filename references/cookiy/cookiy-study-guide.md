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

Patch the `discussion_guide` document returned by `study guide get`, using its latest `revision`.

```
cookiy study guide update --study-id <uuid> --base-revision <n> --json '<patch>'
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--base-revision` | yes | The latest numeric `revision` from `study guide get` |
| `--json` | yes | Incremental patch JSON to merge into the original. See patch guide below. |

Updates use `base_revision` for optimistic concurrency. No idempotency key is needed. After a
timeout or revision conflict, get the latest guide and inspect it before deciding whether to update
again.

---

## JSON Patch Guide

Patch only fields inside `discussion_guide`; do not submit the full GET response. Objects are merged,
provided values replace existing values, and omitted fields stay unchanged.

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
- Preserve the IDs and required fields of existing sections, questions, and media. Use the actual
  document returned by GET as the schema reference.
- Do not use dotted numeric paths to edit individual array entries.
