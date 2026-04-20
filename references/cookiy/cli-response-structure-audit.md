# Cookiy CLI — response structure audit

- Generated: `2026-04-20T04:12:21.825158+00:00`
- CLI: `1.21.0` · Server: `https://s-api.cookiy.ai`
- Read study (data-rich): `019c51ab-cb2b-7094-a59f-e9d12e18ffc9`
- Write study (scratch): `019d950f-2493-712e-bf9e-f3526a4effca`
- Interview / Survey: `019d0506-2a2a-76aa-bdf2-e0c25e7a51b8` / `878381`
- Dynamic survey used after `quant create`: `449428`
- Scope: **all cookiy.sh commands** except **`recruit`** (same order as implementation allows).

Expand each command to see the **field-type tree** (placeholders only).

<details>
<summary>`usage (no args)` · exit 0 · non-JSON (help text or MCP error)</summary>

```text
text (27 lines)
```

</details>

<details>
<summary>`-h / --help` · exit 0 · non-JSON (help text or MCP error)</summary>

```text
text (27 lines)
```

</details>

<details>
<summary>`--version` · exit 0 · non-JSON (help text or MCP error)</summary>

```text
text (1 lines)
```

</details>

<details>
<summary>`help` · exit 0 · non-JSON (help text or MCP error)</summary>

```text
text (134 lines)
```

</details>

<details>
<summary>`help commands (argv ignored by CLI; same body as help)` · exit 0 · non-JSON (help text or MCP error)</summary>

```text
text (134 lines)
```

</details>

<details>
<summary>`save-token (skipped — CLI_AUDIT_SKIP_SAVE_TOKEN=1)` · exit 0 · non-JSON (help text or MCP error)</summary>

```text
(not run)
```

</details>

<details>
<summary>`study list --limit 3` · exit 0 · 1 JSON value(s)</summary>

```text
list:
  array[
    studyId: string
    projectName: string
    createdAt: string
  ]
limit: number
cursor: string
next_cursor: string
total: number
```

</details>

<details>
<summary>`study list --limit 1 (seed cursor)` · exit 0 · 1 JSON value(s)</summary>

```text
list:
  array[
    studyId: string
    projectName: string
    createdAt: string
  ]
limit: number
cursor: string
next_cursor: string
total: number
```

</details>

<details>
<summary>`study list --limit 1 --cursor <from prior>` · exit 0 · 1 JSON value(s)</summary>

```text
list:
  array[
    studyId: string
    projectName: string
    createdAt: string
  ]
limit: number
cursor: string
next_cursor: string
total: number
```

</details>

<details>
<summary>`study create --query (no --wait)` · exit 0 · 1 JSON value(s)</summary>

```text
studyId: string
status: string
```

</details>

<details>
<summary>`study status --study-id` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
project_name: string
created_at: string
updated_at: string
current_stage: string
target_sample_size: number
sources:
  guide:
    status: string
  recruit:
    status: string
    completed_participants: number
    target_participants: number
  interviews:
    total: number
    completed: number
    disqualified: number
    in_progress: number
    paused: number
  synthetic_interviews:
    target_nums: number
    completed_nums: number
```

</details>

<details>
<summary>`study upload --image-url` · exit 0 · 1 JSON value(s)</summary>

```text
s3_key: string
```

</details>

<details>
<summary>`study guide get --study-id (scratch)` · exit 0 · 1 JSON value(s)</summary>

```text
revision: string
discussion_guide:
  core_research_questions:
    array[
      text: string
    ]
  participant_screening_criteria:
    screening_questions:
      array[
        screener_question: string
        type: string
        options: array[object(description,correct)]
        description: string
        media: array[]
      ]
  interview_flow:
    sections:
      array[
        question_list: array[object(question,type,question_depth,required_screen_share,required_in_home_visit,options,followups,media)]
        description: string
      ]
  research_overview:
    project_name: string
    research_objective: string
    interview_duration: number
    interview_methodology: string
    sample_size: number
    mode_of_interview: string
    target_group: string
    external_knowledge: string
```

</details>

<details>
<summary>`study guide update --json (minimal patch, scratch)` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
revision: string
base_revision: string
idempotency_key: string
applied: boolean
```

</details>

<details>
<summary>`study interview list --study-id` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
interviews:
  array[
    interview_id: string
    status: string
    duration_seconds: number
    is_simulation: boolean
    created_at: string
  ]
total: number
limit: number
cursor: string
next_cursor: null
avg_duration_minutes: number
```

</details>

<details>
<summary>`study interview playback url --study-id (no interview-id)` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
interviews:
  array[
    interview_id: string
    playback_page_url: string
    playback_page_expires_at: string
  ]
total: number
```

</details>

<details>
<summary>`study interview playback url --study-id --interview-id` · exit 0 · 1 JSON value(s)</summary>

