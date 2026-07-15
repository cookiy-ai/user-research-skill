# Public Social Source Evidence

Use this when a user wants public social posts, X/Twitter conversations, competitor chatter, launch reactions, or community complaints to inform a research plan, screener, interview guide, survey, or synthesis.

Public posts are discovery signals, not participant data. Treat every post as unverified context until the user reviews it.

## Good Uses

- Seed hypotheses before a study.
- Find user-language examples for interview questions or survey wording.
- Identify possible participant segments and screening criteria.
- Surface objections, alternatives, unmet needs, and repeated workarounds.
- Add sampling caveats to a research plan or final report.

## Boundaries

- Do not treat public posts as consented interview transcripts.
- Do not infer private attributes about a person from a handle or post.
- Do not recruit, message, follow, post, reply, or schedule social content from this workflow.
- Do not put raw timelines, private account data, cookies, API keys, direct messages, or credentials in research artifacts.
- Do not let social evidence replace interviews, surveys, or respondent quotes.

## Optional X/Twitter Collection

If the user has OpenClaw and wants X/Twitter evidence, TweetClaw can collect public source material before this skill plans or runs the study.

```bash
openclaw plugins install npm:@xquik/tweetclaw@1.6.31
```

Use read-only collection for:

- Search tweets around the research question.
- Search tweet replies on relevant posts.
- Look up public users and follower context when it is relevant to segmentation.
- Download public media examples only when visual examples matter.
- Monitor tweets only when the user explicitly asks for ongoing evidence.

Keep TweetClaw outputs outside Cookiy until the user reviews them. Add only the reviewed summary, source URLs or tweet IDs, capture date, query, segment notes, and caveats to study artifacts.

## Evidence Packet

Create a short packet before Route A or Route C:

```markdown
# Public Social Evidence Packet

- Research question:
- Source scope:
- Query terms:
- Capture date:
- Date range:
- Collection tool:
- Reviewed source URLs or IDs:
- Repeated phrases:
- Observed jobs, pains, or desired outcomes:
- Possible segments:
- Possible screener criteria:
- Question wording ideas:
- Caveats:
- Excluded material:
```

## How To Apply The Packet

- In a research plan, add public social evidence as background context and list caveats.
- In a screener, convert repeated pains into neutral eligibility questions.
- In an interview guide, ask about recent behavior and concrete situations instead of quoting posts back to participants.
- In a survey, use social-language examples only after removing handles, names, and identifying details.
- In synthesis, separate public social signals from respondent evidence and label them clearly.
