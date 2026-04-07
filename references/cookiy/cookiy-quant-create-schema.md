# Cookiy Quant Survey Create — Payload Schema Reference

Schema for `cookiy.sh quant create --payload-file <path>` (MCP tool: `cookiy_quant_survey_create`).

---

## I18nText Convention

Any field marked **I18nText** accepts two forms:

| Form | Example | Behavior |
|------|---------|----------|
| Plain string | `"What is your age?"` | Applied to the base language (first in `languages`). |
| Per-language map | `{"en":"What is your age?","zh":"您的年龄？"}` | Each key is a language code; value is the text for that language. Keys should match entries in `languages`. |

When a per-language map is provided but a language key is missing, the first available value is used as fallback.

---

## Top-Level Object

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `survey_title` | **I18nText** | **Yes** | — | Survey title displayed to respondents. Keep ≤200 chars per language. |
| `languages` | `string[]` | No | `["en"]` | Ordered language codes. First entry = base language. Respondents can switch language on the survey page. Min 1, max 20. Each code: 2–16 chars (ISO 639-1 or IETF, e.g. `en`, `zh`, `ja`, `pt-BR`). |
| `survey_format` | `enum` | No | `"G"` | Presentation mode: `"G"` = group by group, `"A"` = all on one page, `"S"` = one question per page. |
| `activate` | `boolean` | No | `true` | Activate survey immediately so `survey_public_url` is respondent-ready. Set `false` for inactive draft. |
| `study_id` | `string` | No | — | Optional Cookiy study ID for your own notes. Not sent to the survey backend. Min 1 char. |
| `groups` | `Group[]` | **Yes** | — | At least 1, max 100. Each group contains ordered questions. |
| `quotas` | `Quota[]` | No | — | Max 100. Quota shells (limits and messaging). Answer-based membership may require the survey admin UI. |

---

## Group Object

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `title` | **I18nText** | **Yes** | — | Group title shown as section heading. |
| `description` | **I18nText** | No | `""` | Group description (HTML or plain text). Max 8000 chars per language. |
| `relevance` | `string` | No | `"1"` (always show) | Expression Manager expression gating the entire group, e.g. `Q1 == 'A1'`. Max 16000 chars. |
| `questions` | `Question[]` | **Yes** | — | Min 1, max 200. Questions in display order. |

---

## Question Object

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `code` | `string` | **Yes** | — | Unique question code, e.g. `Q1`, `G01Q02`. Must start with a letter, letters/digits only, 1–20 chars. No underscores, hyphens, or spaces. |
| `type` | `enum` | **Yes** | — | Question type (see table below). |
| `text` | **I18nText** | **Yes** | — | Question wording shown to respondents. Max 8000 chars per language. For `equation` type, outer `{…}` may be omitted. |
| `help` | **I18nText** | No | — | Help text below the question. Max 8000 chars per language. |
| `relevance` | `string` | No | `"1"` (always show) | Expression Manager expression controlling this question's visibility, e.g. `Q1 == 'A1'`. Max 16000 chars. |
| `mandatory` | `boolean` | No | `false` | Whether the question is required. |
| `allow_other` | `boolean` | No | — | **Only for `list_radio`**: show an "Other" free-text field. |
| `options` | `Option[]` | Conditional | — | **Required** for `list_radio`, `list_dropdown`, `multiple_choice`, `ranking`. Min 2, max 200. |
| `array_subrows` | `Subrow[]` | Conditional | — | **Required** for `array_flexible`. Min 2, max 100. |
| `array_scale` | `Scale[]` | Conditional | — | **Required** for `array_flexible`. Min 2, max 50. |

### Question Types

| `type` value | Respondent UI | Required fields |
|-------------|---------------|-----------------|
| `long_text` | Multi-line text input | — |
| `short_text` | Single-line text input | — |
| `list_radio` | Radio button list | `options` (≥2). Optional: `allow_other`. |
| `list_dropdown` | Dropdown select | `options` (≥2) |
| `multiple_choice` | Checkbox list | `options` (≥2) |
| `ranking` | Drag-to-rank list | `options` (≥2) |
| `yes_no` | Yes / No toggle | — |
| `numeric` | Number input | — |
| `array_flexible` | Matrix / Likert grid | `array_subrows` (≥2) + `array_scale` (≥2) |
| `boilerplate` | Display-only text | — |
| `file_upload` | File upload control | — |
| `equation` | Hidden computed field | — (text is an Expression Manager formula) |

