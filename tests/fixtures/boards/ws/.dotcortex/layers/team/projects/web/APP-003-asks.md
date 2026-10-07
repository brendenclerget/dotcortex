# APP-003: Payment error messages

**Status:** IN_PROGRESS
**Priority:** MEDIUM
**Type:** TASK
**Assignee:** jane@example.com
**Review:** decision-needed
**Created:** 2026-10-01
**Updated:** 2026-10-04

## Description
Payment error messages with two open questions.

## Acceptance Criteria
- [x] AC1: First version built
- [ ] AC2: Copy approved

## What shipped
_Not recorded._

## Evidence
_Not recorded._

## Needs from assignee
### 1. Is this the right wording for the error people see?
- Kind: Approve
- For: bob@example.com
- Why: It's what people read when a payment fails.
- Built today: "Your payment didn't go through. Nothing was charged." On main.

### 2. Should a failed attempt be retried automatically?
- Kind: Question
- For: carol@example.com
- Why: Retrying can charge twice if the bank is slow.
- Options:
  - (a) Never retry: people try again themselves
  - (b) Retry once after 30 seconds
- Recommended: (a) no risk of a double charge

## Notes / Log
- 2026-10-01: Created