```text
interview_id: string
playback_page_url: string
playback_page_expires_at: string
```

</details>

<details>
<summary>`study interview playback content --study-id (no interview-id)` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
interviews:
  array[
    interview_id: string
    transcript:
      array[
        role: string
        content: string
        message_time: string
      ]
    turn_count: number
    transcript_available: boolean
    playback_type: string
  ]
total: number
```

</details>

<details>
<summary>`study interview playback content --study-id --interview-id` · exit 0 · 1 JSON value(s)</summary>

```text
interview_id: string
transcript:
  array[
    role: string
    content: string
    message_time: string
  ]
turn_count: number
transcript_available: boolean
playback_type: string
```

</details>

<details>
<summary>`study run-synthetic-user start (no --wait, scratch)` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
status: string
batch_target: number
batch_completed: number
```

</details>

<details>
<summary>`study report generate --skip-synthetic-interview (no --wait, scratch)` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
generation_request_id: string
report_status: string
```

</details>

<details>
<summary>`study report content --study-id` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
report_id: null
generated_at: null
title: null
markdown: null
report_status: string
```

</details>

<details>
<summary>`study report content --study-id --wait true --timeout-ms` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
report_id: null
generated_at: null
title: null
markdown: null
report_status: string
```

</details>

<details>
<summary>`study report link --study-id` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
report_status: string
share_url: null
share_password: null
```

</details>

<details>
<summary>`study report wait --study-id` · exit 0 · 1 JSON value(s)</summary>

```text
study_id: string
report_status: string
share_url: null
share_password: null
```

</details>

<details>
<summary>`quant list` · exit 0 · 1 JSON value(s)</summary>

```text
surveys:
  array[
    survey_id: number
    title: string
    active: string
  ]
count: number
```

</details>

<details>
<summary>`quant create --json` · exit 0 · 1 JSON value(s)</summary>

```text
survey_id: number
title: string
language: string
active: string
survey_public_url: string
survey_format: string
creation_summary_markdown: string
```

</details>

<details>
<summary>`quant get --survey-id` · exit 0 · 1 JSON value(s)</summary>

```text
survey_id: number
title: string
survey_format: string
language: string
survey_public_url: string
creation_summary_markdown: string
```

</details>

<details>
<summary>`quant update --json` · exit 0 · 1 JSON value(s)</summary>

```text
survey_id: number
survey_updated: boolean
```

</details>

<details>
<summary>`quant status --survey-id` · exit 0 · 1 JSON value(s)</summary>

```text
survey_id: number
survey:
  completed_responses: number
  incomplete_responses: number
  full_responses: number
recruit:
  status: string
  total_bought: number
  total_completed: number
```

</details>

<details>
<summary>`quant report --survey-id` · exit 0 · 1 JSON value(s)</summary>

```text
survey_id: number
completion_status: string
response_row_count: number
completion_funnel: null
question_summaries:
  array[]
```

</details>

<details>
<summary>`quant raw-response --survey-id` · exit 0 · non-JSON (help text or MCP error)</summary>

```text
text (139 lines)
```

</details>

<details>
<summary>`quant raw-response --survey-id --include-incomplete` · exit 0 · non-JSON (help text or MCP error)</summary>

```text
text (158 lines)
```

</details>

<details>
<summary>`billing balance` · exit 0 · 1 JSON value(s)</summary>

```text
balance_summary: string
```

</details>

<details>
<summary>`billing checkout --amount-usd-cents` · exit 0 · 1 JSON value(s)</summary>

```text
payment_required: boolean
amount_cents: number
formatted_amount: string
checkout_url: string
checkout_id: string
```

</details>

<details>
<summary>`billing price-table` · exit 0 · 1 JSON value(s)</summary>

```text
items:
  array[
    action: string
    price: string
  ]
```

</details>

<details>
<summary>`billing transactions --limit 5` · exit 0 · 1 JSON value(s)</summary>

```text
array[
  amount_cents: number
  type: string
  created_at: string
  quantity: number
  study_id: string
  project_name: string
  description: string
]
```

</details>

<details>
<summary>`billing transactions --study-id` · exit 0 · 1 JSON value(s)</summary>

```text
array[
  amount_cents: number
  type: string
  created_at: string
  quantity: number
  study_id: string
  project_name: string
  product_id: string
]
```

</details>

<details>
<summary>`billing transactions --survey-id` · exit 0 · 1 JSON value(s)</summary>

```text
array[]
```

</details>

---

**Notes:** Types are placeholders. Arrays show the **first element** shape; depth/key count may truncate. `billing transactions --survey-id` may fail if the API rejects numeric `survey_id`. Set `CLI_AUDIT_SKIP_CHECKOUT=1` to skip wallet checkout; `CLI_AUDIT_SKIP_SAVE_TOKEN=1` to skip token probe.
