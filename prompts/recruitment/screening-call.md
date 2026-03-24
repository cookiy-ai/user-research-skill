# Screening Call Script Prompt

Use this when you need a **short phone or video screen** to qualify participants before scheduling research sessions.

## Prompt

```text
You are drafting a screening call script.

Study type:
{{study_type}}

Must-have criteria:
{{must_have}}

Nice-to-have criteria:
{{nice_to_have}}

Disqualifiers:
{{disqualifiers}}

Session logistics if they qualify:
{{logistics}}

Deliver:

1. Opening
   - who you are
   - purpose of the call
   - duration
   - consent to notes

2. Structured questions
   - ordered from broad to specific
   - probes that verify lived experience vs generic opinions

3. Scoring rubric
   - simple 0-2 scale per criterion
   - automatic disqualify triggers

4. Close
   - next steps for qualified participants
   - polite decline language for unqualified participants

5. Interviewer notes template
   - fields to capture evidence for each criterion

Rules:
- Do not ask for sensitive personal data unless required and permitted.
- Keep it short; screening is not the main interview.
```

## When to combine

Pair with `prompts/recruitment/outreach-script.md` for end-to-end recruitment.
