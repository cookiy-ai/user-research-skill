<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy AI — End-to-End User Research via CLI

Cookiy AI automates the full user research lifecycle — both qualitative (via AI-moderated
interviews) and quantitative (via user surveys). Use the installed `cookiy` command from
`@cookiyai/cookiy-cli` for all platform operations. `cookiy-cli` is an alias for the same command.

## Setup

Requires Node.js 18+. If the old unscoped package is installed, remove it first:

```bash
npm uninstall -g cookiy-cli
```

Install the CLI and check its version:

```bash
npm install -g @cookiyai/cookiy-cli
cookiy --version
```

Use `cookiy <command> --help` for command options.

## Command Output

- Successful REST commands print the response `data` to stdout, without the outer `{ok, data}`
  envelope. JSON results stay JSON; `quant raw-response` prints CSV text.
- API and network errors exit with code 1 and print error JSON to stderr. Read `code`, `message`,
  `details`, and `login_url` when present. Local argument or missing-token errors may be plain text.

---

## Authentication

The CLI needs a saved access token. If any command returns an auth error — no token, expired token,
or a response containing a login URL — handle it like this:

1. Show the login URL from the CLI error output or help and ask the user to sign in and return the
   access token.
2. Run `cookiy save-token <access_token>` to save it.
3. Re-run the command that originally failed.

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

## Additional Information

For any issues, contact support@cookiy.com.
