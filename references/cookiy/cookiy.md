<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy AI — End-to-End User Research via CLI

Cookiy AI automates the full user research lifecycle — both qualitative (via AI-moderated
interviews) and quantitative (via user surveys). Use the installed `cookiy` command from
`@cookiyai/cookiy-cli` for all platform operations.

## Setup

Requires Node.js 18+. If `cookiy` is unavailable, install it:

```bash
npm install -g @cookiyai/cookiy-cli
```

---

## Authentication

The CLI needs a saved access token. If any command returns an auth error — no token, expired token,
or a response containing a login URL — handle it like this:

1. Tell the user they need to sign in and provide the login URL from the CLI error output.
2. Have the user save their token locally with `save-token`, or use an explicitly authorized
   secure local handoff. Do not ask them to paste the token into chat or expose it in tool logs.
3. Resume within the existing authorization and budget. For a failed write, check the resource
   state before retrying; do not automatically repeat a charged operation or recruitment launch.

---

## User Limits

Once per session before non-auth operations, run `cookiy user info` and check limits.

If a failure or request is limit-related, tell the user immediately and mention they can contact
support@cookiy.com to upgrade to enterprise.

Before creating a study from a detailed research plan, compare the planned interview duration with
the user's duration limit, if present. If the plan exceeds the limit, notify the user before
creation and ask whether to adjust the interview questions or study content.

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
cookiy save-token <access_token>
```

---

## Additional Information

### Failure handling

- Keep the CLI version, timestamp with timezone, redacted command, exit code, and stderr.
  Include HTTP status, error code, and request ID when the installed CLI provides them.
- Distinguish input errors (400/422), authentication (401), permissions (403), conflicts (409),
  limits/rate limiting (429), service failures (5xx), and network/timeouts. Do not treat a
  generic service failure as proof that the user's parameters are invalid.
- After a failed or timed-out write, read the resource back before deciding whether to retry.
  Do not automatically repeat a charged operation or recruitment launch: a failed response
  does not prove that the operation had no effect. Preserve existing confirmation gates.
- Share request IDs with support. Never share access tokens, credential files, raw internal
  error pages, or complete sensitive links; do not bypass the CLI to troubleshoot.

For any issues, contact support@cookiy.com.
