# Phase 2: Coding

You are a sub-agent executing Phase 2 of a qualitative research synthesis. Your goal is to systematically code interview data into organized, analyzable categories — building the codebook iteratively so each batch inherits and extends the work of the previous batch.

## Context

You will receive:
- A batch of ~5 interview files
- The **current codebook** (`analysis/phase2-coding/codebook.md`):
  - First batch: this may be an initial "start list" from deductive coding, or empty for inductive
  - Later batches: the codebook written by the previous batch agent
- `analysis/config.md` — coding depth (Full Codebook / Lightweight Tags), approach (Deductive / Inductive / Hybrid)
- `analysis/phase1-familiarization/phase1-summary.md` — key observations from immersion
- Your batch number and total batch count

## Understanding the Codebook Structure

### If Full Codebook (two-level hierarchy):

```markdown
## Category: [Category Name]

### Code: [Code Name]

**Definition**: [Clear operational definition — what this code captures]

**Inclusion criteria**: [When to apply this code]

**Exclusion criteria**: [When NOT to apply — distinctions from similar codes]

**Typical exemplar**:
> "[Quote that clearly fits this code]" — [Participant ID]

**Atypical exemplar** (boundary case):
> "[Quote that fits but in an unexpected way]" — [Participant ID]

**Frequency**: Appears in [X] of [Y] interviews coded so far

**Subcodes** (if warranted):
- [Subcode A]: [brief definition]
- [Subcode B]: [brief definition]

**Analytic notes**: [Observations about variation within this code, connections to other codes, puzzles]
```

### If Lightweight Tags:

```markdown
## Tag: [Tag Name]

**Description**: [What this tag covers — 1-2 sentences]

**Representative quote**:
> "[Quote]" — [Participant ID]

**Frequency**: [X] of [Y] interviews
```

## Your Tasks

### 1. Read and Internalize the Current Codebook

Before coding any interviews, read the entire current codebook carefully. Understand:
- What codes already exist and what they mean
- The boundaries between similar codes
- Where the codebook may have gaps based on Phase 1 observations

### 2. Code Each Interview in Your Batch

For each interview, work through the material systematically:

**Apply existing codes** where they fit. For each coded excerpt, record:
- The code applied
- The verbatim excerpt
- Brief context note
- Participant ID

**Watch for new phenomena** not captured by existing codes:
- In-vivo codes: Participants' own distinctive language that captures something the existing codebook misses
- Process codes: Actions and sequences (-ing words: "negotiating," "escalating," "abandoning")
- Emotion codes: Affective responses not yet captured
- Meaning codes: How participants interpret or make sense of events

**Track variation within existing codes**: If an existing code applies but the manifestation is different from what's been seen before, note it in the code's analytic notes.

### 3. Update the Codebook

After coding your batch, update `analysis/phase2-coding/codebook.md`:

**Adding new codes**:
- Only add a code if it captures something genuinely distinct from existing codes
- Provide full definition, inclusion/exclusion criteria, and at least one exemplar
- Place it in the appropriate category, or create a new category if needed

**Splitting codes**:
- If an existing code has become too broad (covers meaningfully different phenomena), split it
- Preserve the original excerpts under the appropriate new code

**Merging codes**:
- If two codes overlap significantly and the distinction isn't analytically useful, merge them
- Document the merge in the changelog

**Refining definitions**:
- If coding revealed that a definition was ambiguous, sharpen it
- Update inclusion/exclusion criteria based on boundary cases encountered

**Updating frequency counts**:
- Update the frequency for every code you applied or encountered

### 4. Write Coded Excerpts

For each code you applied, write excerpts to `analysis/phase2-coding/coded-excerpts/{category}--{code}.md`:

```markdown
# Category: [Category Name] > Code: [Code Name]

## [Participant ID]
> "[Excerpt 1]"
> — Context: [What was being discussed]

> "[Excerpt 2]"
> — Context: [What was being discussed]

## [Participant ID]
> "[Excerpt]"
> — Context: [What was being discussed]
```

If the file already exists (from a previous batch), **append** your new excerpts — do not overwrite.

### 5. Update the Changelog

Append to `analysis/phase2-coding/codebook-changelog.md`:

```markdown
## Batch {n} Changes

**Interviews coded**: [List of participant IDs]

**New codes added**:
- [Category] > [Code Name]: [Why this was needed — what it captures that existing codes didn't]

**Codes split**:
- [Old Code] → [New Code A] + [New Code B]: [Why the split was necessary]

**Codes merged**:
- [Code A] + [Code B] → [Merged Code]: [Why the distinction wasn't useful]

**Definitions refined**:
- [Code]: [What changed and why]

**Notable observations**:
- [Anything interesting about this batch — new patterns, surprising applications of existing codes]
```

## Coding Strategies by Approach

### Deductive Start (from config)
- Begin with the start list codes derived from the interview guide, framework (JTBD, heuristics), or literature
- Apply these codes first, then look for what they miss
- New inductive codes should be clearly marked as emergent in the changelog

### Inductive (from config)
- No start list — let codes emerge entirely from the data
- Use in-vivo coding (participants' language) as the primary strategy
- Build categories bottom-up as patterns form across interviews

### Hybrid (from config — most common)
- Start with deductive codes, but actively look for what they miss
- In-vivo codes get first-class treatment — they may become more important than deductive codes
- The start list is a scaffold, not a cage

## Quality Gate

Before writing your outputs, verify:

- [ ] **Consistency**: Could another coder read your codebook and apply the same codes to the same passages? If any definition is ambiguous, sharpen it.
- [ ] **Groundedness**: Every code has at least one concrete exemplar quote. No code exists as pure abstraction.
- [ ] **Heterogeneity**: Within each code, have you noted variation in how the phenomenon manifests? If a code only has one "flavor," it may be too narrow — or you may be missing variation.
- [ ] **No orphan codes**: Every code is assigned to a category. No floating codes.
- [ ] **Reflexivity**: In your changelog, have you explained WHY you made each change? Future agents need to understand your reasoning.

## For the Final Batch Agent

If you are the **last batch** (batch number == total batch count):

After completing your normal tasks, also write `analysis/phase2-coding/phase2-summary.md`:

```markdown
# Phase 2 Summary: Coding Complete

**Interviews coded**: [Total count]
**Codebook size**: [Number of categories] categories, [number of codes] codes

## Codebook Overview
[List all categories and their codes — just names, not full definitions]

## Most Prevalent Codes (top 10)
- [Code]: [Frequency] — [One-line description]

## Most Analytically Interesting Codes
- [Code]: [Why this is interesting — unexpected variation, connects to research questions, challenges assumptions]

## Coding Approach Taken
[Deductive / Inductive / Hybrid — and how the balance played out in practice]

## How the Codebook Evolved
[Brief narrative: what the start list looked like, what emerged, what was the biggest surprise]

## Patterns Visible Through Coding
[What patterns are becoming clear? What themes might form in Phase 3?]

## Recommended Focus for Phase 3
[Which codes should be grouped? Where are the strongest theme candidates? What contradictions need resolution?]
```

---

## Parallel Extensibility Slot

_The `parallel/` directory is reserved for future analysis signals embedded in this phase. Currently empty. Examples of what could be added here:_

- _`in-vivo-lexicon.md` — Comprehensive collection of participants' distinctive language, metaphors, and framing devices_
- _`interaction-patterns.md` — Coded interaction sequences for conversational or usability analysis_
