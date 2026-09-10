# EAGOLD — R10 EXPOSURE REDUCTION ENGINE
## Formal Specification v1.1

**Status:** LOGICALLY CLOSED / READY FOR IMPLEMENTATION
**Scope:** R10 Exposure Reduction
**System:** EAGOLD / MT4
**Repository:** `sezinando/newbot`
**Supersedes:** conceptual portions of R10 v1.0 where this document is more specific

---

## 1. Executive Definition

R10 is the EAGOLD engine responsible for reducing exposure that already exists in the active basket in a controlled, deterministic and auditable manner.

R10 is **not** a recovery engine, does not predict market direction, does not create exposure merely to justify a reduction, and does not own recovery accounting or recovery-step progression.

### Fundamental invariant

> **R10 reduces existing exposure. It must never create new exposure as a prerequisite for reduction.**

The engine therefore operates as a decision-and-execution pipeline:

```text
MEASURE
  ↓
CLASSIFY
  ↓
GENERATE CANDIDATES
  ↓
SIMULATE
  ↓
HARD CONSTRAINTS
  ↓
LEXICOGRAPHIC RANKING
  ↓
EXECUTE
  ↓
VERIFY
  ↓
RECONCILE
  ↓
PUBLISH EVENT
```

---

## 2. Architectural Responsibility

| Engine | Responsibility | R10 relationship |
|---|---|---|
| R9 | Exposure detection / hedge behavior | Upstream exposure controller |
| R10 | Reduction of existing exposure | This specification |
| R10.2 | Recovery realization/accounting | Receives R10 financial events |
| R11 | Recovery step/progression | Consumes recovery state; controls next step |
| R4/R5/R7 | Existing lifecycle/grid/restart behavior | Must not be silently rewritten by R10 |

### Boundary rule

R10 may **observe** R9, R10.2 and R11 state, but must not silently assume ownership of their responsibilities.

---

## 3. Current Implementation Baseline

The current EAGOLD implementation is v0.106. Existing R10 inputs include:

- `EnableR10Reduce`
- `R10MinExposureLots`
- `EnableR10PairReduction`
- `R10PairMinProfit`
- `R10PairMaxLots`
- `R10PairCooldownSeconds`
- visual R10 markers

The current source also provides the core exposure primitives `DirectionLots()`, `ExposureLots()`, `HeavyDirection()` and `DirectionBasketProfit()`. These establish the baseline on which the formal engine should be implemented. [Source: current `EA/EAGOLD.mq4`]

---

## 4. Basket State Model

R10 must reason about the basket as a state vector rather than a single P/L number.

### 4.1 Position state

```text
BUY_LOTS
SELL_LOTS
NET_LOTS_SIGNED = BUY_LOTS - SELL_LOTS
NET_EXPOSURE    = abs(NET_LOTS_SIGNED)
GROSS_EXPOSURE  = BUY_LOTS + SELL_LOTS
```

### 4.2 Hedge state

```text
HEDGE_VOLUME = min(BUY_LOTS, SELL_LOTS)
HEDGE_RATIO  = HEDGE_VOLUME / max(BUY_LOTS, SELL_LOTS)
```

If both sides are zero, `HEDGE_RATIO = 0`.

### 4.3 Account state

```text
BALANCE
EQUITY
MARGIN
FREE_MARGIN
MARGIN_LEVEL
```

### 4.4 Economic state

R10 should distinguish:

```text
FLOATING_PROFIT
FLOATING_SWAP
FLOATING_COMMISSION
REALIZED_RESULT
TRANSACTION_COST
```

For the EAGOLD trade result, the current implementation correctly aggregates:

```text
OrderProfit() + OrderSwap() + OrderCommission()
```

because `OrderProfit()` alone does not include swap and commission.

### 4.5 Recovery state

R10 observes, but does not own:

```text
RECOVERY_ACTIVE
RECOVERY_DEBT
RECOVERY_REMAINING
RECOVERY_SURPLUS
```

