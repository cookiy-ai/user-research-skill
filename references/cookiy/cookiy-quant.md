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
scripts/cookiy.sh quant list
```

### quant create

Create a survey.

```
scripts/cookiy.sh quant create --json '<obj>'
```

### quant get

Get survey detail.

```
scripts/cookiy.sh quant get --survey-id <n>
```

### quant update

Update basic survey fields (e.g. title, format). Groups/questions cannot be modified after creation. The JSON is a subset of the create schema — provided keys overwrite, missing keys unchanged.

```
scripts/cookiy.sh quant update --survey-id <n> --json '<obj>'
```

### quant status

Show overall survey status including recruitment progress.

```
scripts/cookiy.sh quant status --survey-id <n>
```

### quant report

Fetch per-question response statistics. Returns JSON with a `question_summaries` field — present it visually or as text per the user's request.

```
scripts/cookiy.sh quant report --survey-id <n>
```

---

For the JSON schema used in `create` and `update`, refer to [`cookiy-quant-schema.md`](cookiy-quant-schema.md).