### Option Object

Used in `options` for list/choice/ranking questions.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `code` | `string` | No | Auto: `A1`, `A2`, … | Answer code. 1–5 chars. |
| `label` | **I18nText** | **Yes** | — | Answer label shown to respondents. 1–2000 chars per language. |

### Subrow Object

Used in `array_subrows` for matrix questions.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `code` | `string` | **Yes** | — | Subquestion code (row identifier). 1–20 chars. |
| `label` | **I18nText** | **Yes** | — | Row label shown to respondents. 1–2000 chars per language. |

### Scale Object

Used in `array_scale` for matrix questions.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `code` | `string` | **Yes** | — | Scale code (column identifier). 1–5 chars. |
| `label` | **I18nText** | **Yes** | — | Column label shown to respondents (e.g. "Strongly agree"). 1–2000 chars per language. |

---

## Quota Object

Quota shells control survey completion limits. Answer-based membership rules may still require the survey admin UI.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | `string` | **Yes** | — | Quota name (admin-visible). 1–500 chars. |
| `limit` | `integer` | **Yes** | — | Maximum completed responses for this quota. ≥0. |
| `active` | `boolean` | No | `true` | Whether the quota is active. |
| `action` | `enum` | No | `"terminate"` | Action when quota triggers: `"terminate"`, `"terminate_visible_hidden"`, `"terminate_pages"`, `"confirm_terminate"`. |
| `autoload_url` | `boolean` | No | `false` | Auto-redirect when quota triggers. |
| `message` | `string` | No | `""` | Message shown when quota triggers. Max 8000 chars. **Required** if `url` or `url_description` is set. |
| `url` | `string` | No | — | Redirect URL when quota triggers. Max 8000 chars. Requires `message`. |
| `url_description` | `string` | No | — | URL description text. Max 500 chars. Requires `message`. |

---

## Validation Rules

1. **`list_radio` / `list_dropdown` / `multiple_choice` / `ranking`** require `options` with ≥2 entries.
2. **`array_flexible`** requires both `array_subrows` (≥2) and `array_scale` (≥2).
3. `options` may only be set on list/choice/ranking types.
4. `array_subrows` / `array_scale` may only be set on `array_flexible`.
5. `allow_other` may only be set on `list_radio`.
6. Quota `url` / `url_description` require `message` to be non-empty.
7. Question `code` must be unique within the survey and match `^[A-Za-z][A-Za-z0-9]*$`.

---

## Multi-Language Behavior

| Layer | Multi-language support |
|-------|----------------------|
| Survey title | Full — per-language via `I18nText`. |
| Question text / help | Full — per-language via `I18nText`. |
| Option / subrow / scale labels | Full — per-language via `I18nText`. |
| Group title | Base language only (survey backend API limitation). |
| Quota message | Base language only. |
| Respondent experience | Language switcher on the survey page; questions, options, and scale labels render in the selected language. |

When `languages` has a single entry, the survey is single-language. Plain strings in all text fields work identically to the previous behavior.

---

## Minimal Example (Single Language)

```json
{
  "survey_title": "Customer Feedback",
  "groups": [
    {
      "title": "General",
      "questions": [
        {
          "code": "Q1",
          "type": "list_radio",
          "text": "How satisfied are you?",
          "mandatory": true,
          "options": [
            { "code": "A1", "label": "Very satisfied" },
            { "code": "A2", "label": "Satisfied" },
            { "code": "A3", "label": "Neutral" },
            { "code": "A4", "label": "Dissatisfied" }
          ]
        },
        {
          "code": "Q2",
          "type": "long_text",
          "text": "Any additional comments?"
        }
      ]
    }
  ]
}
```

## Multi-Language Example

