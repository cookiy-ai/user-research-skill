---
name: synthesize-research-report
description: Synthesize a comprehensive qualitative research report from raw interview materials (transcripts, notes, summaries). Handles 50+ interviews via batched sub-agents, builds codebooks iteratively, constructs data-driven personas, and produces prioritized findings with outcome-oriented opportunities. Use when you have completed qualitative interviews and need to turn raw data into a structured, evidence-backed research report.
argument-hint: "<research topic, question, or path to research materials>"
---

# Synthesize Research Report

Transform raw qualitative interview data into a comprehensive, evidence-backed research report through a multi-phase autonomous pipeline.

## Usage

```
/synthesize-research-report $ARGUMENTS
```

## Prerequisites — Gather Before Starting

Before any analysis begins, you MUST have three things. If any are missing, ask the user:

### 1. Research Overview & Objectives
Ask: *"What is the research objective? What questions were you trying to answer?"*
You need:
- The core research question(s)
- What decisions this research will inform
- The target audience for the final report (product team, executives, design, academic)
- The research goal type — this determines the prioritization framework later:

| Research Goal | Prioritization Framework |
|--------------|------------------------|
| Tactical usability fixes | Criticality Scoring (Severity x Frequency) |
| Market gaps & innovation | Opportunity Scoring (Importance vs. Satisfaction) |
| MVP / sprint scoping | Impact/Effort Matrix |
| High-risk discovery | Hypothesis Canvas (Risk vs. Perceived Value) |
| Product strategy | Opportunity Solution Tree |

### 2. Interview Guide / Discussion Guide
Ask: *"Do you have the interview guide or discussion guide used? Please provide it or point me to it."*
This is essential for:
- Generating deductive "start list" codes
- Understanding what topics were probed
- Assessing coverage across interviews

