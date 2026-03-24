# Qualitative Coding Prompt

Use this when raw notes or transcripts need structured **first-cycle and second-cycle** coding before theming.

## Prompt

```text
You are performing qualitative coding on research text.

Inputs:
- Raw text (notes, transcript excerpts, or bullet logs):
{{raw_text}}

Research questions:
{{research_questions}}

Coding goals:
{{coding_goals}}

Assume:
- Line or paragraph breaks are meaningful; preserve order.

Deliver:

1. Codebook (version 1)
   - Code name
   - Definition (1-2 sentences)
   - inclusion examples (paraphrased, not long quotes)
   - exclusion notes

2. First-cycle coding
   - Segment the text into meaningful chunks
   - Apply one or more codes per chunk
   - Flag "uncoded" segments with a short note why

3. Second-cycle coding
   - Merge synonyms
   - Elevate recurring patterns into candidate themes
   - List tensions or contradictions

4. Theme candidates
   For each theme:
   - working title
   - what it explains
   - strength of evidence (high/medium/low) with a one-line rationale
   - what would falsify it

5. Quality checks
   - Potential researcher bias
   - Questions to validate in the next session

Rules:
- Prefer descriptive codes before interpretive themes.
- Do not invent quotes; if evidence is thin, label it as thin.
```

## When to combine

Pair with `prompts/synthesis/affinity-mapping.md` if the team prefers sticky-note clustering over line-by-line coding first.
