# Usability Test Script Prompt

Use this when the team has a prototype or live product and needs a **task-based** usability session script.

## Prompt

```text
You are drafting a moderated usability test script.

Product or prototype:
{{product}}

Participant profile:
{{participant}}

Test environment:
{{environment}}

Tasks to evaluate (ordered):
{{tasks}}

Success criteria (what "done" means per task):
{{success_criteria}}

Known product risks or fragile areas:
{{known_risks}}

Produce:

1. Session structure (with time boxes)
   - Consent and recording notes
   - Background questions (minimal)
   - Task instructions
   - Debrief

2. Task scripts
   For each task:
   - neutral scenario prompt (no UI labels unless necessary)
   - starter question
   - optional probes if they hesitate
   - what to observe (errors, recovery, confusion signals)

3. Moderator rules
   - When to help vs when to wait
   - Standard phrase for avoiding direct answers
   - How to ask "what are you thinking?" without biasing

4. Severity note template
   - How to log issue: task, quote, outcome (fail/partial/success), suspected cause

5. Post-test questions
   - Expectation match
   - confidence rating for critical actions
   - comparison to existing tools if relevant

Rules:
- Do not teach the interface during tasks unless safety requires it.
- Prefer realistic goals over feature tours.
- Keep tasks independent when possible; if order matters, say why.
```

## When to combine

Use with `references/templates/discussion-guide-template.md` for a broader study that includes usability tasks as one module.
