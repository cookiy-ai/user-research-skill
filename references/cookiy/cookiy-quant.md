<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy — Quantitative Research (User Survey)

**Workflow:**
1. Read [`cookiy-quant-schema.md`](cookiy-quant-schema.md), then co-design the survey questions with the user
2. Confirm the supported survey languages with the user
3. Ask whether to activate immediately or keep a draft for native preview
4. `quant create` — always runs LimeSurvey's persisted native logic validation before any activation
5. If keeping a draft, open `quant admin-link`, preview/edit it in LimeSurvey, then activate it there when ready
6. Recruit participants only after the survey is active → get report

---

## CLI Commands

### quant list

List surveys.

```
scripts/cookiy.sh quant list
```

### quant create

Create a survey. Activation defaults to `true`. Set `"activate": false` to
keep a validated, inactive draft that the user can edit and preview in the
native LimeSurvey admin UI.

```
scripts/cookiy.sh quant create --json '<obj>'
```

The service validates the fully persisted survey for every language. With
`activate:true`, it activates only after validation succeeds. With
`activate:false`, it returns the validated draft with `active: "N"`; do not
recruit respondents from its public URL yet.

If creation returns `QUANT_SURVEY_LOGIC_INVALID`, the temporary survey has
been deleted. Do not retry the same JSON and do not describe the survey as
created.

Report every item in `error.details.errors` to the user. Locate each one using
the fields that refer to the JSON you sent, **not** the LimeSurvey ids:

| Field | Use |
|---|---|
| `group_index` | Zero-based position in the `groups` array you submitted |
| `group_title` | Title of that group |
| `question_code` | The `code` you gave the question, e.g. `S4` |
| `location` | For `scope: "survey"` errors, which survey-level field is broken, e.g. `Welcome` or `End URL` |
| `language` | Which language the error was found in |
| `issues[].message` / `.token` / `.expression` | LimeSurvey's own message, the offending token, and the full expression containing it |

`discarded_survey_id`, `group_id` and `question_id` are audit context only.
They identify rows in the survey that was just deleted, so they mean nothing to
the user and must not be presented as something to look up or open.

A `scope: "survey"` error with no `group_index` is not in any question — it is
in the survey-level text named by `location`.

Explain the concrete correction needed, revise the survey JSON with the user,
and only then retry `quant create`.

### quant admin-link

Open the current user's survey in LimeSurvey's native admin UI. For an inactive
draft, let the user use LimeSurvey's Preview action, edit the questionnaire,
and activate it when ready. Give the returned `admin_login_url` to the user to
open immediately; it is short-lived.

```
scripts/cookiy.sh quant admin-link --survey-id <n>
```

Native activation automatically reruns the same persisted logic validation.
If LimeSurvey blocks activation, keep the survey as a draft, fix the reported
logic in the admin UI, preview again, and retry activation. Do not recruit until
`quant get` or `quant list` reports `active: "Y"`.

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

### quant raw-response

Raw survey responses as CSV. Excludes incomplete by default. Output can be large — better redirect to a file.

```
scripts/cookiy.sh quant raw-response --survey-id <n> [--include-incomplete]
```

---

For the JSON schema used in `create` and `update`, refer to [`cookiy-quant-schema.md`](cookiy-quant-schema.md).
