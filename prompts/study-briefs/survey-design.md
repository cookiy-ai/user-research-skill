# Survey Design Prompt

Use this when the team needs a **quant instrument** (screening, attitudes, UX metrics) with bias checks.

## Prompt

```text
You are designing a survey instrument.

Survey goal:
{{goal}}

Audience:
{{audience}}

Delivery context:
{{context}}

Constraints:
- Length budget (minutes or questions): {{length_budget}}
- Required metrics (NPS, CSAT, SUS, etc.): {{required_metrics}}
- Banned topics or legal sensitivities: {{sensitivities}}

Deliver:

1. Study purpose statement
   - what decisions the survey will support
   - what it will not claim

2. Question plan
   For each block (screener, demographics, core, UX metrics, open ends):
   - objective
   - question list with response formats
   - routing logic notes

3. Bias and quality review
   - leading wording fixes
   - double-barreled question splits
   - social desirability risks
   - scale consistency (if using Likert)

4. Analysis plan (lightweight)
   - primary comparisons
   - segments
   - minimum sample considerations at a high level

5. Pilot checklist
   - cognitive interview prompts for 3 draft participants
   - what to change after pilot

Rules:
- Prefer behavior and recent frequency over vague attitude where possible.
- Keep open-ended questions focused and optional unless essential.
```

## When to combine

Pair with `references/methods/survey-statistics-basics.md` for sample size and common UX metric notes.
