# Study Creation Workflow

## Trigger

User wants to create a new study, research project, or interview guide
from a research goal.

## Prerequisites

- Cookiy MCP is connected (cookiy_introduce succeeds)
- User has a research goal or question in mind

## Workflow

### 1. Upload images (if any)

If the user provides images (screenshots, mockups, reference materials),
upload each one before creating the study.

For each image:
```
cookiy_media_upload
  image_data: <base64 string>   (for local/chat images)
  image_url: <url>              (for remote images)
  content_type: image/png       (or jpeg, gif, webp)
```

Collect the returned `s3_key` from each upload. You must pair each
`s3_key` with a human-readable `description` for the next step.

### 2. Create the study

```
cookiy_study_create
  query: <research goal in plain language>
  language: <source language code, e.g. "en", "zh", "ja">
  thinking: "none" | "medium" | "high"  (optional, default none)
  attachments: [{ s3_key, description }, ...]  (from step 1)
```

Rules:
- `language` is an ISO language code for the study's primary language.
  Always pass it explicitly — do not rely on defaults.
- `query` should be the user's research goal in natural language,
  not a structured command.
- `thinking` controls the depth of AI reasoning during guide generation.

On success, the response includes `study_id`. Save it for all
subsequent calls.

On 402: display `payment_summary` and `checkout_url` to the user.

### 3. Poll guide generation status

```
cookiy_guide_status
  study_id: <from step 2>
```

Poll every 3-5 seconds until the status indicates the guide is ready.
Guide generation is asynchronous and may take 10-60 seconds.

### 4. Retrieve the generated guide

```
cookiy_guide_get
  study_id: <from step 2>
```

This returns the full discussion guide plus `important_field_review`.

### 5. Review critical settings

Read `important_field_review` from the guide response. Present these
fields to the user for confirmation:

**mode_of_interview**
- `video`: captures facial expressions, harder to recruit
- `audio`: lower barrier, broader recruitment pool
- `audio_optional_video`: audio-first with optional video
- Default is `video` unless the study has a reason to reduce camera
  requirements.

**screen_share / in_home_visit**
- Questions requiring screen share or rear camera significantly
  increase recruitment difficulty.
- Confirm these are intentional.

**sample_size**
- 5-8 for exploratory research
- 10-15 for validation studies
- 20+ for quantitative studies
- Directly impacts cost and timeline.

If the user wants to change any of these, transition to the
Guide Editing workflow (guide-editing.md).

### 6. Done

Present available next steps:
- **AI Interview**: simulate interviews with AI personas
- **Recruitment**: recruit real participants
- **Guide Editing**: refine the discussion guide further

## Error handling

| Situation | Action |
|---|---|
| 402 on study_create | Display payment_summary, offer checkout_url |
| guide_status stays not-ready for > 2 minutes | Inform user of delay, continue polling |
| Image upload fails | Report the specific image failure, continue with remaining images |
