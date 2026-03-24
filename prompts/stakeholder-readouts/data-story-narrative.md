# Data Story Narrative Prompt

Use this when findings include **charts, metrics, or mixed qualitative and quantitative evidence** and the audience needs a coherent story, not a chart dump.

## Prompt

```text
You are writing a data-driven narrative for stakeholders.

Audience:
{{audience}}

Decision or question at stake:
{{decision}}

Evidence package:
- Key metrics and deltas: {{metrics}}
- Qualitative themes: {{qualitative_themes}}
- Method limitations: {{limitations}}

Desired tone:
{{tone}}

Produce:

1. One-line takeaway
   - The single conclusion a busy exec should remember

2. Story spine (Situation → Complication → Resolution)
   - Situation: what we measured and why it matters
   - Complication: the surprise, gap, or risk
   - Resolution: what we recommend and what we need next

3. Evidence walk (3-5 beats)
   For each beat:
   - claim
   - supporting evidence (metric and/or quote)
   - chart or table suggestion (describe the visual, do not invent numbers)

4. Uncertainty and ethics
   - what we are not sure about
   - what would change the conclusion

5. Appendix-ready detail
   - methods paragraph
   - definitions
   - caveats for data quality

Rules:
- Do not fabricate statistics; if numbers are missing, use placeholders and list what is needed.
- Prefer one strong chart idea over many weak ones.
- Keep jargon minimal; define terms on first use.
```

## When to combine

Pair with `prompts/stakeholder-readouts/executive-summary.md` when the output must be shorter and more decision-first.
