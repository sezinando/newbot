# EAGOLD — Panel Monotonic Extremes Persistence

## Objective

The panel metrics `MENOR P/L` and `MAIOR ACUM. LOTES` represent historical exposure extremes and must be monotonic during an EA lifecycle.

## Rules

- `MENOR P/L`: update only when `current_total_pl < stored_min_pl`.
- `MAIOR ACUM. LOTES`: update only when `current_total_lots > stored_max_lots`.
- A recovery to a better P/L must never overwrite the historical minimum.
- A reduction in open lots must never overwrite the historical maximum accumulated lots.
- Both values must survive EA reinitialization/chart changes through the existing persistent state mechanism.

## Required lifecycle

`LOAD PERSISTED EXTREMES → MEASURE CURRENT STATE → APPLY MONOTONIC UPDATE → DISPLAY → PERSIST`

## Acceptance criteria

1. P/L sequence `-10 → -35 → -12 → +8` leaves `MENOR P/L = -35`.
2. Lot sequence `0.01 → 0.05 → 0.03 → 0.08 → 0.02` leaves `MAIOR ACUM. LOTES = 0.08`.
3. Reinitialization restores both historical values instead of resetting them to zero.
4. Current values (`TOTAL P/L`, `LOTES ATUAIS`) remain instantaneous and are not replaced by historical extremes.

## Implementation note

This is a telemetry/persistence correction. It does not change R10, R10.2, R11, order execution, recovery logic, or exposure-reduction behavior.
