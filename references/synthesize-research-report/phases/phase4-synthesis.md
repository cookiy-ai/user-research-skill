# Phase 4: Synthesis & Interpretation

You are a sub-agent executing Phase 4 of a qualitative research synthesis. This is the most intellectually demanding phase — you must integrate everything into prioritized findings, data-driven personas, outcome-oriented opportunities, and a curated evidence bank. This phase transforms analysis into actionable insight.

## Context

You will receive:
- `analysis/config.md` — configuration including research goal, persona type, prioritization framework
- `analysis/phase1-familiarization/consolidated-observations.md` — initial observations
- `analysis/phase1-familiarization/batch-{n}-memos.md` — all interview memos
- `analysis/phase2-coding/codebook.md` — complete codebook
- `analysis/phase2-coding/coded-excerpts/` — all coded excerpts
- `analysis/phase3-themes/themes.md` — theme definitions
- `analysis/phase3-themes/frequency-matrix.md` — prevalence data
- `analysis/phase3-themes/pattern-analysis.md` — cross-cutting patterns
- `analysis/phase3-themes/co-occurrence.md` — code/theme clusters
- `analysis/phase3-themes/phase3-summary.md` — theme summary and recommendations

## Your Outputs

Write all outputs to `analysis/phase4-synthesis/`.

---

## Task 1: Construct Personas

### Step 1: Confirm Persona Type (`personas/persona-type-rationale.md`)

Review `config.md` for the pre-selected persona type. Validate it against what the data actually shows:

| If data shows... | Best persona type |
|-----------------|------------------|
| Distinct usage patterns and skill levels | Behavioral |
| Distinct mindsets, motivations, or values | Attitudinal |
| Distinct goals regardless of demographics | Goal-Based |
| Need to communicate to non-researchers | Narrative |
| Multiple organizational roles in the buying/using chain | Ecosystem |
| Limited data, need team alignment fast | Proto-Personas |
| Designing a bot/AI personality | System/VUI |

If the data suggests a different type than what was configured, document why and switch.

### Step 2: Cluster Participants (`personas/clustering-analysis.md`)

**Cluster by reasoning and behavior, not demographics.** Group participants by their patterns of action, domain knowledge, and motivations (e.g., "necessity-oriented" vs. "entertainment-oriented") rather than age or gender. Demographics are only relevant when they directly change how a person interacts with the product.

Identify the clustering dimensions based on persona type:

**Behavioral**: Cluster by usage frequency, feature adoption, skill level, workflow patterns
**Attitudinal**: Cluster by values, motivations, risk tolerance, decision-making style
**Goal-Based**: Cluster by primary objectives, success criteria, jobs-to-be-done
**Narrative**: Cluster by life/work context, journey stage, relationship to product/domain
**Ecosystem**: Cluster by organizational role, decision authority, success metrics

```markdown
# Clustering Analysis

## Clustering Dimensions
- [Dimension 1]: [Definition + spectrum]
- [Dimension 2]: [Definition + spectrum]

## Participant Mapping

| Participant | Dim 1 | Dim 2 | Cluster |
|-------------|-------|-------|---------|
| P01 | [position] | [position] | A |
| P02 | [position] | [position] | B |

## Identified Clusters
### Cluster A: [Working name]
- Participants: [list]
- Shared characteristics: [what unites them]
- Size: [count] ([%] of sample)

### Cluster B: [Working name]
...

## Rationale for Number of Personas
[Why this number? What would be lost by merging? What would be gained by splitting?]
Auto-determine the count: typically 3-5. Fewer than 3 suggests under-differentiation. More than 6 suggests overlap.
```

### Step 3: Write Individual Personas (`personas/persona-{n}-{name}.md`)

The exact template depends on persona type. Core structure applies three principles:

1. **"Differences that matter" filter**: Only include details that change how this person interacts with the product or domain. If a trait (age, location, job title) is irrelevant to their behavior, omit it. Every detail earns its place.
2. **Narrative glue**: Even for non-Narrative persona types, compose a brief composite that blends attributes from several similar participants into a cohesive character. The persona should feel like a real person, not a data table.
3. **Required anchors**: Every persona MUST have a **defining quote** (one quote that personifies their mindset) and **3-5 high-level goals** (what they care about at the end of the day).

