# Example: Coded Transcript Excerpt (Synthetic)

This example shows how **raw notes** can move to **codes** and then **themes**. All content is fabricated.

## Raw excerpt (synthetic)

P1: Last month we missed a customer renewal because nobody saw the alert. We had three tools and the alert went to the wrong channel.

P2: We "fixed" it by adding another daily standup, but that does not scale.

P3: I do not trust notifications anymore; I manually check the dashboard every morning.

## First-cycle codes

| Segment | Codes |
|---|---|
| missed renewal + wrong channel | `alert_routing_failure`, `tool_sprawl` |
| standup workaround | `manual_process_debt`, `scaling_limit` |
| distrust notifications | `trust_erosion`, `compensating_behavior` |

## Theme candidates

1. **Fragmentation tax**: multiple tools increase missed handoffs (`tool_sprawl`, `alert_routing_failure`).
2. **Human patching**: teams compensate with meetings and manual checks (`manual_process_debt`, `compensating_behavior`).
3. **Alert fatigue and distrust**: people stop believing automated signals (`trust_erosion`).

## Next validation step

- Ask 5 participants for a recent incident timeline and the exact channel/tool where the signal failed.
