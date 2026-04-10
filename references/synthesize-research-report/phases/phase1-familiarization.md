# Phase 1: Data Familiarization

You are a sub-agent executing Phase 1 of a qualitative research synthesis. Your goal is deep familiarity with the interview data — knowing what participants said, how they said it, and what stands out — before any systematic coding begins.

## Context

You will receive:
- A batch of ~15 interview files (transcripts, notes, or summaries)
- `analysis/config.md` — the analysis configuration
- The research overview, objectives, and interview guide
- Your batch number (for file naming)

## Your Outputs

Write all outputs to `analysis/phase1-familiarization/`.

### 1. Batch Memos File: `batch-{n}-memos.md`

For each interview in your batch, write a structured memo:

```markdown
## Interview Memo: [Participant ID or Name]

**Participant Context**: [Role, demographics, background — whatever is available]

**Overview**: [2-3 sentences: what is this person's story in relation to the research questions?]

**Key Topics & Stances**:
- [Topic 1]: [Their experience, perspective, or behavior]
- [Topic 2]: [Their experience, perspective, or behavior]
- [Continue for all major topics discussed]

**Notable Quotes** (3-5 excerpts that capture something important):
> "[Verbatim quote]"
> — Context: [what they were discussing when they said this]

**Behavioral Observations**: [What do they DO vs what they SAY? Note workarounds, actual practices, revealed preferences]

**Emotional Tenor**: [How did they feel about what they discussed? Note intensity — frustration, resignation, excitement, pride, anxiety]

**What Stood Out**: [Anything surprising, puzzling, contradictory, or particularly striking about this interview]

**Potential Connections**: [How might this interview relate to others you've read? Early groupings?]
```

### 2. Batch Observations (appended to memo file)

After all memos in your batch, add a section:

```markdown
## Batch {n} Cross-Interview Observations

**Emerging Patterns**: [What do multiple participants in this batch talk about similarly?]

**Notable Variation**: [Where do participants differ? What might explain the differences?]

**Surprises**: [What didn't you expect? What challenges assumptions?]

**Puzzles**: [What doesn't make sense yet? What needs further investigation?]

**Potential Groupings**: [Are there types or clusters forming? Which participants seem similar?]

**Strongest Quotes in This Batch**: [List 3-5 quotes that are particularly vivid, analytical, or representative — these are early candidates for the evidence bank]
```

## Reading Stance

Approach each interview asking:
- What is this person trying to tell me?
- What matters to them about this?
- What would I need to know to understand their experience from the inside?
- What do they DO vs. what do they SAY they do? (Behavioral > stated preferences)
- What surprises me? What confirms expectations?
- What is NOT said — silences, deflections, avoided topics?
- What language and metaphors do they use? (In-vivo candidates)

### Distinguishing Input Types

**Raw transcripts**: Rich in language, pauses, hedging, emphasis. Pay close attention to:
- What they say at length vs. briefly
- Where they become animated or emotional
- Self-corrections and contradictions within the same interview
- Unprompted topics (what they bring up without being asked)

**Interview notes**: More condensed, filtered through the researcher's lens. Pay attention to:
- What the note-taker chose to record (signals importance)
- Bracketed or italicized researcher observations
- Gaps between questions asked and topics noted

**Interview summaries**: Most processed — treat as an interpretation layer. Pay attention to:
- Themes the summarizer highlighted
- Quotes they chose to preserve
- Whether the summary captures behavior or just attitudes

## Quality Gate

Before writing your outputs, verify:

- [ ] **Cognitive Empathy**: For each memo, can a reader understand this participant's perspective from the inside? If any memo reads like a clinical summary rather than an empathic account, revise.
- [ ] **Heterogeneity**: Do your memos capture how participants DIFFER, not just what they share? If all memos sound the same, you are flattening variation — go back and sharpen distinctions.
- [ ] **Specificity**: Do quotes include enough context to understand them later? If any quote is orphaned from context, add it.
- [ ] **Behavioral vs. Attitudinal**: Have you noted what participants DO (behaviors, workarounds, practices) separately from what they SAY they want? If behavioral observations are thin, re-read for them.

## For the Consolidation Agent

If you are the **consolidation agent** (running after all batch agents complete):

Read ALL `batch-{n}-memos.md` files and produce:

### `consolidated-observations.md`

```markdown
# Consolidated Observations Across All Interviews

**Dataset Overview**: [Total interviews, participant characteristics, data types]

## Strong Patterns (appeared across multiple batches)
- [Pattern 1]: [Description + which batches/participants]
- [Pattern 2]: ...

## Notable Variation
- [Dimension of variation]: [How participants split + tentative explanation]

## Contradictions & Tensions
- [Contradiction]: [What participants disagree about or where accounts conflict]

## Surprises
- [Surprise]: [What challenges prior assumptions]

## Emerging Groupings
- [Group A]: [Characteristics + which participants]
- [Group B]: ...

## Strongest Quotes (Top 10-15 across all batches)
> "[Quote]" — [Participant ID] (Context: ...)

## Puzzles for Phase 2
- [Question that coding should help answer]
```

### `phase1-summary.md`

A concise handoff (aim for ~500 words) containing:
1. Dataset description (count, participant types, data quality)
2. Top 5 patterns observed
3. Top 3 dimensions of variation
4. Key surprises and contradictions
5. Recommended coding focus areas for Phase 2
6. Any data quality concerns (e.g., thin interviews, inconsistent depth)

---

## Parallel Extensibility Slot

_The `parallel/` directory is reserved for future analysis signals embedded in this phase. Currently empty. Examples of what could be added here:_

- _`sentiment-extraction.md` — Per-interview emotional valence ratings and high-intensity moments_
- _`journey-raw-data.md` — Temporal touchpoints and emotional states extracted per interview_
- _`language-patterns.md` — Distinctive vocabulary, metaphors, and framing devices_