---

## 5. Exposure Semantics

### Net exposure

Net exposure represents directional imbalance:

```text
NET = abs(BUY - SELL)
```

### Gross exposure

Gross exposure represents total open inventory:

```text
GROSS = BUY + SELL
```

### Critical distinction

A basket containing:

```text
BUY  1.00
SELL 1.00
```

has:

```text
NET   = 0
GROSS = 2.00
```

Therefore a basket can have zero directional exposure while still carrying substantial gross inventory, margin requirements, costs and structural complexity.

---

## 6. Recovery Debt Boundary

Recovery Debt is an EAGOLD internal accounting abstraction. It is not treated as a universal trading-industry definition and must not be conflated with monetary loss, lot volume, net exposure or gross exposure.

The current R10.2 implementation defines cycle debt from the equity excursion:

```text
RECOVERY_DEBT = max(0, START_EQUITY - WORST_EQUITY)
```

and remaining debt as:

```text
REMAINING_DEBT = max(0, START_EQUITY - CURRENT_EQUITY)
```

Recovery surplus is:

```text
RECOVERY_SURPLUS = max(0, CURRENT_EQUITY - START_EQUITY)
```

R10 does not directly modify these values. R10 emits a reduction event containing the realized financial result; R10.2 interprets that event inside the recovery cycle.

---

## 7. Candidate Model

R10 must generate explicit candidates rather than directly closing whichever order happens to be encountered first.

Each candidate should contain at least:

```text
ACTION_ID
ACTION_TYPE
TICKET_A
TICKET_B
DIRECTION_A
DIRECTION_B
REQUESTED_LOTS_A
REQUESTED_LOTS_B
```

plus its simulated before/after state.

### Initial action types

```text
R10_PAIR
R10_SINGLE_PARTIAL
R10_PROFIT_FUNDED
```

`R10_PROFIT_FUNDED` is an architectural extension and should not be implemented until separately validated. The initial implementation should prioritize pair reduction and the already-existing reduction behavior.

---

## 8. Reduction Modes

### R10-A — Pair Reduction

Uses opposing positions to reduce gross inventory.

Example:

```text
BUY  1.00
SELL 0.40

REDUCE 0.40 FROM BOTH SIDES

BUY  0.60
SELL 0.00
```

This reduces gross exposure from 1.40 to 0.60 while leaving net exposure at 0.60.

Where supported, `OrderCloseBy()` is the native MQL4 mechanism for closing one opened position against an opposite opened position.

### R10-B — Profit-Funded Reduction

Uses qualifying profitable positions as economic funding for partial reduction of a losing position.

This is a researched design pattern, not a universal trading rule. It must remain subject to the same simulation, constraints and verification pipeline.

### R10-C — Basket Reduction

Future extension for whole-basket risk relief. It is intentionally outside the minimum implementation scope.

---

## 9. Simulation Before Execution

Every candidate must be evaluated in two states.

### BEFORE

```text
BUY_LOTS
SELL_LOTS
NET
GROSS
HEDGE
FLOATING_RESULT
MARGIN
FREE_MARGIN
RECOVERY_STATE
```

### AFTER

```text
BUY_LOTS'
SELL_LOTS'
NET'
GROSS'
HEDGE'
FLOATING_RESULT'
MARGIN'
FREE_MARGIN'
RECOVERY_STATE'
```

The candidate is not executable merely because the order exists or can technically be closed.

It must first survive the constraint layer.

### Important limitation

`AccountFreeMarginCheck()` is designed to estimate free margin after opening an order. It must not be represented as a direct post-close simulator. Post-close margin state must be reconstructed from the actual account state after execution.

---

## 10. Hard Constraints

Hard constraints are binary. A candidate either passes or is rejected.

### HC-01 — Ownership

The order must belong to the EAGOLD scope:

```text
OrderSymbol() == Symbol()
OrderMagicNumber() == MagicNumber
```

