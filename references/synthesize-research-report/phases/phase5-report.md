# Phase 5: Report Compilation

You are a sub-agent executing Phase 5 of a qualitative research synthesis. Your goal is to compile a comprehensive, polished markdown research report that integrates all prior phase outputs into a single, reader-friendly document. This is what the stakeholders will read.

## Guiding Philosophy: Pearls, Not Oysters

The prior phases opened all the oysters. This phase presents only the pearls. The report is **explanatory** (here is what matters and why), not **exploratory** (here is everything we looked at). Raw data, full codebooks, and detailed methodology belong in appendices — the main body is a structured experience of knowledge that enables decision-makers to act.

**The report is a story** with three acts:
1. **Beginning**: Why we did this research and how (Sections 1-2)
2. **Middle**: What we found — the evidence and what it means (Sections 3-5)
3. **End**: What to do about it and what we still don't know (Sections 6-8)

**Target length**: The main body (excluding appendices) should aim for **5-10 pages** of content. Longer reports are rarely read in full. Be ruthless about what earns space in the main body vs. what belongs in an appendix.

## Context

You will receive:
- `analysis/config.md` — configuration (research goal, audience, coding approach, persona type, prioritization framework)
- `analysis/phase1-familiarization/consolidated-observations.md`
- `analysis/phase2-coding/codebook.md`
- `analysis/phase3-themes/themes.md`
- `analysis/phase3-themes/frequency-matrix.md`
- `analysis/phase3-themes/pattern-analysis.md`
- `analysis/phase4-synthesis/findings.md`
- `analysis/phase4-synthesis/evidence-bank.md`
- `analysis/phase4-synthesis/personas/persona-{n}-{name}.md` (all persona files)
- `analysis/phase4-synthesis/opportunities.md`
- `analysis/phase4-synthesis/recommendations.md`
- `analysis/phase4-synthesis/open-questions.md`
- `analysis/phase4-synthesis/phase4-summary.md`
- All `parallel/` directory contents from every phase (if any exist)

## Your Output

Write `analysis/final-report.md`.

---

## Report Structure

The report follows this structure. Every section is required unless marked optional. Adapt depth and tone to the target audience specified in `config.md`.

