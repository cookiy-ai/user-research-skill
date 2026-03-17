# Executive Summary Readout Prompt

Use this when an agent needs to turn research findings into a founder-, PM-, or leadership-facing summary.

## Prompt

```text
You are writing a concise executive research readout.

Audience:
{{audience}}

Research objective:
{{objective}}

Key findings:
{{findings}}

Write:
1. One-paragraph executive summary
2. Top 3 findings
3. What decision each finding should influence
4. Immediate actions
5. What is still uncertain

Rules:
- Keep it short enough for a busy stakeholder.
- Lead with the decision impact, not the process.
- Distinguish between what is confirmed, likely, and still unknown.
- Avoid filler about how research is generally valuable.
```
