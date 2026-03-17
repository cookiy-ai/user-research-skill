# Roadmap

The repo now has a stable production runtime surface and a growing open library surface. The next steps should expand usefulness without destabilizing install and indexing behavior.

## Current State

- Production installable skill: `cookiy`
- Stable MCP registration and install entrypoints
- Open library sections for prompts, references, examples, and policy docs
- Lightweight CI guard for protected public surfaces

## Near-Term Priorities

### 1. Better study-brief and interview-guide assets

Goal:
- Make it easier for users and agents to turn vague research goals into strong Cookiy studies.

Examples:
- B2B discovery
- onboarding friction
- pricing research
- prototype feedback

### 2. Evidence-first synthesis pack

Goal:
- Standardize how raw transcripts, notes, and survey comments become findings.

Deliverables:
- synthesis prompts
- insight-card templates
- worked examples
- contradiction and confidence handling guides

### 3. Stakeholder readout pack

Goal:
- Help agents turn findings into concise outputs for founders, PMs, and design teams.

Deliverables:
- executive summary prompts
- weekly readout templates
- recommendation framing patterns

## Medium-Term Priorities

### 4. Research landscape toolkit

Goal:
- Add a structured way to do recent-signal market, competitor, and community research.

Constraint:
- Keep this additive until a runnable implementation and maintenance plan exist.

### 5. Future installable skills

Candidate skill areas:
- research-plan
- synthesize-research
- research-readout
- research-landscape

Promotion rule:
- Do not place these under the public `skills/` install surface until default-skill behavior across public platforms is verified.

## Out of Scope

- Hosting copyrighted books or long excerpts
- Adding heavy infrastructure to a docs-first repository
- Breaking the current `cookiy` install path to chase a cleaner multi-skill layout