```markdown
# [Research Title]: [Methodology Type]

**Date**: [Date of report compilation]
**Authors**: [Researchers who conducted and analyzed the study]
**Stakeholders**: [Key stakeholders who commissioned or will act on this research — listing them builds organizational buy-in]
**Research objective**: [From config — the core question(s)]
**Methodology**: [Interview count, participant types, data types]
**Analysis approach**: [Coding depth + approach from config]

---

## Table of Contents

[Auto-generate from section headers]

---

## Executive Summary

[Maximum 1 page. This is the "if you read nothing else" section. Follow the inverted pyramid — most critical message first.]

**What we studied**: [1-2 sentences on research scope and method]

**What's working** (top 3 positive findings):
1. [Positive finding — what users value, what succeeds]
2. [Positive finding]
3. [Positive finding]

**What needs attention** (top 3 high-severity opportunities):
1. [High-severity opportunity — what's broken or underserved]
2. [High-severity opportunity]
3. [High-severity opportunity]

**Who we found**: [1-2 sentences on the personas identified]

**What to do about it**: [3-5 bullet points — the top recommendations]

**Key limitations**: [1-2 sentences — what this research cannot tell us]

---

## 1. Research Overview

### 1.1 Background & Objectives
[Why this research was conducted. What questions it aimed to answer. What decisions it will inform.]

### 1.2 Methodology
[Keep this extremely brief in the main body — under 100 words. Full details go in Appendix B.]
- **Participants**: [Count, recruitment method, key segmentation]
- **Data collection**: [Interview type, duration range, mode]
- **Data types**: [Transcripts, notes, summaries — counts]
- **Analysis method**: [Coding approach, thematic analysis — one line]
- **Prioritization framework**: [Which framework and why — one line]

### 1.3 Participant Overview
[Table or summary of participant characteristics relevant to the research — roles, experience levels, segments, etc. No PII.]

---

## 2. Personas

[Brief introduction: how personas were derived, what type, how many]

### 2.1 Persona: [Name]

[Full persona profile — adapted from Phase 4 persona files. Include:]
- Who they are (context, characteristics)
- Their key behaviors/attitudes/goals (depending on persona type)
- Top needs and pain points (with brief evidence)
- 1-2 representative quotes
- How they relate to the key themes

[Repeat for each persona]

### 2.N Persona Comparison
[Brief comparison table showing how personas differ on key dimensions]

---

## 3. Key Findings

[Brief introduction: how many findings, how they were prioritized, evidence standards.

**Structure choice**: Order findings either by priority rank (default) or by research question. If the research had distinct questions, consider using the original research questions as section headers — this ensures you've answered what you set out to learn and makes the report navigable for stakeholders who care about specific questions.]

### 3.1 Finding: [Finding statement]

**Tier**: [Must Know / Should Know / Nice to Know] | **Priority**: [Rank] | **Prevalence**: [X]% of participants | **Confidence**: [High/Medium/Low]

[2-3 paragraph narrative explaining this finding. Follow the show-don't-tell principle:]

**Opening**: Lead with the insight — state what you found clearly.

**Evidence**: Show it with quotes. Use the anchor-echo pattern:
- **Anchor**: One extended quote (3-6 sentences) from a single participant, set up with context and followed by brief interpretation. Let the reader hear the participant's voice and reasoning.
- **Echoes**: 2-3 shorter quotes from other participants showing the pattern repeats. Brief attribution for each.

**Variation**: How does this finding manifest differently across personas or subgroups? Address negative cases — participants who DON'T show this pattern and why.

**Prevalence statement**: Ground the finding quantitatively — "[X] of [Y] participants described this pattern" or "This was most pronounced among [persona/segment]."

[Repeat for each finding, ordered by priority]

---

## 4. Themes & Patterns

### 4.1 Theme Overview
[Table summarizing all themes: name, definition (1 sentence), prevalence, key findings it supports]

### 4.2 Cross-Cutting Patterns
[The 2-4 most significant patterns that span multiple themes — from Phase 3 pattern analysis. These show how themes interact, reinforce, or contradict each other.]

### 4.3 Contradictions & Tensions
[Where the data tells conflicting stories. Frame these as analytically interesting, not as failures. Explain possible reasons for the tension.]

---

## 5. Codebook Summary

[Not the full codebook — that's in `phase2-coding/codebook.md`. This is a structured overview.]

### 5.1 Coding Approach
[Deductive start list / inductive emergence / hybrid — brief narrative of how the codebook developed]

### 5.2 Code Inventory
[Table: Category | Code | Definition (1 line) | Prevalence]

### 5.3 Codebook Evolution
[Brief narrative: how the codebook changed during analysis — what was added, merged, split. What does this evolution tell us about the data?]

**Full codebook**: See `analysis/phase2-coding/codebook.md`

---

## 6. Opportunity Areas

[Brief introduction: how opportunities were derived from findings. Frame all opportunities as customer needs ("I need to..."), pain points, or desires — never as feature requests or solutions.]

### 6.1 Opportunity Tree
[Include the opportunity tree visualization from Phase 4. This gives readers the hierarchical structure at a glance — root outcomes, branch opportunities, and actionable leaf-nodes.]

```
[Outcome / Root Opportunity]
├── [Branch 1]
│   ├── [Leaf 1.1] ← actionable
│   └── [Leaf 1.2] ← actionable
└── ...
```

### 6.2 Opportunity: [Outcome-oriented statement]

**Level**: [Root / Branch / Leaf] | **Priority**: [Rank] | **Derived from**: Finding [X], [Y]

**Current state**: [How users handle this today]
**Desired state**: [What success looks like]
**Affected personas**: [Which personas + how]
**Evidence strength**: [High/Medium/Low]

[Repeat for each opportunity. Highlight leaf-node opportunities — the smallest solvable problems — as the clearest path forward.]

### 6.N Opportunity Prioritization
[Visual or table showing opportunities ranked by the selected framework]

---

## 7. Recommendations

[Brief introduction: these are actionable next steps tied to specific findings and opportunities]

### 7.1 [Recommendation statement]
- **Addresses**: [Opportunity/Finding reference]
- **Expected impact**: [What changes for users]
- **Priority**: [Rank]
- **Considerations**: [Risks, tradeoffs, unknowns]

**Collaboration placeholders** (turn the report into a live negotiation tool):
- **PM**: [What product decisions or prioritization this requires]
- **Eng**: [What technical investigation, feasibility, or implementation this requires]
- **Design**: [What design exploration, prototyping, or validation this requires]

[Repeat for each recommendation]

---

## 8. Limitations & Open Questions

### 8.1 Research Limitations
[Honest accounting — sample, method, analysis constraints. Be specific, not generic.]

### 8.2 Open Questions
[What the research did not answer. For each: what we know so far, what's still unclear, and why it matters.]

### 8.3 Suggested Follow-Up Research
[Specific methods + questions they would answer. Show the user where to go next.]

---

## Appendix A: Evidence Highlights

[Curated collection of the strongest quotes organized by finding — from the evidence bank. This gives readers direct access to participant voices beyond what's in the main text.]

## Appendix B: Methodology Details

[Extended methodology notes — this is where the "oysters" go so the main body stays lean:]
- Full interview guide / discussion guide topics
- Sampling approach and recruitment details
- Participant demographics table (detailed — the main body has only a summary)
- Analysis timeline
- Quality assurance measures applied
- Codebook evolution narrative (from Phase 2)

## Appendix C: Full Codebook Reference

[Complete codebook from `analysis/phase2-coding/codebook.md` — categories, codes, definitions, exemplars. Reference for teams who want to apply the codes to future research.]
```

---

## Writing Principles

### The "So What" Test
Every section, every paragraph, every finding must clearly state **why this matters** for the product's success or the research objectives. If a reader could ask "so what?" and not find the answer in the next sentence, you've failed to connect insight to implication.

### Inverted Pyramid Within Sections
Within each section, put the most critical message first. A reader who stops after the first sentence of any section should still get the most important point. Supporting detail follows, not precedes.

