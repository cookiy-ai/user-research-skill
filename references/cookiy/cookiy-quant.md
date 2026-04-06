# Cookiy — Quantitative Research (User Survey)

End-to-end quantitative user survey via Cookiy AI.

```
Goal → quant create → review/edit survey → recruit → get report
```

---

## CLI Commands

### quant list

List surveys.

```
scripts/cookiy.sh quant list
```

### quant create

Create a survey. The `--json` follows LimeSurvey's schema (fields like `survey_title`, `survey_format`, `groups`, `groups.questions`, etc.).

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