### 3. Raw Interview Materials
Ask: *"Where are the interview transcripts, notes, or summaries located?"*
Supported formats:
- **Raw transcripts** (full verbatim or cleaned)
- **Interview notes** (researcher's contemporaneous notes)
- **Interview summaries** (post-interview write-ups)

Confirm the count and location of materials.

---

## Determining Analysis Configuration

Based on the research context, make two key decisions and record them in `analysis/config.md`:

### Coding Depth: Full Codebook vs. Lightweight Tags

| Condition | Use Full Codebook | Use Lightweight Tags |
|-----------|-------------------|---------------------|
| Theory-building research | Yes | |
| Team-based analysis / multiple coders | Yes | |
| Regulatory or compliance context | Yes | |
| Exploratory / rapid discovery | | Yes |
| Stakeholders want to read raw data | | Yes |
| Non-interview data (tickets, surveys) | | Yes |

**Full Codebook**: Two-level hierarchy (Category > Code), operational definitions, inclusion/exclusion criteria, typical and atypical exemplars.

**Lightweight Tags**: Descriptive topic labels with brief definitions and representative quotes.

### Coding Approach: Deductive, Inductive, or Hybrid

| Condition | Approach |
|-----------|----------|
| Well-understood domain + established framework (JTBD, heuristics) | Deductive start |
| Unfamiliar domain, understudied population, complex social processes | Inductive |
| Most product/UX research | Hybrid (deductive start + inductive growth) |

For **Hybrid** (recommended default):
1. Generate a "start list" of 12-40 provisional codes from the interview guide, research objectives, or a framework
2. Remain open to emergent in-vivo codes during transcript review
3. Formalize emergent codes into the codebook structure during Phase 3

### Persona Type Selection

Auto-determine based on research context:

| Persona Type | Best For | Key Variable |
|-------------|----------|-------------|
| Proto-Personas | Limited data, early alignment | Team assumptions |
| Behavioral | Complex workflows, B2B tools | Usage patterns & skills |
| Attitudinal | Brand, lifestyle, emotional design | Mindset & values |
| Goal-Based | Interface design, JTBD | Intended outcomes |
| Narrative | Communicating to non-researchers | Day-in-the-life stories |
| Ecosystem | B2B with multiple stakeholders | Organizational roles |
| System/VUI | Chatbot or voice interface design | Personality traits |

Record the selected type and rationale in `analysis/config.md`.

---

## The Five Phases

The pipeline has exactly five fixed phases. Each runs in its own sub-agent(s). Phases are sequential — each reads the previous phase's summary. Future analysis signals (sentiment, journey maps, severity ratings, etc.) are added by embedding new instructions into the relevant phase file and writing outputs to that phase's `parallel/` directory.

| Phase | Name | Sub-Agent Strategy | Purpose |
|-------|------|--------------------|---------|
| 1 | Familiarization | Parallel batches (~15 interviews each) | Deep reading, memos, initial observations |
| 2 | Coding | Sequential batches (~5 interviews each) | Iterative codebook building, coded excerpts |
| 3 | Theme Development | Single agent | Group codes into themes, pattern analysis |
| 4 | Synthesis & Interpretation | Single agent (may spawn sub-agents for large persona clustering) | Findings, personas, opportunities, evidence |
| 5 | Report Compilation | Single agent | Final comprehensive markdown report |

### Phase Instruction Files

Each phase has a detailed instruction file in `phases/`:

| File | Loaded By |
|------|-----------|
| `phases/phase1-familiarization.md` | Each Phase 1 batch agent |
| `phases/phase2-coding.md` | Each Phase 2 sequential agent |
| `phases/phase3-themes.md` | Phase 3 agent |
| `phases/phase4-synthesis.md` | Phase 4 agent |
| `phases/phase5-report.md` | Phase 5 agent |

---

## Output Directory Structure

```
analysis/
├── config.md                              # Configuration: coding depth, approach, persona type, prioritization framework
│
├── phase1-familiarization/
│   ├── batch-{n}-memos.md                 # Interview memos (~15 per file)
│   ├── consolidated-observations.md       # Merged observations across all batches
│   ├── parallel/                          # [Extensibility] e.g., sentiment-extraction.md, journey-raw-data.md
│   └── phase1-summary.md                  # Handoff to Phase 2
│
├── phase2-coding/
│   ├── codebook.md                        # Final codebook
│   ├── codebook-changelog.md              # Evolution log: what was added/merged/split per iteration
│   ├── coded-excerpts/
│   │   └── {category}--{code}.md          # All excerpts for a given code, grouped by participant
│   ├── parallel/                          # [Extensibility] e.g., in-vivo-lexicon.md
│   └── phase2-summary.md                  # Handoff to Phase 3
│
├── phase3-themes/
│   ├── themes.md                          # Theme definitions (with core category and codeweaving)
│   ├── frequency-matrix.md                # Code/theme prevalence per participant
│   ├── co-occurrence.md                   # Which codes/themes cluster together
│   ├── code-map.md                        # Abstraction progression: codes → focused → categories → themes
│   ├── pattern-analysis.md                # Cross-cutting patterns, contradictions, outliers, narrative threads
│   ├── parallel/                          # [Extensibility] e.g., severity-ratings.md, sentiment-patterns.md
│   └── phase3-summary.md                  # Handoff to Phase 4
│
├── phase4-synthesis/
│   ├── findings.md                        # Prioritized findings with evidence (min 2-interview threshold)
│   ├── prioritization-rationale.md        # Which framework was used and why
│   ├── evidence-bank.md                   # Extended quotes, luminous exemplars, anchor/echo candidates
│   ├── personas/
│   │   ├── persona-type-rationale.md      # Selection logic and clustering method
│   │   ├── clustering-analysis.md         # How participants map to personas
│   │   └── persona-{n}-{name}.md         # Individual persona profiles
│   ├── opportunities.md                   # Outcome-oriented opportunity statements
│   ├── recommendations.md                 # Actionable recommendations tied to findings
│   ├── open-questions.md                  # Gaps, unresolved puzzles, future research
│   ├── parallel/                          # [Extensibility] e.g., journey-map.md, competitive-gaps.md
│   └── phase4-summary.md                  # Handoff to Phase 5
│
└── final-report.md                        # Comprehensive synthesis report
```

---

## Sub-Agent Orchestration

### Phase 1: Parallel Batch Agents

```
N = ceil(total_interviews / 15)

Spawn N agents IN PARALLEL. Each receives:
  - phases/phase1-familiarization.md (instructions)
  - Its batch of ~15 interview file paths
  - analysis/config.md
  - The research overview and interview guide

Each agent writes: analysis/phase1-familiarization/batch-{n}-memos.md

After ALL batch agents complete:
  Spawn 1 consolidation agent that:
    - Reads all batch-{n}-memos.md files
    - Writes consolidated-observations.md
    - Writes phase1-summary.md
```

### Phase 2: Sequential Batch Agents

```
M = ceil(total_interviews / 5)

For i = 1 to M:
  Spawn 1 agent that receives:
    - phases/phase2-coding.md (instructions)
    - Its batch of ~5 interview file paths
    - The CURRENT codebook:
        - If i == 1: the initial "start list" (from config) or empty codebook
        - If i > 1: analysis/phase2-coding/codebook.md (written by previous agent)
    - analysis/config.md
    - analysis/phase1-familiarization/phase1-summary.md

  Agent writes:
    - Updated analysis/phase2-coding/codebook.md (overwrite)
    - Appends to analysis/phase2-coding/codebook-changelog.md
    - Creates/updates coded-excerpts/{category}--{code}.md files

After all sequential agents complete:
  Spawn 1 agent to write phase2-summary.md
```

### Phases 3-5: Single Agents

```
Each phase spawns 1 agent that receives:
  - The phase instruction file
  - The previous phase's summary file
  - Paths to specific prior-phase artifacts it needs (listed in the phase instruction file)
  - analysis/config.md

Agent writes all outputs for its phase directory + phase{N}-summary.md
```

---

## Extensibility Model

Phases are fixed. New analysis signals are added by:

1. **Adding instructions** to the relevant phase's `.md` file (e.g., add a "Sentiment Extraction" section to `phase1-familiarization.md`)
2. **Writing outputs** to that phase's `parallel/` subdirectory
3. **Adding a section** to `phase5-report.md` to incorporate the new signal into the final report

### Example: Adding Sentiment Analysis

| Where | What to Add |
|-------|------------|
| `phases/phase1-familiarization.md` | Section: "For each interview, rate overall emotional valence and flag high-intensity moments" → writes to `parallel/sentiment-extraction.md` |
| `phases/phase3-themes.md` | Section: "Analyze sentiment patterns across themes" → writes to `parallel/sentiment-patterns.md` |
| `phases/phase5-report.md` | Section: "Include Emotional Landscape section in final report" |

### Example: Adding Journey Mapping

| Where | What to Add |
|-------|------------|
| `phases/phase1-familiarization.md` | Section: "Extract temporal touchpoints and emotional states" → writes to `parallel/journey-raw-data.md` |
| `phases/phase4-synthesis.md` | Section: "Synthesize journey stages across personas" → writes to `parallel/journey-map.md` |
| `phases/phase5-report.md` | Section: "Include User Journey Map section in final report" |

---

## Quality Assurance (Embedded)

Quality is NOT a separate phase. Every phase instruction file includes a **Quality Gate** section that checks:

| Dimension | What It Means | Checked In |
|-----------|---------------|------------|
| Cognitive Empathy | Understand participants as they understand themselves | Phase 1, 4 |
| Heterogeneity | Capture variation, not just the dominant pattern | Phase 1, 2, 3 |
| Palpability | Evidence is concrete and specific, not abstract | Phase 2, 4 |
| Groundedness | Claims traceable to specific data, min 2 interviews | Phase 3, 4 |
| Reflexivity | Analytic choices made explicit | Phase 2, 3, 4 |

If a quality gate fails, the agent must self-correct before writing outputs.

---

## Running the Skill

After gathering all prerequisites:

1. Write `analysis/config.md` with all configuration decisions
2. Execute Phase 1 → 2 → 3 → 4 → 5 sequentially (spawning sub-agents per the strategies above)
3. After Phase 5, present the user with:
   - Path to `analysis/final-report.md`
   - Top 5-8 key findings (one sentence each)
   - Number of personas and their names
   - Number of opportunity areas
   - Any caveats or limitations noted during analysis
   - Paths to key artifacts: codebook, personas, evidence bank