### HC-02 — Valid order state

The ticket must exist and be correctly selected before execution.

### HC-03 — Valid volume

Requested volume must respect broker:

```text
MODE_MINLOT
MODE_LOTSTEP
MODE_MAXLOT
```

### HC-04 — Minimum retained exposure

R10 must not reduce below `R10MinExposureLots` when the parameter is applicable.

### HC-05 — CloseBy permission

`OrderCloseBy()` may only be used where the symbol/broker permits it.

### HC-06 — Reduction invariant

A reduction action must not increase gross exposure:

```text
GROSS_AFTER <= GROSS_BEFORE
```

### HC-07 — Directional safety

Where the active state requires directional protection:

```text
NET_AFTER <= NET_BEFORE
```

If an action does not reduce net exposure but legitimately reduces gross exposure, such as a pair reduction, it can remain valid. The constraint therefore depends on the action class and current protection state.

### HC-08 — Hedge integrity

A candidate must not destroy a hedge that the active cycle requires unless the responsible policy explicitly permits the transition.

### HC-09 — Margin safety

The post-action state must not violate account/broker safety limits.

### HC-10 — No new exposure

R10 may close or partially close existing exposure. It must not open a new position solely to enable a reduction.

### HC-11 — Recovery boundary

R10 cannot directly rewrite R10.2 debt or R11 recovery-step parameters.

### HC-12 — Idempotency

The same logical `ACTION_ID` cannot be executed twice.

---

## 11. Hedge Integrity Model

Hedge Integrity is a constraint set, not a weighted score.

The observable quantities are:

```text
EXPECTED_HEDGE
ACTUAL_HEDGE
HEDGE_DEFICIT
HEDGE_SURPLUS
```

At minimum:

```text
ACTUAL_HEDGE = min(BUY_LOTS, SELL_LOTS)
```

The exact expected hedge must be supplied by the responsible exposure/recovery policy rather than invented by R10.

Thus:

```text
HEDGE_DEFICIT = max(0, EXPECTED_HEDGE - ACTUAL_HEDGE)
HEDGE_SURPLUS  = max(0, ACTUAL_HEDGE - EXPECTED_HEDGE)
```

No arbitrary `1.50x` hedge rule is part of the specification.

---

## 12. Smart Closure / Candidate Ranking

R10 does not use arbitrary weighted scores in the core decision engine.

The selection method is lexicographic.

### Priority 1 — Hard constraints

Reject every invalid candidate.

### Priority 2 — Do not increase critical directional exposure

Prefer candidates with:

```text
NET_AFTER <= NET_BEFORE
```

when directional safety is active.

### Priority 3 — Reduce gross exposure

Prefer:

```text
GROSS_AFTER < GROSS_BEFORE
```

### Priority 4 — Preserve hedge integrity

Prefer the candidate that better preserves the required hedge state.

### Priority 5 — Improve margin state

Prefer lower margin load / greater free margin when otherwise equivalent.

### Priority 6 — Improve recovery state

Prefer the candidate that improves the active recovery condition without violating the recovery boundary.

### Priority 7 — Economic result

Compare expected net economic result including:

```text
profit + swap + commission - expected transaction costs
```

### Priority 8 — Operational simplicity

Prefer the simpler valid action when risk/economic outcomes are otherwise equivalent.

### Priority 9 — Deterministic tie-break

Use stable identifiers such as ticket/action ID. Never depend on arbitrary order returned by position enumeration.

---

## 13. Why No Arbitrary Reduction Score Exists

A formula such as:

```text
40% exposure
30% profit
20% margin
10% hedge
```

would introduce weights without empirical justification.

Such weights may be appropriate for a later statistical optimization project, but they are not part of the R10 logical contract.

The institutional rule is:

> **Hard constraints first; deterministic priorities second; statistical calibration only after telemetry exists.**

---

## 14. Context Boundary

