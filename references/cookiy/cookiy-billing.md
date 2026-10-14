<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy — Billing

## How It Works

Single wallet balance. Payments deduct from it; top-ups add to it.

- **Balance sufficient:** the paid operation can proceed.
- **Balance short:** auto-charges saved card. If that also fails, the wallet must be topped up manually first.
- **Refunds:** not self-service — contact support.

## Handling 402 / Insufficient Balance

Paid operations can fail with `INSUFFICIENT_BALANCE` in stderr JSON (HTTP 402). Use the error's
`details` for the payment quote and balance shortfall:

1. Show the user the payment information and minimum amount needed from the error response.
2. After the user confirms how much to charge, run `billing checkout` to get a checkout URL.
3. After the user confirms payment, retry the failed operation.

## CLI Commands

### billing transactions

List wallet transaction history. Optionally filter by study or survey.

```
cookiy billing transactions [--limit <n>] [--cursor <iso8601>] [--study-id <uuid>] [--survey-id <sid>]
```

### billing price-table

Get current pricing for all operations.

```
cookiy billing price-table
```

### billing balance

Get current wallet balance.

```
cookiy billing balance
```

### billing checkout

Get a Stripe checkout URL to top up the wallet. Amount must be a whole dollar (no cents), minimum $10.

```
cookiy billing checkout --amount-usd-cents <n>
```
