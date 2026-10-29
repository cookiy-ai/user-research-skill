<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

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
| `relevance` | string | no | LimeSurvey Expression Manager. Default `"1"` (always show). e.g. `Q1 == 'A1'`. Only shows or hides the group — see [Screening](#screening). |

---

## Question

| Field | Type | Req | Notes |
|-------|------|-----|-------|
| `code` | string | yes | Unique within survey. `^[A-Za-z][A-Za-z0-9]*$`. `RID` is reserved. |
| `type` | enum | yes | See types below |
| `text` | I18nText | yes | For `equation`, outer `{…}` may be omitted. |
| `help` | I18nText | no | |
| `mandatory` | boolean | no | Default `false` |
| `relevance` | string | no | Expression Manager. Default `"1"`. Only shows or hides the question. |
| `screen_out_answers` | `string[]` | no | Answer codes that disqualify the respondent. See [Screening](#screening). |
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
- `code` must be unique within the survey; `RID` is reserved for the recruitment participant id
- `screen_out_answers` → `list_radio`, `list_dropdown`, `multiple_choice` (option codes, including the auto `A1`, `A2`…) or `yes_no` (`Y` / `N`); the question must have `mandatory: true`; it cannot list every answer

---

## Screening

When only some people may take the survey, ask the screening questions first and put the disqualifying answer codes in `screen_out_answers`. A respondent who gives any of them leaves the survey as soon as they submit that page and goes back to the recruitment panel as **screened out**: they do not count toward the participants you recruit and pay for, and they are not in the report.

- **Relevance is not screening.** Hiding the rest of the survey with `relevance` sends the respondent straight to the end, and reaching the end is a completed response — counted and paid for like any other.
- For `multiple_choice`, list the options whose selection disqualifies, e.g. a "None of these" option. Picking a disqualifying option disqualifies even when a qualifying one is also ticked.
- To screen in on a single-choice question, list every other answer. The free-text "Other" answer (`allow_other`) cannot be listed and never disqualifies, so leave `allow_other` off such a question.
- Screening must be set when the survey is created; `quant update` cannot change questions.

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

**Screening and conditional logic:**
```json
{
  "survey_title": "Product Research",
  "groups": [
    {
      "title": "Screening",
      "questions": [
        {
          "code": "S1", "type": "yes_no",
          "text": "Have you used our product in the last 30 days?",
          "mandatory": true,
          "screen_out_answers": ["N"]
        },
        {
          "code": "S2", "type": "multiple_choice",
          "text": "Which industries do you work in?",
          "mandatory": true,
          "options": [
            { "label": "Retail" },
            { "label": "Finance" },
            { "code": "NONE", "label": "None of these" }
          ],
          "screen_out_answers": ["NONE"]
        }
      ]
    },
    {
      "title": "Feedback",
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
