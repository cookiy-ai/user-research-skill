# Cookiy — Quantitative Research (User Survey)

End-to-end quantitative user survey via Cookiy AI.

**Workflow:**
1. Read [`cookiy-quant-schema.md`](cookiy-quant-schema.md), then co-design the survey questions with the user
2. Once confirmed, create with `activate: false` to create a draft survey
3. Preview survey (show it to the user) in readable format
4. (Optional) `quant update` to edit, then re-preview
5. Once satisfied, `quant update` with `activate: true` to activate — **survey content cannot be modified after activation**
6. Recruit participants → get report

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

Get survey detail. `--include-structure` defaults to yes (returns full survey questions); set to no for basic info only.

```
scripts/cookiy.sh quant get --survey-id <n> [--include-structure <bool>]
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
