# Quant Survey — JSON Schema

## I18nText

Any field marked **I18nText** accepts a plain string (base language) or a per-language map:

```json
"text": "What is your age?"
"text": { "en": "What is your age?", "zh-Hans": "您的年龄？" }
```

---

## Top-Level Object

| Field | Type | Req | Default | Notes |
|-------|------|-----|---------|-------|
| `survey_title` | I18nText | yes | — | Updatable |
| `groups` | `Group[]` | yes | — | |
| `languages` | `string[]` | no | `["en"]` | First = base. LimeSurvey locale codes, e.g. `en`, `zh-Hans`, `zh-Hant-HK`, `ja`. |
| `survey_format` | enum | no | `"G"` | Presentation mode: `"G"` group-by-group, `"A"` all on one page, `"S"` one question per page. Updatable. |

---

## Group

| Field | Type | Req | Notes |
|-------|------|-----|-------|
| `title` | I18nText | yes | |
| `questions` | `Question[]` | yes | |
| `description` | I18nText | no | |
| `relevance` | string | no | LimeSurvey Expression Manager. Default `"1"` (always show). e.g. `Q1 == 'A1'` |

---

## Question

| Field | Type | Req | Notes |
|-------|------|-----|-------|
| `code` | string | yes | Unique within survey. `^[A-Za-z][A-Za-z0-9]*$`. |
| `type` | enum | yes | See types below |
| `text` | I18nText | yes | For `equation`, outer `{…}` may be omitted. |
| `help` | I18nText | no | |
| `mandatory` | boolean | no | Default `false` |
| `relevance` | string | no | Expression Manager. Default `"1"`. |
| `allow_other` | boolean | no | `list_radio` only — adds free-text "Other" option |
| `options` | `Option[]` | cond | Required for `list_radio`, `list_dropdown`, `multiple_choice`, `ranking`. Min 2. |
| `array_subrows` | `Subrow[]` | cond | Required for `array_flexible`. Min 2. |
| `array_scale` | `Scale[]` | cond | Required for `array_flexible`. Min 2. |

### Question Types

| type | UI | Required fields |
|------|----|-----------------|
| `long_text` | Multi-line input | — |
| `short_text` | Single-line input | — |
| `numeric` | Number input | — |
| `yes_no` | Yes / No | — |
| `list_radio` | Radio list | `options` (≥2); optional: `allow_other` |
| `list_dropdown` | Dropdown | `options` (≥2) |
| `multiple_choice` | Checkboxes | `options` (≥2) |
| `ranking` | Drag-to-rank | `options` (≥2) |
| `array_flexible` | Matrix / Likert grid | `array_subrows` (≥2) + `array_scale` (≥2) |
| `boilerplate` | Display-only text | — |
| `file_upload` | File upload | — |
| `equation` | Hidden computed field | text = Expression Manager formula |

---

## Option / Subrow / Scale

| Field | Type | Req | Notes |
|-------|------|-----|-------|
| `code` | string | no (Option: auto A1, A2…) / yes (Subrow, Scale) | |
| `label` | I18nText | yes | |

---

## Validation

- `allow_other` → `list_radio` only
- `options`/`array_subrows`/`array_scale` only on their respective types
- `code` must be unique within the survey

---

## Examples

**Multi-language:**
```json
{
  "survey_title": { "en": "Customer Feedback", "zh-Hans": "客户反馈问卷" },
  "languages": ["en", "zh-Hans"],
  "groups": [{
    "title": { "en": "Satisfaction", "zh-Hans": "满意度" },
    "questions": [{
      "code": "Q1",
      "type": "list_radio",
      "text": { "en": "How satisfied are you?", "zh-Hans": "您的满意度如何？" },
      "mandatory": true,
      "options": [
        { "code": "A1", "label": { "en": "Very satisfied", "zh-Hans": "非常满意" } },
        { "code": "A2", "label": { "en": "Satisfied", "zh-Hans": "满意" } },
        { "code": "A3", "label": { "en": "Neutral", "zh-Hans": "一般" } },
        { "code": "A4", "label": { "en": "Dissatisfied", "zh-Hans": "不满意" } }
      ]
    }]
  }]
}
```

**Conditional logic:**
```json
{
  "survey_title": "Product Research",
  "groups": [
    {
      "title": "Screening",
      "questions": [{
        "code": "S1", "type": "yes_no",
        "text": "Have you used our product in the last 30 days?",
        "mandatory": true
      }]
    },
    {
      "title": "Feedback",
      "relevance": "S1 == 'Y'",
      "questions": [
        {
          "code": "Q1", "type": "numeric",
          "text": "How likely are you to recommend us? (0–10)",
          "mandatory": true
        },
        {
          "code": "Q2", "type": "long_text",
          "text": "What would you improve?",
          "relevance": "Q1 <= 6"
        }
      ]
    }
  ]
}
```