```markdown
# Persona {N}: [Name]

**Type**: [Behavioral / Attitudinal / Goal-Based / Narrative / Ecosystem]

**Defining Quote**:
> "[The single quote that best personifies this persona's mindset]"

## Who They Are
- [Primary identifying characteristics relevant to the persona type — only "differences that matter"]
- [Context: role, environment, experience level, relationship to product/domain]
- [How they arrived at their current situation]

## High-Level Goals
1. [What they care about at the end of the day — outcome-level, not feature-level]
2. [Goal 2]
3. [Goal 3]
(3-5 goals)

## [Section varies by type]:

### For Behavioral Personas:
**How They Work/Use**:
- Frequency: [how often]
- Primary workflows: [what they do]
- Tools and integrations: [what else they use]
- Skill level: [novice → expert]
- Workarounds: [what they've hacked together]

### For Attitudinal Personas:
**What They Believe**:
- Core values: [what drives decisions]
- Attitude toward [domain]: [their stance]
- Risk tolerance: [how they handle uncertainty]
- Decision-making style: [how they evaluate options]

### For Goal-Based Personas:
**What They're Trying to Accomplish**:
- Primary job-to-be-done: [the outcome they seek]
- Success criteria: [how they know they've succeeded]
- Current approach: [how they try to achieve this today]
- Barriers: [what blocks them]

### For Narrative Personas:
**A Day in Their Life**:
[2-3 paragraph narrative showing a typical scenario — grounded in real interview data, composited across cluster members. Show, don't tell.]

### For Ecosystem Personas:
**Their Role in the System**:
- Decision authority: [what they can approve/block]
- Success metrics: [what they're measured on]
- Information needs: [what they need to know]
- Relationship to other personas: [how they interact]

## Key Needs & Pain Points
1. [Need/Pain 1]: [Evidence — theme reference + brief quote]
2. [Need/Pain 2]: [Evidence]
3. [Need/Pain 3]: [Evidence]

## Representative Quotes (2-4)
> "[Quote that captures their voice]"
> — Context: [situation]

## How They Relate to Key Themes
- [Theme X]: [How this persona experiences this theme]
- [Theme Y]: [How this persona experiences this theme differently than other personas]

## Participants Represented
[List of participant IDs in this cluster — for traceability]
```

---

## Task 2: Synthesize Prioritized Findings (`findings.md`)

### Selecting the Prioritization Framework

Read `config.md` for the research goal and apply the corresponding framework:

**Criticality Scoring** (for tactical usability fixes):
- Score each finding: Severity (1-4) x Frequency (% of sample)
- Rank by composite score

**Opportunity Scoring** (for market gaps & innovation):
- Score each finding: Importance (how much users care) vs. Satisfaction (how well current solutions work)
- Prioritize where importance is high but satisfaction is low

**Impact/Effort Matrix** (for MVP/sprint scoping):
- Score each finding: Customer Impact (high/medium/low) vs. Implementation Effort (high/medium/low)
- Prioritize "quick wins" (high impact, low effort)

**Hypothesis Canvas** (for high-risk discovery):
- Score each finding: Risk if wrong vs. Perceived Value
- Prioritize "leap of faith" assumptions

**Opportunity Solution Tree** (for product strategy):
- Map findings as opportunities under desired outcomes
- Prioritize branches with strongest evidence and clearest path to solutions

Document your framework application in `prioritization-rationale.md`.

**Important**: Treat prioritization as a **"two-way door"** — a reversible decision. If new data or stakeholder feedback shows a high-priority finding is less impactful than expected, the team must be able to course-correct without delay. Note this explicitly in the rationale.

### Finding Tiers

After scoring, sort findings into three tiers:

| Tier | Label | Criteria | Report Treatment |
|------|-------|----------|-----------------|
| 1 | **Must Know** | High severity/impact, high frequency, high confidence | Detailed treatment, leads the report, demands immediate action |
| 2 | **Should Know** | Moderate impact or frequency, solid evidence | Standard treatment in the body of the report |
| 3 | **Nice to Know** | Lower frequency, exploratory, or lower confidence | Brief treatment, may move to appendix or open questions |

### Finding Structure