R10 context is operational, not predictive.

### Operational context

```text
Spread
Bid / Ask
Trading permission
Broker limits
Lot rules
CloseBy capability
Margin
Freeze/stop constraints
Execution conditions
Current basket state
```

### Non-R10 prediction context

Indicators such as:

```text
MACD
IFR
MMA21
MMA34
VWAP
M5/M15 regime
```

must not silently become R10 trading signals.

They may be consumed by another context/recovery policy if explicitly contracted, but R10 itself remains a reduction engine.

This prevents architectural drift from:

```text
EXPOSURE REDUCTION
```

to:

```text
MARKET PREDICTION + NEW TRADING STRATEGY
```

---

## 15. Execution Contract

```text
1. DETECT
2. SNAPSHOT BASKET
3. VALIDATE OWNERSHIP
4. GENERATE CANDIDATES
5. SIMULATE EACH CANDIDATE
6. APPLY HARD CONSTRAINTS
7. RANK VALID CANDIDATES
8. CREATE ACTION_ID
9. EXECUTE
10. CAPTURE RETURN / ERROR
11. RESELECT / VERIFY TICKETS
12. REBUILD BASKET STATE
13. RECONCILE HEDGE
14. PUBLISH R10 EVENT
15. START COOLDOWN / CONSUME ACTION_ID
```

---

## 16. Failure State Machine

```text
DETECTED
   ↓
CANDIDATE
   ↓
SIMULATED
   ↓
AUTHORIZED
   ↓
EXECUTING
   ↓
VERIFYING
   ├── SUCCESS
   ├── RETRY
   ├── BLOCK
   └── ABORT
```

### BLOCK

Known constraint violation. No execution attempt.

Examples:

```text
invalid volume
CloseBy not permitted
minimum exposure reached
ownership failure
hedge constraint failure
```

### RETRY

Potentially transient execution problem.

Examples can include broker execution conditions such as requote or trade-context contention. Retry count must be bounded.

### ABORT

Execution cannot safely continue.

Examples:

```text
inconsistent ticket state
unexpected residual volume
unrecoverable execution error
```

### SUCCESS

Execution and post-state verification agree.

---

## 17. Ticket Lifecycle Audit

Every R10 execution should produce a complete lifecycle record.

### BEFORE

```text
ACTION_ID
TIMESTAMP
TICKET
TYPE
LOTS
OPEN_PRICE
FLOATING_PROFIT
SWAP
COMMISSION
```

### REQUEST

```text
ACTION_TYPE
REQUESTED_LOTS
EXECUTION_PRICE
```

### RESULT

```text
RETURN_VALUE
ERROR_CODE
```

### AFTER

```text
TICKET_EXISTS
REMAINING_LOTS
CLOSE_TIME
CLOSE_PRICE
REALIZED_RESULT
BASKET_STATE_AFTER
```

This is mandatory for diagnosing ticket lifecycle anomalies and proving that an apparent reduction actually occurred.

---

## 18. Idempotency and Cooldown

Cooldown is a secondary protection. The primary protection is logical action identity.

```text
ACTION_ID
   ↓
EXECUTE
   ↓
VERIFY
   ↓
CONSUME ACTION_ID
   ↓
COOLDOWN
```

Repeated ticks must not produce repeated execution of the same logical reduction.

`R10PairCooldownSeconds` remains a useful operational throttle but does not replace state-based idempotency.

---

## 19. R10 → R10.2 Event Contract

R10 publishes a `REDUCTION_EVENT` containing at least:

```text
ACTION_ID
TIMESTAMP
SYMBOL
MAGIC
ACTION_TYPE
TICKET_A
TICKET_B
LOTS_A
LOTS_B

BUY_BEFORE
SELL_BEFORE
NET_BEFORE
GROSS_BEFORE

BUY_AFTER
SELL_AFTER
NET_AFTER
GROSS_AFTER

REALIZED_PROFIT
REALIZED_SWAP
REALIZED_COMMISSION
REALIZED_NET

EXECUTION_STATUS
ERROR_CODE
```

