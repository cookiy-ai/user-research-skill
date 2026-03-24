# Affinity Mapping Prompt

Use this when the team has many discrete observations and needs a **bottom-up** grouping pass before prioritization.

## Prompt

```text
You are facilitating an affinity mapping synthesis.

Inputs:
- Observation list (one observation per line or bullet):
{{observations}}

Synthesis goal:
{{goal}}

Constraints:
- Target number of clusters: {{cluster_target}}
- Must-keep labels from the team: {{fixed_labels}}

Deliver:

1. Normalization pass
   - Merge duplicates
   - Split double ideas
   - Rewrite vague items into observable statements

2. Cluster draft
   - Cluster name
   - items in the cluster
   - cluster definition in one sentence
   - why these items belong together

3. Cluster relationships
   - Which clusters are causes vs symptoms
   - Dependencies or sequences if visible

4. Insight statements
   For each cluster with enough support:
   - insight (one sentence)
   - implication for product or research
   - confidence (high/medium/low) and what evidence is missing

5. Parking lot
   - Items that did not fit
   - suggested follow-up data to collect

Rules:
- Cluster names should describe the group, not a solution.
- Avoid premature prioritization until clusters stabilize.
```

## When to combine

Works well after `prompts/synthesis/qualitative-coding.md` when codes need to become wall-ready groups.
