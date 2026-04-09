# Cookiy — Quantitative Research (User Survey)

**Workflow:**
1. Read [`cookiy-quant-schema.md`](cookiy-quant-schema.md), then co-design the survey questions with the user
2. Confirm the supported survey languages with the user
3. `quant create` — creates and activates the survey immediately. **Groups/questions cannot be modified after creation.** Make sure the design is finalised before this step
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

Patch a survey. The JSON is a partial object merged into the original — provided keys overwrite, missing keys unchanged, arrays are replace-only (always send full array).

```
scripts/cookiy.sh quant update --survey-id <n> --json '<obj>'
```

### quant report

Get survey report.

```
scripts/cookiy.sh quant report --survey-id <n>
```

---

For the JSON schema used in `create` and `update`, refer to [`cookiy-quant-schema.md`](cookiy-quant-schema.md).