R10.2 consumes this event and updates recovery accounting.

R10 must not directly mutate R10.2 debt variables.

---

## 20. R10 → R11 Boundary

R10 can report:

```text
exposure reduced
hedge state changed
recovery event occurred
post-reduction state
```

R11 remains responsible for:

```text
recovery step distance
step progression
recovery lot progression
recovery-specific caps
```

R10 must not silently modify `RecoveryStepMultiplier` or `RecoveryStepMax`.

---

## 21. Broker and Execution Controls

R10 must respect broker properties such as:

```text
MODE_MINLOT
MODE_LOTSTEP
MODE_MAXLOT
MODE_CLOSEBY_ALLOWED
MODE_FREEZELEVEL
```

The implementation must also capture and classify execution errors instead of treating all failures as equivalent.

Volume error handling must recognize that invalid trade volume is error 131; this must not be confused with unrelated trade errors.

---

## 22. Financial Cost Model

For EAGOLD's internal net trade result:

```text
NET_RESULT = OrderProfit()
           + OrderSwap()
           + OrderCommission()
```

Transaction cost analysis should additionally consider spread and, where measurable, execution slippage.

A reduction that is profitable in `OrderProfit()` but negative after swap/commission must not be classified as economically positive solely from gross profit.

---

## 23. Test Matrix

### Position-state tests

| ID | Scenario | Expected |
|---|---|---|
| T01 | BUY > SELL | Correct heavy direction |
| T02 | SELL > BUY | Correct heavy direction |
| T03 | BUY = SELL | NET = 0 |
| T04 | No positions | R10 idle |
| T05 | Pair reduction | GROSS decreases |

### Broker/volume tests

| ID | Scenario | Expected |
|---|---|---|
| T06 | Below minimum lot | BLOCK |
| T07 | Invalid lot step | BLOCK |
| T08 | Above maximum lot | BLOCK |
| T09 | CloseBy unsupported | BLOCK/fallback |

### Risk tests

| ID | Scenario | Expected |
|---|---|---|
| T10 | GROSS would increase | BLOCK |
| T11 | Required hedge destroyed | BLOCK |
| T12 | Minimum exposure reached | BLOCK |
| T13 | Margin safety violated | BLOCK |

### Execution tests

| ID | Scenario | Expected |
|---|---|---|
| T14 | OrderClose success | VERIFY |
| T15 | OrderClose failure | error + RETRY/ABORT |
| T16 | Ticket changes/disappears | VERIFY/reconcile |
| T17 | Duplicate ACTION_ID | IGNORE/BLOCK |
| T18 | Cooldown active | BLOCK |

### Accounting tests

| ID | Scenario | Expected |
|---|---|---|
| T19 | Commission present | Included |
| T20 | Swap present | Included |
| T21 | Realized loss | Correct R10 event |
| T22 | Realized profit | Correct R10 event |
| T23 | R10.2 debt active | R10 emits; R10.2 accounts |

### Determinism tests

| ID | Scenario | Expected |
|---|---|---|
| T24 | Multiple valid candidates | Same winner every run |
| T25 | Position enumeration order differs | Same decision |

---

## 24. Backtest Validation Protocol

Every R10 implementation change must be evaluated with:

1. identical symbol;
2. identical initial balance;
3. identical spread assumptions;
4. identical lot configuration;
5. identical Magic Number;
6. identical date range;
7. identical tester model;
8. R10 telemetry enabled.

Compare at least:

```text
R10 action count
R10 blocked count
R10 retry count
R10 realized result
NET exposure before/after
GROSS exposure before/after
maximum gross exposure
maximum drawdown
margin state
recovery debt
recovery duration
```

A backtest improvement is not accepted merely because final profit increases. It must also satisfy the R10 invariants and preserve lifecycle behavior.

---

