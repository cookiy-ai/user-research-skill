# Opportunity Solution Tree (OST) Prompt

Use this when the team needs a **structured map** from outcomes to opportunities to solution ideas, typically during continuous discovery.

## Prompt

```text
You are building an Opportunity Solution Tree.

Desired outcome (customer-centric, measurable if possible):
{{outcome}}

Current evidence (insights, quotes, metrics, support themes):
{{evidence}}

Constraints:
{{constraints}}

Known solutions already in motion:
{{known_solutions}}

Produce:

1. Outcome framing
   - Rewrite the outcome to be specific and customer-centered
   - Success signals

2. Opportunities (problem spaces)
   - List 5-12 opportunities implied by the evidence
   - For each: who, when it hurts, current workaround

3. Solutions (solution ideas)
   - Map candidate solutions under opportunities
   - Tag each solution: small experiment vs larger bet

4. Priority view
   - Top 3 opportunities by evidence strength and impact
   - For each top opportunity, the cheapest next learning step

5. Risks and unknowns
   - Biggest assumptions
   - What research would de-risk fastest

Rules:
- Opportunities are not solutions; call out solution-y phrasing and fix it.
- Prefer many small bets over one large unvalidated bet.
- Mark items that need quantitative validation vs qualitative validation.
```

## Notes

OST is a widely used discovery framing device. This prompt captures a practical structure without copying proprietary diagrams verbatim.
