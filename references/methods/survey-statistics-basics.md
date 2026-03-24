# Survey Statistics Basics — Method Card

## What it is

A compact reference for common UX survey decisions: precision, comparisons, and standard metrics like **SUS** and **NPS**. This is guidance, not medical or legal advice.

## Confidence intervals (conceptual)

For a proportion (e.g., percent agree), uncertainty shrinks as sample size increases. Reporting a **margin of error** or confidence interval is better than reporting a point estimate alone.

Rule of thumb: if you only have a handful of responses, treat differences as directional unless you have modeled uncertainty.

## Comparing two designs or flows

- Prefer within-subject designs when learning effects are manageable (same participants, both conditions, counterbalanced order).
- Between-subject designs need larger samples to detect the same effect size.

## Sample size (pragmatic)

Exact calculations depend on effect size, variance, alpha, and power. In product work, start from:

- What decision you are making
- What smallest meaningful difference is
- What failure modes matter (false positive vs false negative)

Use `scripts/survey_sampler.py` for a minimal two-proportion sample-size estimate when you can supply assumptions.

## SUS (System Usability Scale)

- 10-item Likert questionnaire, standardized scoring to 0-100
- Useful for comparing iterations or benchmarking against industry norms (interpret norms cautiously)

## NPS (Net Promoter Score)

- Single 0-10 likelihood question with categorized promoters/passives/detractors
- Useful for tracking trends; weak as a standalone diagnostic without qualitative follow-up

## Related prompts

- `prompts/study-briefs/survey-design.md`

## Attribution note

Formulas in `scripts/survey_sampler.py` are standard statistics references, implemented as code for convenience.