```json
{
  "survey_title": { "en": "Customer Feedback", "zh": "客户反馈问卷" },
  "languages": ["en", "zh"],
  "survey_format": "G",
  "groups": [
    {
      "title": { "en": "Satisfaction", "zh": "满意度" },
      "questions": [
        {
          "code": "Q1",
          "type": "list_radio",
          "text": { "en": "How satisfied are you?", "zh": "您的满意度如何？" },
          "help": { "en": "Select one option", "zh": "请选择一个选项" },
          "mandatory": true,
          "options": [
            { "code": "A1", "label": { "en": "Very satisfied", "zh": "非常满意" } },
            { "code": "A2", "label": { "en": "Satisfied", "zh": "满意" } },
            { "code": "A3", "label": { "en": "Neutral", "zh": "一般" } },
            { "code": "A4", "label": { "en": "Dissatisfied", "zh": "不满意" } }
          ]
        },
        {
          "code": "Q2",
          "type": "array_flexible",
          "text": { "en": "Rate the following:", "zh": "请评价以下方面：" },
          "mandatory": true,
          "array_subrows": [
            { "code": "SQ1", "label": { "en": "Speed", "zh": "速度" } },
            { "code": "SQ2", "label": { "en": "Quality", "zh": "质量" } },
            { "code": "SQ3", "label": { "en": "Support", "zh": "服务" } }
          ],
          "array_scale": [
            { "code": "1", "label": { "en": "Poor", "zh": "差" } },
            { "code": "2", "label": { "en": "Fair", "zh": "一般" } },
            { "code": "3", "label": { "en": "Good", "zh": "好" } },
            { "code": "4", "label": { "en": "Excellent", "zh": "优秀" } }
          ]
        },
        {
          "code": "Q3",
          "type": "long_text",
          "text": { "en": "Additional comments?", "zh": "其他意见？" }
        }
      ]
    }
  ],
  "quotas": [
    {
      "name": "Max 500 responses",
      "limit": 500,
      "action": "terminate",
      "message": "Thank you, the survey has reached its response limit."
    }
  ]
}
```

## Matrix + Conditional Logic Example

```json
{
  "survey_title": "Product Research",
  "languages": ["en"],
  "groups": [
    {
      "title": "Screening",
      "questions": [
        {
          "code": "S1",
          "type": "yes_no",
          "text": "Have you used our product in the last 30 days?",
          "mandatory": true
        }
      ]
    },
    {
      "title": "Detailed Feedback",
      "relevance": "S1 == 'Y'",
      "questions": [
        {
          "code": "Q1",
          "type": "multiple_choice",
          "text": "Which features did you use? (select all)",
          "options": [
            { "code": "A1", "label": "Search" },
            { "code": "A2", "label": "Dashboard" },
            { "code": "A3", "label": "Reports" },
            { "code": "A4", "label": "API" }
          ]
        },
        {
          "code": "Q2",
          "type": "ranking",
          "text": "Rank these features by importance:",
          "options": [
            { "code": "A1", "label": "Search" },
            { "code": "A2", "label": "Dashboard" },
            { "code": "A3", "label": "Reports" },
            { "code": "A4", "label": "API" }
          ]
        },
        {
          "code": "Q3",
          "type": "numeric",
          "text": "On a scale of 0–10, how likely are you to recommend us?",
          "help": "0 = not at all likely, 10 = extremely likely",
          "mandatory": true
        },
        {
          "code": "Q4",
          "type": "list_radio",
          "text": "What is your primary role?",
          "allow_other": true,
          "options": [
            { "code": "A1", "label": "Developer" },
            { "code": "A2", "label": "Designer" },
            { "code": "A3", "label": "Product Manager" },
            { "code": "A4", "label": "Researcher" }
          ]
        },
        {
          "code": "Q5",
          "type": "long_text",
          "text": "What would you improve?",
          "relevance": "Q3 <= 6"
        }
      ]
    }
  ]
}
```

---

## CLI Usage

```bash
# Single-language survey
cookiy.sh quant create --payload-file survey.json

# The payload file is the JSON object described above.
# All fields (languages, i18n text maps, groups, quotas) go inside the file.
```

## Response

On success, `data` includes:

| Field | Description |
|-------|-------------|
| `survey_id` | Numeric survey ID on the backend. |
| `languages` | Array of enabled language codes. |
| `language` | Base language code. |
| `survey_public_url` | Respondent-facing URL (ready if `activate=true`). |
| `created_groups` | Array of `{ title, group_id, question_ids }`. |
| `created_quotas` | Array of `{ name, quota_id }`. |
| `creation_summary_markdown` | Readable Markdown table of what was created. |
| `activation_note` | Whether the survey was activated or left as draft. |
