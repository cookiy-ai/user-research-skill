# Cookiy AI — End-to-End User Research via CLI

Cookiy AI automates the full user research lifecycle — both qualitative (via AI-moderated
interviews) and quantitative (via user surveys). All operations go through the
[`scripts/cookiy.sh`](scripts/cookiy.sh) CLI (scripts folder is located under the same directory
as this file). This is the only supported integration path — do not use alternative methods.

---

## Authentication

The CLI needs a saved access token. If any command returns an auth error — no token, expired token,
or a response containing a login URL — handle it like this:

1. Tell the user they need to sign in. The login URL is shown in the CLI error output. Include this
   URL in your message so the user can open it directly, and ask them to copy the access token back
   to you once logged in.
3. Use the `save-token` CLI command to save it.
4. Automatically re-run the command that originally failed.

---

## Modules

| Module | Reference | Covers |
|--------|-----------|--------|
| Qualitative Research | [`cookiy-qual.md`](cookiy-qual.md) | Study creation, discussion guides, real participant recruitment, synthetic user interviews, reports — the full interview study workflow |
| Quantitative Research | [`cookiy-quant.md`](cookiy-quant.md) | Survey form creation, real participant recruitment, report — the full survey workflow |
| Billing | [`cookiy-billing.md`](cookiy-billing.md) | Payment (costs) and billing related guidance and operations |

---

## CLI Commands

### Auth

**save-token** — Store an access token obtained from browser sign-in.

```
scripts/cookiy.sh save-token <access_token>
```