### Report Neutrally
Present findings objectively. Do not attempt to "correct" the user's mental model or advocate for a particular solution. The report's trustworthiness depends on neutrality — let the evidence speak, and let stakeholders draw their own conclusions about implementation.

### Lead with Insight, Not Process
```
BAD:  "After careful analysis of all 52 transcripts, we identified several patterns..."
GOOD: "Users consistently develop personal workarounds before seeking official support —
       a pattern we call 'silent struggle' that appeared in 73% of interviews."
```

### Show, Don't Tell (Anchor-Echo Pattern)
```
BAD:  "Participants found onboarding frustrating."

GOOD: "The onboarding experience left users feeling abandoned. As one project manager
       described: 'I spent three hours clicking around with no idea if I was even
       setting things up right. There was no feedback, no progress bar, nothing
       telling me I was on the right track. I almost gave up and went back to
       spreadsheets.' (P14, enterprise PM, 3 months in)

       This wasn't isolated. 'I Googled more than I used the product that first
       week' (P07). 'My onboarding was basically asking the person who left the
       role before me' (P23). Thirty-one of forty-two participants described
       significant self-directed troubleshooting during their first two weeks."
```

### Ground Claims Quantitatively
```
BAD:  "Many users experienced this."
GOOD: "31 of 42 participants (74%) described this pattern, with the highest
       concentration among [persona name] (12 of 14, 86%)."
```

### Highlight Buried Treasure
The most brilliant insight should NOT be buried mid-paragraph. Move it to the beginning of its section. Bold the headline statement. Make it scannable.

### Make Transitions Carry Analytical Weight
```
BAD:  "Another finding was about support." (topic shift, no analysis)
GOOD: "If silent struggle describes how users cope alone, the next finding reveals
       what happens when they finally reach out — and why many wish they hadn't."
       (connected, builds tension)
```

### Acknowledge Complexity Without Drowning In It
Address negative cases and variation, but don't let caveats overwhelm findings. Pattern first, nuance second.

### Formatting for Scannability
- **Bold key assertions** — the headline insight of each finding should be bold so skimmers catch it.
- *Italicize theme names and code names* on first mention — this signals to readers that these are defined analytical constructs, not casual language.
- **Subheadings are cognitive signposts** — use them liberally. A reader scanning only headers should get the story arc.
- Keep paragraphs short (3-5 sentences max). Dense walls of text lose readers.

---

## Audience Adaptation

Adjust depth and emphasis based on the target audience in `config.md`:

| Audience | Executive Summary | Findings | Codebook | Methodology |
|----------|-------------------|----------|----------|-------------|
| Product team | Concise, action-oriented | Full depth + recommendations | Summary only | Brief |
| Executives | Very concise, strategic | Top 3-5 only, high-level | Skip | 1 paragraph |
| Design team | Concise | Full depth + personas emphasized | Summary | Brief |
| Academic | Abstract-style | Full depth + theoretical framing | Full detail | Extended |
| Mixed/General | Balanced | Full depth | Summary | Moderate |

---

## Quality Gate

Before writing the final report, verify:

- [ ] **Completeness**: Every section in the template is populated. No placeholder text remains.
- [ ] **Evidence standards**: Every finding has at least 1 anchor quote and 2 echo quotes. No finding relies on a single interview.
- [ ] **Traceability**: A reader could follow from recommendation → opportunity → finding → theme → code → quote. The chain is unbroken.
- [ ] **Palpability**: The report contains enough verbatim quotes that readers hear participant voices, not just analyst summaries.
- [ ] **Cognitive empathy**: Participants come across as real people with genuine perspectives, not data points.
- [ ] **Quantitative grounding**: Every prevalence claim has a specific fraction (X of Y), not vague quantifiers ("many," "some," "several").
- [ ] **Honest limitations**: Limitations section is specific and substantive, not pro-forma boilerplate.
- [ ] **Scannable structure**: A reader skimming headers, bold text, and first sentences of paragraphs gets the key story.
- [ ] **No orphan recommendations**: Every recommendation traces to a specific finding and opportunity.
- [ ] **"So what" test**: Every section and finding clearly states why it matters. No insight is left without implication.
- [ ] **Neutrality**: Findings are reported objectively. The report does not advocate for specific solutions or correct the user's mental model.
- [ ] **Formatting**: Key assertions are bold. Theme/code names are italicized on first mention. Subheadings break up every section. No paragraph exceeds 5 sentences.
- [ ] **Length discipline**: Main body (excluding appendices) is 5-10 pages. If longer, move supporting detail to appendices.
- [ ] **Audience fit**: Depth, tone, and emphasis match the target audience from config.

---

## Parallel Extensibility Slot

_If any `parallel/` files exist in prior phases, incorporate them into the report:_

- _Sentiment analysis → Add "Emotional Landscape" section after Themes & Patterns_
- _Journey mapping → Add "User Journey" section after Personas_
- _Severity ratings → Integrate into Findings priority scoring_
- _Competitive gaps → Add "Competitive Context" section before Recommendations_

_Check each phase's `parallel/` directory. If files exist, read them and weave their insights into the appropriate report section._
