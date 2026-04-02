# Phase 3: Theme Development

You are a sub-agent executing Phase 3 of a qualitative research synthesis. Your goal is to elevate individual codes into meaningful themes — systematically transitioning from the real and particular to the abstract and general. This is second-cycle coding: you are no longer labeling data, you are building analytic structure.

## Context

You will receive:
- `analysis/phase2-coding/codebook.md` — the complete codebook
- `analysis/phase2-coding/codebook-changelog.md` — how codes evolved
- `analysis/phase2-coding/coded-excerpts/` — all coded excerpts by code
- `analysis/phase2-coding/phase2-summary.md` — coding summary and recommendations
- `analysis/phase1-familiarization/consolidated-observations.md` — initial observations
- `analysis/config.md` — analysis configuration

## Your Outputs

Write all outputs to `analysis/phase3-themes/`.

---

## Task 1: Build the Frequency Matrix (`frequency-matrix.md`)

Create a matrix showing which codes appear in which interviews. This is the quantitative backbone of your thematic analysis.

```markdown
# Code Frequency Matrix

| Code | P01 | P02 | P03 | ... | Total | % of Sample |
|------|-----|-----|-----|-----|-------|-------------|
| [Category] > [Code] | x | | x | | 15 | 30% |
| ... | | x | x | | 8 | 16% |
```

Then summarize:
- **High-frequency codes** (>50% of sample): These are likely core themes
- **Mid-frequency codes** (20-50%): May represent important sub-themes or segment-specific patterns
- **Low-frequency codes** (<20%): Check if these are noise or meaningful signals from a specific subgroup
- **Co-occurring codes**: Which codes appear together in the same interviews?

## Task 2: Identify Code Co-Occurrence (`co-occurrence.md`)

Analyze which codes cluster together:

```markdown
# Code Co-Occurrence Analysis

## Strong Co-Occurrences (appear together in >60% of cases)
- [Code A] + [Code B]: [Interpretation — why might these co-occur?]

## Inverse Relationships (rarely appear together)
- [Code A] vs [Code B]: [Interpretation — are these competing patterns?]

## Code Clusters
Codes that form natural groupings based on co-occurrence:

### Cluster 1: [Descriptive Name]
- Codes: [list]
- Shared thread: [what connects them]
- Appears in participants: [list]

### Cluster 2: [Descriptive Name]
- Codes: [list]
- Shared thread: [what connects them]
- Appears in participants: [list]
```

## Task 3: Develop Themes (`themes.md`)

A theme is NOT just a code renamed. A theme is a researcher-constructed interpretation that captures a **meaningful pattern** — it identifies what a unit of data *means* in relation to the research questions. Developing themes requires a rigorous, multi-step elevation process.

### Step 1: Focused Coding — Identify Salient Categories

Review all first-cycle codes and identify the most frequent or significant ones. This forces decisions about which codes make the most analytic sense for the entire dataset.

- **If you have many granular "splitter" codes**: Use "lumping" to group them into fewer, more manageable analytic units before proceeding.
- **Goal**: Reduce the code list to a set of candidate categories, each grouping codes that share thematic similarity.

### Step 2: Axial Coding — Explore Category Properties and Relationships

For each candidate category, analyze:
- **Properties**: What are the characteristics of this category? What dimensions does it have?
- **Dimensions**: What is the range of each property? (e.g., frequency: daily → yearly; intensity: mild → severe)
- **Relational structure**: How do categories relate to each other?
  - **Conditions**: What circumstances give rise to this category?
  - **Interactions**: How does this category interact with others?
  - **Consequences**: What results from this category?

This step prevents themes from being flat labels — it gives them internal structure and external connections.

### Step 3: Pattern Coding — Build Meta-Codes

Pull together first-cycle codes into explanatory or inferential "meta-codes" — pattern codes that describe causes, explanations, or theoretical constructs. These are the building blocks of themes.

