<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy — Quantitative Research (User Survey)

**Workflow:**
1. Read [`cookiy-quant-schema.md`](cookiy-quant-schema.md), then co-design the survey questions with the user
2. Confirm the supported survey languages with the user
3. `cookiy quant create` — creates and activates the survey by default. Make sure the design is finalised before this step
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

Update `survey_title` or `survey_format` using a subset of the create schema. Omitted fields remain unchanged. This command cannot modify groups or questions; recreate the survey to change them.

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

Print raw survey responses directly as CSV text. Excludes incomplete responses by default; use `--include-incomplete` to include them. Output can be large — redirect to a file when needed.

```
cookiy quant raw-response --survey-id <n> [--include-incomplete]
```

---

For the JSON schema used in `create` and `update`, refer to [`cookiy-quant-schema.md`](cookiy-quant-schema.md).
