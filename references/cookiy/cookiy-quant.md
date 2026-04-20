# Cookiy — Quantitative Research (User Survey)

**Workflow:**
1. Read [`cookiy-quant-schema.md`](cookiy-quant-schema.md), then co-design the survey questions with the user
2. Confirm the supported survey languages with the user
3. `quant create` — creates and activates the survey immediately. Make sure the design is finalised before this step
4. Recruit participants → get report

---

## CLI Commands

### quant list

List surveys.

```
cookiy quant list
```

### quant create

Create a survey.

```
cookiy quant create --json '<obj>'
```

### quant get

Get survey detail.

```
cookiy quant get --survey-id <n>
```

### quant update

Update basic survey fields (e.g. title, format). Groups/questions cannot be modified after creation. The JSON is a subset of the create schema — provided keys overwrite, missing keys unchanged.

```
cookiy quant update --survey-id <n> --json '<obj>'
```

### quant status

Show overall survey status including recruitment progress.

```
cookiy quant status --survey-id <n>
```

### quant report

Fetch per-question response statistics. Returns JSON with a `question_summaries` field — present it visually or as text per the user's request.

```
cookiy quant report --survey-id <n>
```

### quant raw-response

Raw survey responses as CSV. Excludes incomplete by default. Output can be large — better redirect to a file.

```
cookiy quant raw-response --survey-id <n> [--include-incomplete]
```

---

For the JSON schema used in `create` and `update`, refer to [`cookiy-quant-schema.md`](cookiy-quant-schema.md).
