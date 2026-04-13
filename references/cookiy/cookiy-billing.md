# Cookiy — Billing

## How It Works

Single wallet balance. Payments deduct from it; top-ups add to it.

- **Balance sufficient:** action completes instantly.
- **Balance short:** auto-charges saved card. If that also fails, the wallet must be topped up manually first.
- **Refunds:** not self-service — contact support.

## Handling 402 / Insufficient Balance

Many operations cost money (recruit, synthetic interview, report generation, discussion guide generation). If any CLI command returns a 402 or indicates insufficient balance:

1. Show the user the payment information and minimum amount needed from the error response.
2. After the user confirms how much to charge, run `billing checkout` to get a checkout URL.
3. After the user confirms payment, retry the failed operation.

## CLI Commands

### billing transactions

List wallet transaction history. Optionally filter by study or survey.

```
scripts/cookiy.sh billing transactions [--limit <n>] [--cursor <iso8601>] [--study-id <uuid>] [--survey-id <sid>]
```

### billing price-table

Get current pricing for all operations.

```
scripts/cookiy.sh billing price-table
```

### billing balance

Get current wallet balance.

```
scripts/cookiy.sh billing balance
```

### billing checkout

Get a Stripe checkout URL to top up the wallet. Amount must be a whole dollar (no cents), minimum $10.

```
scripts/cookiy.sh billing checkout --amount-usd-cents <n>
```
