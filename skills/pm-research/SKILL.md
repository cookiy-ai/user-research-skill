---
name: pm-research
description: >
  Product and UX research workflows without Cookiy MCP: planning studies,
  drafting interview guides and surveys, synthesizing qualitative evidence,
  recruiting participants, and producing stakeholder-ready narratives using
  this repository's prompts, references, and examples.
---

# PM / UXR Research Toolkit

This skill is **additive** and **not** the Cookiy MCP runtime. It does not
call `cookiy_*` tools or require Cookiy authentication. Use it when the
user wants agent help with research craft inside this repo's open library.

## When to activate

- User asks for interview guides, usability scripts, JTBD studies, surveys
- User wants synthesis: coding, affinity mapping, opportunity mapping
- User needs recruitment copy or screening flows
- User wants data-informed stakeholder narratives or findings decks

## Operating principles

1. **Pick a workflow** from "Workflow router" below.
2. **Load the smallest set of files** needed—usually one prompt plus one reference.
3. **Stay evidence-first**: ask for inputs the prompt expects (`{{placeholders}}`).
4. **Respect content policy**: synthesize and transform; do not reproduce copyrighted text.
5. **Optional scripts**: offer `scripts/transcript_to_codes.py` and `scripts/survey_sampler.py` when they save time.

## Workflow router

| User intent | Start here | Pair with |
|---|---|---|
| Switch / JTBD discovery | `prompts/interview-guides/jtbd-switch-interview.md` | `references/methods/jtbd-framework.md` |
| Stronger probes | `prompts/interview-guides/probing-techniques.md` | `references/templates/discussion-guide-template.md` |
| Usability test | `prompts/interview-guides/usability-test-script.md` | `references/templates/discussion-guide-template.md` |
| Qualitative coding | `prompts/synthesis/qualitative-coding.md` | `examples/synthesis/coded-transcript-excerpt.md` |
| Affinity mapping | `prompts/synthesis/affinity-mapping.md` | `prompts/synthesis/evidence-first-synthesis.md` |
| Opportunity mapping | `prompts/synthesis/opportunity-solution-tree.md` | `references/methods/continuous-discovery-loop.md` |
| Survey design | `prompts/study-briefs/survey-design.md` | `references/methods/survey-statistics-basics.md` |
| Data storytelling | `prompts/stakeholder-readouts/data-story-narrative.md` | `references/templates/findings-deck-template.md` |
| Recruitment | `prompts/recruitment/outreach-script.md` | `references/templates/recruit-screener-template.md` |
| Screening call | `prompts/recruitment/screening-call.md` | `examples/recruitment/cold-outreach-email.md` |

## Full index

See `skills/pm-research/references/method-index.md` for a complete file listing.

## Conflict rule

If the user also wants live Cookiy operations (hosted studies, MCP tools),
switch to `skills/cookiy/SKILL.md` and follow Cookiy MCP preflight there.