## 25. Required Telemetry

Minimum event fields:

```text
timestamp
symbol
magic
cycle_id
action_id
action_type
state_before
candidate_count
candidate_selected
constraint_result
execution_result
error_code
state_after
realized_net
net_before
net_after
gross_before
gross_after
hedge_before
hedge_after
margin_before
margin_after
recovery_state
```

Telemetry should log state transitions and meaningful actions rather than repeating identical HOLD messages on every tick.

---

## 26. Explicitly Rejected Rules

The following are **not** part of the R10 specification:

- arbitrary Basket Balance Score formula;
- 40/30/20/10 Reduction Score weights;
- fixed Hedge Integrity multiplier such as 1.50x;
- universal ATR 2.5x rule;
- automatic 50% reduction based only on ATR;
- Positive Grid inside R10;
- opening a new position merely to facilitate reduction;
- R10 owning Recovery Debt accounting;
- R10 owning R11 step progression;
- R10 acting as a market-direction predictor.

These may be researched independently but must not be introduced as established R10 behavior without evidence.

---

## 27. Evidence Classification

The R10 research used the following hierarchy:

### A — Strong official/documented/code evidence

Direct MQL4/MQL5 documentation, current EAGOLD source, or explicit documented behavior of a referenced system.

### B — Strong community evidence

Repeated or technically substantive community implementations/discussions.

### C — Weak community evidence

Isolated or commercially motivated claims without sufficient technical validation.

### D — Inference

Reasonable engineering inference from A/B evidence, but not directly documented.

### E — Project hypothesis

An EAGOLD-specific design decision requiring empirical validation.

This classification prevents hypotheses from being silently presented as facts.

---

## 28. Institutional Design Principles

The R10 specification is governed by these principles:

1. **Exposure reduction is not recovery.**
2. **Net and gross exposure are different risk dimensions.**
3. **A candidate must be simulated before execution.**
4. **Constraints precede optimization.**
5. **Determinism precedes statistical optimization.**
6. **Execution must be verified against actual account state.**
7. **Financial accounting belongs to the designated accounting engine.**
8. **Recovery progression belongs to R11.**
9. **R10 must never create exposure solely to justify a reduction.**
10. **Every meaningful action must be auditable.**
11. **Repeated ticks must not repeat the same logical action.**
12. **Any threshold not supported by evidence is a calibration parameter, not a fact.**

---

## 29. Implementation Scope

### Phase 1 — Required

Implement and validate:

```text
Basket State
Candidate Generation
Simulation
Hard Constraints
Pair Reduction
Lexicographic Ranking
Execution
Verification
Ticket Audit
Idempotency
R10 Event
```

### Phase 2 — Controlled extension

After Phase 1 telemetry is stable:

```text
Profit-Funded Reduction
Smart Closure Threshold
Advanced hedge reconciliation
```

### Phase 3 — Experimental

Only after sufficient out-of-sample evidence:

```text
statistical candidate ranking
adaptive thresholds
basket-level optimization
```

---

## 30. Final Status

**R10 logical specification: CLOSED.**

The remaining work is empirical and implementation-oriented:

```text
SPECIFICATION
    ↓
IMPLEMENTATION
    ↓
MT4 COMPILATION
    ↓
SCENARIO TESTS
    ↓
BACKTEST
    ↓
TELEMETRY REVIEW
    ↓
OUT-OF-SAMPLE VALIDATION
    ↓
CALIBRATION
```

No implementation parameter should be declared empirically validated until it survives controlled backtesting and out-of-sample testing.

---

## 31. Primary References

- MQL4 official documentation: Orders, account information, market information and trade functions.
- MQL5 community documentation and examples concerning basket management, hedging, recovery and multi-objective optimization.
- Public documentation/release information from recovery/hedging products used strictly as design references, not as proof that their algorithms are optimal for EAGOLD.
- Current EAGOLD source in `EA/EAGOLD.mq4`.