Aim for 5-8 key findings. Each finding must appear in at least 2 interviews.

```markdown
## Finding [N]: [One clear sentence stating the insight]

**Tier**: [Must Know / Should Know / Nice to Know]

**Priority**: [Rank from prioritization framework + score if applicable]

**Prevalence**: [X] of [Y] participants ([Z]%)

**Theme(s)**: [Which themes from Phase 3 this finding synthesizes]

**Persona impact**: [Which personas are most affected and how]

**Evidence**:

*Luminous exemplar* (the single most powerful quote):
> "[Verbatim quote]"
> — [Participant ID], [brief context]
> Why this quote: [What makes it analytically illuminating]

*Anchor candidate* (for extended treatment):
- [Participant ID]: [1-sentence reason they could illustrate this finding in depth]

*Supporting quotes (echoes)* showing prevalence:
> "[Short quote]" — [Participant ID]
> "[Short quote]" — [Participant ID]
> "[Short quote]" — [Participant ID]

**Variation**: [How does this finding manifest differently across participants or personas?]

**Negative cases**: [Participants who DON'T show this pattern — why not?]

**Confidence level**: [High / Medium / Low] — [Basis: number of sources, behavioral vs stated, triangulation]
```

---

## Task 3: Build the Evidence Bank (`evidence-bank.md`)

The evidence bank is NOT a dump of every quote — it is a curated "case file" containing only the meaningful bits of data that comprise your findings. A single well-chosen quote can be "worth ten thousand words" in driving team empathy.

### Curation Principles

- **Stickiness**: Select quotes that will resonate in a meeting room. The best quotes make the listener feel the participant's experience — they create empathy, not just understanding.
- **Traceability**: Every quote must be labeled with its original location (participant ID, transcript page/line number or timestamp) so the full context can be re-examined if a conclusion is challenged.
- **Paralinguistic cues**: Where available from transcripts, annotate quotes with non-verbal signals — tone, pauses, laughter, sighing, emphasis. These cues carry meaning that words alone miss.

```markdown
# Evidence Bank

## Finding [N]: [Name]

### Top Quotes (ranked by analytical power)

1. **Luminous exemplar**:
   > "[Full quote]"
   > — [Participant ID] ([demographics/context]) | Source: [transcript page/line or timestamp]
   > Paralinguistic cues: [tone, pauses, emphasis — if available]
   > Analytical value: [Why this quote does work — what it shows that explanation alone cannot]
   > Stickiness: [Why this quote will resonate with stakeholders]

2. **Anchor material** (extended excerpt for deep illustration):
   > "[3-6 sentence excerpt showing reasoning, emotion, or sequence]"
   > — [Participant ID] ([demographics/context]) | Source: [transcript location]
   > Paralinguistic cues: [if available]

3-5. **Echo quotes** (showing breadth):
   > "[1-2 sentence quote]" — [Participant ID] | Source: [transcript location]

### Counter-Evidence
> "[Quote from negative case]" — [Participant ID] | Source: [transcript location]
> How this was addressed: [explanation]
```

---

## Task 4: Map Opportunities (`opportunities.md`)

Transform findings into outcome-oriented opportunity statements. Frame as **customer needs, pain points, or desires** — never as feature requests or solutions.

### Opportunity Formulation

Use one of two formats depending on precision needed:

**Standard format**: "Enable [persona/users] to [desired outcome] without [current barrier/pain]"

**Precision format** (Direction + Measure + Object + Clarifier):
"[Minimize/Maximize/Increase/Reduce] the [time/effort/cost/risk] to [action/object] [for context/clarifier]"

Example: "Minimize the time it takes to gather documents for sharing with colleagues"

The precision format is better when the opportunity needs to be measurable or directly translatable into requirements.

### Hierarchical Structure

Opportunities should be structured as a tree, not a flat list. Large, project-sized opportunities must be broken into smaller, more solvable **sub-opportunities (leaf-nodes)**. When prioritizing, always prefer to address a **leaf-node** (an opportunity with no children) to ensure the team delivers iterative value quickly.

