# AI Interview Workflow

## Trigger

User wants to run simulated interviews, AI-to-AI interviews, or test
the discussion guide with AI personas.

## Prerequisites

- Study exists (`study_id` is known)
- Discussion guide is ready (`cookiy_guide_status` returns ready)

If the guide is not ready, inform the user and either wait or
transition to Study Creation workflow.

## Workflow

### 1. Confirm guide readiness

```
cookiy_guide_status
  study_id: <study_id>
```

Only proceed if the guide status is ready. If not ready, poll or
inform the user.

### 2. Generate simulated interviews

Choose one of these persona input modes:

**Auto-generate (simplest — recommended for most cases):**
```
cookiy_simulated_interview_generate
  study_id: <study_id>
  auto_generate_personas: true
  persona_count: <number, 1-20>
```

**Single custom persona:**
```
cookiy_simulated_interview_generate
  study_id: <study_id>
  interviewee_persona: "A 35-year-old marketing manager who..."
```

**Multiple custom personas:**
```
cookiy_simulated_interview_generate
  study_id: <study_id>
  interviewee_personas: [
    "A 25-year-old student who...",
    "A 45-year-old executive who..."
  ]
```

**Multi-language personas (object form):**
```
cookiy_simulated_interview_generate
  study_id: <study_id>
  interviewee_personas: [
    {
      text: "A Japanese college student...",
      prompt_language_code: "ja"
    },
    {
      text: "A German engineer...",
      prompt_language_code: "de"
    }
  ]
```

Rules:
- `interviewee_persona` (singular) and `interviewee_personas` (array)
  CANNOT be provided together.
- For multi-language interviews, use the object form with
  `prompt_language_code` to prevent language drift.
- Each persona text is max 4000 characters.
- Max 20 personas per call.

On success, save the returned `job_id`.

On 402: display `payment_summary` and `checkout_url`.

### 3. Poll simulation status

```
cookiy_simulated_interview_status
  study_id: <study_id>
  job_id: <from step 2>
```

Poll every 5-10 seconds until the job completes. Simulations typically
take 1-5 minutes per persona.

### 4. List completed interviews

```
cookiy_interview_list
  study_id: <study_id>
  include_simulation: true
```

This returns interview identifiers. Use cursor-based pagination if
the list is long.

The runtime may also return:
- `status_breakdown` — interview counts by status
- `playback_ready_interview_ids` — completed interview IDs already ready
  for transcript/playback review

### 5. View interview transcripts

For each interview the user wants to review:

```
cookiy_interview_playback_get
  study_id: <study_id>
  interview_id: <from step 4>
```

Rules:
- Simulated interviews return `playback_type: "transcript"`.
  There is no audio or video for simulations — read the transcript
  directly from the tool response.
- Real interviews return `playback_type: "recording"` with a
  `playback_page_url` for synced review, and transcript text may or may
  not already be available in the same response.
- Always check `transcript_available`. If it is `false`, use the
  playback page now and retry this tool later for transcript text.
- When transcript text is available, it is included directly in the
  tool response. The playback page link is an optional supplement for
  interview review.
- `playback_page_url` expires in 24 hours. Call the tool again to
  get a fresh link if needed.

## Error handling

| Situation | Action |
|---|---|
| 402 on generate | Display payment_summary, offer checkout_url |
| 409 "guide not ready" | Guide was modified or not yet generated. Check guide_status. |
| Job status shows partial failures | Report which personas failed, offer to retry just those |
