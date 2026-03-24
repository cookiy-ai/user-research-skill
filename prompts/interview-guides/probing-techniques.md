# Probing Techniques Prompt

Use this when an interview guide exists but follow-ups need to be sharper, or when the agent should coach an interviewer on **how** to probe without leading.

## Prompt

```text
You are improving follow-up probes for a user interview.

Interview topic:
{{topic}}

Current draft questions (optional):
{{draft_questions}}

Constraints:
- Session length: {{duration}}
- Sensitive topics to avoid: {{sensitive_topics}}

Produce a probing toolkit with four parts:

1. Technique menu
   For each technique below, give 2 example probes written for this topic:
   - Clarify scope: "What happened right before that?"
   - Story arc: "Walk me through the last time that happened."
   - Contrast: "How is that different from {{baseline}}?"
   - Evidence: "What did you see or do that made you think that?"
   - Impact: "What did that cost you in time, money, or risk?"
   - Calibration: "On a scale from X to Y, where would you put that and why?"

2. Mirroring and labeling (neutral tone)
   - Short mirror phrases that invite more detail without agreeing or disagreeing
   - Labeling phrases that name emotion or tension without judging

3. Anti-patterns to remove
   - Leading questions, double-barreled questions, solution selling
   - For each flagged pattern, suggest a neutral replacement

4. Interviewer checklist (10 bullets)
   - What to listen for
   - When to stay silent
   - When to switch from "why" to "what happened"

Rules:
- Keep probes short and conversational.
- Prefer recent, concrete episodes over hypotheticals.
```

## Notes

This prompt encodes common qualitative practice (probes, contrast, calibration). It is not a transcript of any single published work.
