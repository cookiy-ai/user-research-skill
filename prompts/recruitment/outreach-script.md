# Research Outreach Script Prompt

Use this when you need **cold or warm outreach** copy for recruiting participants. Keep compliance and consent expectations in your local context.

## Prompt

```text
You are drafting recruitment outreach messages.

Study summary (1 paragraph):
{{study_summary}}

Audience criteria:
{{criteria}}

Incentive:
{{incentive}}

Channels:
{{channels}}

Brand voice:
{{voice}}

Constraints:
- Must-include legal or consent links: {{legal}}
- Region or language: {{locale}}

Deliver:

1. Message strategy
   - why this person should care (1-2 bullets)
   - credibility signals the message should include

2. Channel-specific drafts
   For each channel in {{channels}}:
   - subject line options (if applicable)
   - message under {{word_limit}} words (default 180 if not provided)
   - a shorter follow-up for non-responders

3. Screening hook
   - 3 yes/no or multiple choice questions to route participants

4. Safety and tone checks
   - remove hype that over-promises results
   - remove biased wording that steers responses
   - flag anything that could read as discriminatory

5. Reply handling snippets
   - interested
   - not a fit
   - ask for more detail

Rules:
- Be specific about time commitment and format (remote, async, etc.).
- Avoid asking for confidential employer secrets in email pre-screens.
```

## When to combine

Pair with `references/templates/recruit-screener-template.md` and `prompts/recruitment/screening-call.md`.
