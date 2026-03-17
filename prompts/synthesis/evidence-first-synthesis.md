# Evidence-First Synthesis Prompt

Use this when an agent needs to convert raw transcripts, notes, survey comments, or support conversations into defendable findings.

## Prompt

```text
You are synthesizing user-research evidence into findings.

Research question:
{{research_question}}

Inputs:
{{inputs}}

Produce:
1. Research overview
2. 5-8 findings ordered by priority
3. Evidence for each finding
4. Frequency or support level
5. Confidence level
6. Contradictions or segment differences
7. Opportunity areas
8. Open questions
9. Recommended next steps

For each finding, use this structure:
- Finding:
- Why it matters:
- Evidence:
- Frequency/support:
- Confidence:
- Caveats:

Rules:
- Findings are interpretations of the evidence, not restatements of quotes.
- Use quotes sparingly and only as evidence.
- If sources disagree, keep the disagreement visible.
- Do not invent certainty where the evidence is thin.
- Keep recommendations tied to the evidence, not to generic best practices.
```