Use the **"Five Rs"** as a pattern detection lens:
- **Routines**: What do participants do regularly? What habits and practices recur?
- **Rituals**: What symbolic or meaningful repeated actions appear?
- **Rules**: What explicit or implicit rules govern behavior?
- **Roles**: What roles do participants occupy, claim, or resist?
- **Relationships**: What relationship dynamics shape experience?

Look for repetitive, regular, or consistent occurrences that appear more than twice.

### Step 4: Narrative Thread Analysis

Look for story lines that interweave across different participants' accounts. These are not just shared topics but shared *narrative structures* — similar sequences, turning points, or arc shapes.

- Preserve **in-vivo codes** (participants' own words) as motifs within the broader patterns. These anchor themes in authentic voice.
- Ask: Do multiple participants tell a similar *story*, not just mention a similar *topic*?

### Step 5: The "Touch Test" — Elevate to Conceptual Meaning

For each candidate theme, apply the abstraction test: **Can you physically touch what this theme describes?**

- If YES (e.g., "Drug use," "Support tickets," "Login screen") → you are still at the descriptive/topic level. Push further.
- If NO (e.g., "Dependency," "Silent struggle," "Trust erosion") → you have reached conceptual meaning.

This is the critical difference between a topic and a theme:
- **Topic** (touchable): "Onboarding experience" — merely names a subject
- **Theme** (conceptual): "Users develop personal workarounds before seeking official support" — captures an insight about behavior, meaning, or mechanism

Every theme must pass the touch test. If it doesn't, keep abstracting.

### Step 6: Name and Define Themes

A good theme name is a phrase or sentence that captures the insight, not just a topic label. Write a 2-3 sentence definition that makes the theme's scope and meaning unambiguous.

### Theme Structure

```markdown
## Theme [N]: [Theme Name — a phrase that captures the insight]

**Definition**: [What this theme captures — 2-3 sentences. Must pass the touch test.]

**Properties & Dimensions**:
- [Property 1]: [Dimension range — e.g., "Intensity: from mild annoyance to rage-quit"]
- [Property 2]: [Dimension range]

**Constituent codes**:
- [Category] > [Code 1]: [How this code contributes to the theme]
- [Category] > [Code 2]: [How this code contributes to the theme]

**Prevalence**: Found in [X] of [Y] participants ([Z]%)

**Sub-themes** (if the theme has meaningful internal structure):

### Sub-theme [N.a]: [Name]
- **Description**: [What this sub-theme captures]
- **Codes**: [Which codes belong here]
- **Prevalence**: [X] of [Y]

### Sub-theme [N.b]: [Name]
- **Description**: [What this sub-theme captures]
- **Codes**: [Which codes belong here]
- **Prevalence**: [X] of [Y]

**Variation within this theme**: [How does this theme manifest differently across participants? Are there sub-groups?]

**Relational structure**:
- **Conditions**: [What gives rise to this theme? What context is required?]
- **Interactions**: [How does this theme interact with other themes?]
- **Consequences**: [What results from this theme? What does it lead to?]

**Narrative threads**: [What shared story lines or arcs connect to this theme? What in-vivo motifs recur?]

**Strongest evidence**: [2-3 quotes that most vividly illustrate this theme]
> "[Quote]" — [Participant ID]

**Boundary cases**: [Participants who partially fit — what makes them edge cases?]
```

### Theme Quality Criteria

For each candidate theme, verify:
- **Touch test**: Does the theme name describe something you CANNOT physically touch? If you can touch it, it's a topic, not a theme. Keep abstracting.
- **Coherence**: Do all constituent codes genuinely belong together, or is this a forced grouping?
- **Distinctness**: Is this theme clearly different from every other theme? Could a reader tell them apart?
- **Saturation**: Is there enough evidence? (Minimum: appears in 2+ interviews)
- **Analytic value**: Does this theme say something about the research questions, or is it just a category?
- **Dimensional richness**: Does the theme have identified properties and dimensions, or is it flat?

### Target: 5-10 Themes

Aim for 5-10 well-defined themes. Fewer than 5 suggests under-analysis. More than 10 suggests themes need consolidation. Some may be "major" (high prevalence, central to research questions) and others "minor" (lower prevalence but analytically important).

## Task 4: Identify the Core Category (`themes.md` — final section)

After developing all themes, step back and ask: **What is this research fundamentally about?**

Identify a **core category** — the central theme that functions as the "spine" of the analysis. All other themes should relate to it as conditions, consequences, strategies, or dimensions. The core category explains, at the highest level of abstraction, what this research is all about.

```markdown
## Core Category: [Name]

**Statement**: [One sentence that integrates the core category with its key relationships]

**How other themes relate**:
- Theme [X] is a [condition / consequence / strategy / dimension] of the core category
- Theme [Y] is a [condition / consequence / strategy / dimension] of the core category
- ...

**Codeweaving narrative**: [Integrate key code words and phrases into a narrative paragraph that weaves the themes together — this tests whether the pieces truly form a coherent whole. Write 3-5 sentences that tell the story of the data using theme and code language.]
```

The codeweaving narrative is a synthesis test: if you cannot write a coherent paragraph weaving the themes together, the thematic structure needs revision.

## Task 5: Track the Abstraction Progression (`code-map.md`)

Document how the analysis progressed through levels of abstraction. This makes the analytic journey transparent and auditable.

```markdown
# Code Map: Abstraction Progression

## Iteration 1: First-Cycle Codes (from Phase 2)
[List all codes as received from the codebook — the raw material]

## Iteration 2: Focused Codes (lumped/prioritized)
[Show which first-cycle codes were grouped, which were deprioritized, and why]

## Iteration 3: Categories (from axial coding)
[Show the categories with their properties and dimensions]

## Iteration 4: Themes (final thematic structure)
[Show the themes, sub-themes, and core category — the final architecture]

## Key Analytic Moves
[Document the 3-5 most consequential decisions in moving from codes to themes:
 - What was merged and why?
 - What was elevated and why?
 - What was deprioritized and why?
 - Where did you change direction?]
```

## Task 6: Pattern Analysis (`pattern-analysis.md`)

Go beyond individual themes to analyze cross-cutting patterns:

```markdown
# Pattern Analysis

## Cross-Cutting Patterns
[Patterns that span multiple themes — e.g., temporal sequences, causal chains, typologies.
 Use the Five Rs as a detection lens: routines, rituals, rules, roles, relationships.]

### Pattern: [Name]
- **Description**: [What this pattern captures]
- **Themes involved**: [Which themes participate]
- **How it works**: [The mechanism or sequence]
- **Five Rs mapping**: [Which of the Five Rs does this pattern involve?]
- **Evidence**: [Key supporting data]

### Narrative Threads
[Story lines that weave across multiple participants' accounts — shared arcs, parallel sequences, common turning points]

#### Thread: [Name]
- **The shared story**: [What narrative structure recurs?]
- **Participants who tell this story**: [list]
- **Key in-vivo motifs**: [Participants' own recurring phrases/metaphors that carry this thread]
- **Variation in the story**: [How does the arc differ across participants?]

## Contradictions & Tensions
[Where the data tells conflicting stories. These are analytically valuable — do not suppress them.]

### Contradiction: [Name]
- **What conflicts**: [Theme A suggests X, but Theme B suggests Y]
- **Disconfirming evidence**: [Specific quotes/observations that oppose the dominant pattern]
- **Possible explanations**: [Different segments? Context-dependent? Developmental stage?]
- **Participants on each side**: [Who holds which position]
- **Analytic significance**: [What does this contradiction reveal that the dominant pattern alone doesn't?]

## Outlier Analysis
[The outlier is your friend. Participants or observations that don't fit any theme are not noise — they test and refine your interpretation.]

### Outlier: [Participant ID or observation]
- **What doesn't fit**: [How this deviates from the thematic structure]
- **Possible explanations**: [Why this participant/observation differs]
- **What it reveals**: [How considering this outlier sharpens or qualifies the analysis]
- **Action taken**: [Did this outlier cause you to revise a theme? Add a boundary condition? Create a sub-theme?]

## Surprises
[Findings that challenge conventional wisdom or prior expectations]

### Surprise: [Name]
- **Expected**: [What you or the literature would predict]
- **Found**: [What the data actually shows]
- **Significance**: [Why this matters]

## Absences
[What participants do NOT talk about that you'd expect them to]
- **Expected topic**: [What's missing]
- **Possible reasons**: [Taboo? Taken for granted? Genuinely not relevant?]
```

## Task 7: Write Phase 3 Summary (`phase3-summary.md`)

Concise handoff (~600 words):

```markdown
# Phase 3 Summary: Theme Development Complete

**Themes developed**: [Count] themes, [count] sub-themes
**Core category**: [Name — one sentence]

## Theme Overview
1. [Theme name] — [One sentence] — Prevalence: [X]%
2. [Theme name] — [One sentence] — Prevalence: [X]%
...

## Core Category & Codeweaving Narrative
[The codeweaving paragraph from Task 4 — this gives Phase 4 the "spine" of the analysis]

## Most Important Themes for Research Questions
[Which 3-4 themes most directly address the research objectives?]

## Key Cross-Cutting Patterns
[The 2-3 most significant patterns spanning themes]

## Narrative Threads
[The 1-2 strongest shared story lines across participants]

## Most Important Contradictions & Outliers
[Tensions and outliers that Phase 4 must address — these prevent findings from being simplistic]

## Emerging Participant Groupings
[Based on theme combinations, what types of participants are forming? This feeds persona construction in Phase 4]

## Evidence Strength Assessment
[Which themes have rock-solid evidence? Which are suggestive but thinner?]

## Recommended Focus for Phase 4
[What should synthesis prioritize? Where are the strongest findings candidates?]
```

## Quality Gate

Before writing your outputs, verify:

- [ ] **Touch test**: Every theme name describes something you cannot physically touch. If any theme is still a topic label, abstract further.
- [ ] **Groundedness**: Every theme can be traced back to specific codes and specific quotes. No theme exists as pure interpretation without data backing.
- [ ] **Dimensional richness**: Every theme has identified properties and dimensions, not just a flat label.
- [ ] **Relational structure**: Every theme has documented conditions, interactions, and/or consequences. Themes are connected, not isolated.
- [ ] **Core category**: A core category has been identified and all themes relate to it. The codeweaving narrative reads as a coherent whole.
- [ ] **Heterogeneity**: Have you represented variation WITHIN themes, not just the dominant manifestation? Themes should show range, not uniformity.
- [ ] **Contradiction foregrounding**: Contradictions and disconfirming evidence are kept in the foreground, not buried or discarded. Have you actively asked "Do any data oppose this conclusion?" for each theme?
- [ ] **Outlier analysis**: Outliers have been examined and their meaning explored. No inconvenient data has been quietly dropped.
- [ ] **Distinctness**: Can you explain how each theme differs from every other theme? If two themes blur together, consider merging them.
- [ ] **Minimum evidence**: Every theme appears in at least 2 interviews. Single-interview "themes" are observations, not themes.
- [ ] **Abstraction progression**: The code-map.md documents the journey from codes → focused codes → categories → themes. The analytic moves are transparent.
- [ ] **Reflexivity**: Have you documented why you grouped codes the way you did? Could someone disagree with your grouping? Acknowledge the judgment calls.

---

## Parallel Extensibility Slot

_The `parallel/` directory is reserved for future analysis signals embedded in this phase. Currently empty. Examples of what could be added here:_

- _`severity-ratings.md` — Severity ratings per theme based on user impact and frequency_
- _`sentiment-patterns.md` — Emotional valence patterns across themes_
- _`temporal-patterns.md` — How themes evolve across the user journey or over time_
