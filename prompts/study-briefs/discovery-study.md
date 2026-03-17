# Discovery Study Brief Prompt

Use this when you have a loose product question and need an agent to produce a strong research brief that can be turned into a Cookiy study.

## Input Checklist

- Product or feature
- Target user or buyer
- Decision that the team needs to make
- Current hypothesis
- Constraints:
  - geography
  - language
  - timing
  - sample size
  - artifacts available

## Prompt

```text
You are preparing a user-research study brief for Cookiy.

Start from the raw business question below and turn it into a research-ready brief.

Business question:
{{business_question}}

Context:
- Product: {{product}}
- Target user: {{target_user}}
- Stage: {{stage}}
- Current hypothesis: {{hypothesis}}
- Decision this research should inform: {{decision}}
- Constraints: {{constraints}}
- Available artifacts: {{artifacts}}

Produce:
1. Research objective
2. Key learning questions
3. Best-fit method for this stage
4. Recommended participant profile
5. Suggested sample size
6. Risks or ambiguities in the current brief
7. A final plain-language study description that can be pasted into Cookiy

Rules:
- Be specific about what the team is trying to learn.
- Remove solution bias and feature-leading language where possible.
- If the input is underspecified, call out the missing pieces explicitly.
- Keep the final Cookiy-ready description natural and concise.
```

## What Good Output Looks Like

- clear objective
- no mixed goals
- participant definition is testable
- sample size matches method
- final study description is short enough to paste directly into a tool