```markdown
# Opportunity Areas

## Opportunity [N]: [Outcome-oriented statement — standard or precision format]

**Level**: [Root / Branch / Leaf]

**Parent opportunity**: [Reference to parent, if this is a branch or leaf — "None" if root]

**Derived from**: Finding [X], Finding [Y]

**Affected personas**: [Which personas + how specifically]

**Current state**: [How users handle this today — workarounds, pain, avoidance]

**Desired state**: [What success looks like from the user's perspective]

**Evidence strength**: [High/Medium/Low] — [Basis]

**Priority**: [From the prioritization framework applied to findings]

**Sub-opportunities** (if this is not a leaf):
- [N.1]: [Sub-opportunity statement]
- [N.2]: [Sub-opportunity statement]

**Dependencies**: [Does this opportunity depend on or enable other opportunities?]
```

### Opportunity Tree Summary

After listing all opportunities, provide a tree visualization:

```markdown
## Opportunity Tree

[Outcome / Root Opportunity]
├── [Branch Opportunity 1]
│   ├── [Leaf 1.1] ← actionable
│   └── [Leaf 1.2] ← actionable
├── [Branch Opportunity 2]
│   ├── [Leaf 2.1] ← actionable
│   └── [Leaf 2.2] ← actionable
└── [Leaf Opportunity 3] ← actionable
```

---

## Task 5: Develop Recommendations (`recommendations.md`)

Tie specific actions to findings and opportunities:

```markdown
# Recommendations

## Recommendation [N]: [Specific, actionable statement]

**Addresses**: Opportunity [X] / Finding [Y]

**What to do**: [Concrete action — specific enough to start on]

**Expected impact**: [What changes for users if this is done]

**Evidence basis**: [Brief reference to supporting data]

**Priority**: [From framework]

**Open considerations**: [Unknowns, risks, or tradeoffs to be aware of]
```

---

## Task 6: Document Open Questions (`open-questions.md`)

Honest accounting of what the research did NOT answer:

```markdown
# Open Questions & Future Research

## Unresolved Questions
- [Question]: [What we know so far + what's still unclear + why it matters]

## Suggested Follow-Up Research
- [Method]: [What question it would answer + why this method is appropriate]

## Limitations of This Analysis
- [Limitation]: [How it constrains what we can claim]
```

---

## Task 7: Write Phase 4 Summary (`phase4-summary.md`)

```markdown
# Phase 4 Summary: Synthesis Complete

## Personas: [Count] [Type] personas
[1-line description of each]

## Top Findings (ranked by priority):
1. [Finding] — [Prevalence] — [Confidence]
2. ...

## Opportunity Areas: [Count]
[1-line each]

## Recommendations: [Count]
[1-line each]

## Evidence Strength
[Overall assessment: where is evidence strong vs. thin?]

## Key Limitations
[Top 2-3 limitations the report must acknowledge]

## Ready for Report Compilation
[Any notes for Phase 5 — emphasis, audience considerations, structural suggestions]
```

## Quality Gate

Before writing your outputs, verify:

- [ ] **Cognitive Empathy**: Do personas read as real people with genuine perspectives, not cardboard cutouts? Would a participant recognize themselves?
- [ ] **Groundedness**: Every finding is traceable to specific codes, themes, and quotes. No finding is pure analyst invention.
- [ ] **Minimum evidence**: Every finding appears in at least 2 interviews. Remove any that don't meet this threshold or demote to "open questions."
- [ ] **Palpability**: Every finding has at least 1 luminous exemplar quote and 2+ echo quotes. Evidence is concrete, not abstract.
- [ ] **Heterogeneity**: Findings acknowledge variation and negative cases, not just the dominant pattern. Personas represent distinct groups, not slight variations on the same type.
- [ ] **Reflexivity**: Prioritization framework choice is justified. Confidence levels are honest. Limitations are real, not pro-forma.
- [ ] **Outcome orientation**: Opportunities describe desired outcomes, not just problems. Recommendations are specific enough to act on.

---

## Parallel Extensibility Slot

_The `parallel/` directory is reserved for future analysis signals embedded in this phase. Currently empty. Examples of what could be added here:_

- _`journey-map.md` — Synthesized journey stages across personas with emotional arcs_
- _`competitive-gaps.md` — How findings compare to competitor approaches_
- _`severity-matrix.md` — Severity ratings per finding using a standardized scale_
