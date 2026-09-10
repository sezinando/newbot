# EAGOLD — R10
# Research Methodology and Validation Report v1.0

**Document class:** Institutional research and methodology record
**Status:** FINAL — Iterations 1–4 completed
**Subject:** R10 Exposure Reduction Engine
**System:** EAGOLD / MT4
**Repository:** `sezinando/newbot`

---

## 1. Purpose

This report records the methodology used to investigate, validate, reject, formalize and close the logical specification of the EAGOLD R10 Exposure Reduction Engine.

The objective was not to invent a sophisticated algorithm and retrofit justification afterward. The objective was to distinguish:

- facts supported by official documentation;
- behavior supported by existing EAGOLD source code;
- technically relevant community evidence;
- engineering inferences;
- EAGOLD-specific hypotheses requiring empirical validation.

The process deliberately favored auditability, architectural separation and deterministic behavior over premature optimization.

---

## 2. Research Question

The central question was:

> **What should R10 be responsible for, how should it decide when and how to reduce an existing EAGOLD exposure, and what evidence is sufficient to authorize each component of that design?**

Secondary questions were:

1. How should net and gross exposure be represented?
2. How should basket state be modeled?
3. What is the proper relationship between R10, R10.2 and R11?
4. Can Pair Reduction be justified technically?
5. How should candidate reductions be compared?
6. How should execution be simulated and verified?
7. How should hedge integrity be protected?
8. How should recovery debt be represented without conflating it with loss or exposure?
9. How should execution failures be classified?
10. What evidence is required before implementation parameters are considered validated?

---

## 3. Evidence Hierarchy

A formal classification was adopted.

### A — Strong official / documented / source-code evidence

Includes:

- official MQL4 documentation;
- official MQL5 documentation;
- current EAGOLD source;
- explicit technical documentation from a referenced product.

### B — Strong community evidence

Includes technically substantive, repeatable implementations or discussions from established trading-development communities.

### C — Weak community evidence

Includes isolated claims, anecdotal reports or commercial claims without enough technical evidence.

### D — Engineering inference

A logical conclusion derived from stronger evidence, but not itself directly documented.

### E — EAGOLD project hypothesis

An internal design choice that must be tested empirically.

This hierarchy is a central control against accidental overstatement.

---

## 4. Methodological Principles

The research followed these principles:

1. **No invention presented as fact.**
2. **Current source code checked before proposing source-level changes.**
3. **Official platform capabilities separated from strategy behavior.**
4. **Community examples treated as evidence of feasibility, not proof of optimality.**
5. **Vendor behavior treated as design reference, not algorithmic truth.**
6. **Thresholds not supported by evidence kept open for calibration.**
7. **Architecture defined before optimization.**
8. **Hard constraints separated from objectives.**
9. **Execution result separated from execution request.**
10. **Post-execution state must be verified.**

---

# 5. Iteration 1 — Foundation Validation

The first iteration established the technical primitives.

## 5.1 Net Exposure

Validated as:

```text
NET = abs(BUY_LOTS - SELL_LOTS)
```

This is a direct consequence of directional volume aggregation.

**Status:** A / foundational.

## 5.2 Gross Exposure

Validated as:

```text
GROSS = BUY_LOTS + SELL_LOTS
```

It represents total open inventory and must not be confused with directional imbalance.

**Status:** A / foundational.

## 5.3 Margin

Established as a separate risk dimension rather than a synonym for exposure.

Relevant MQL4 account and market properties include margin, free margin, margin requirements and broker trading constraints.

**Status:** A.

## 5.4 Pair Reduction

Validated as technically feasible through MQL4 `OrderCloseBy()` where broker/symbol configuration permits it.

Important constraints identified:

- `MODE_CLOSEBY_ALLOWED`;
- unequal lot sizes;
- residual volume;
- broker lot rules;
- execution verification.

**Status:** A.

## 5.5 Volume Constraints

The correct volume controls are:

```text
MODE_MINLOT
MODE_LOTSTEP
MODE_MAXLOT
```

Invalid volume is associated with trade error 131.

**Status:** A.

## 5.6 Ticket Audit

`OrderSelect()` behavior and order-state inspection established the need to reselect and verify tickets rather than trusting stale position data.

**Status:** A.

---

# 6. Iteration 2 — Architectural Refinement

Iteration 2 tested the proposed higher-level concepts.

## 6.1 Basket Balance Score

A proposed weighted BBS formula was rejected.

Reason:

- no evidence for the formula;
- potential counterintuitive behavior;
- arbitrary weights;
- insufficient auditability.

Replacement:

```text
BASKET_STATE_VECTOR
```

containing position, hedge, economic, margin and recovery dimensions.

**Decision:** R10-C11 APPROVED — state vector; arbitrary BBS rejected.

## 6.2 Recovery Debt

No universal definition was found.

Decision:

- retain Recovery Debt as an EAGOLD internal abstraction;
- assign accounting ownership to R10.2;
- require R10 to publish reduction events instead of directly manipulating recovery accounting.

**Decision:** R10-C12 APPROVED — architectural separation.

## 6.3 Hedge Integrity

A fixed formula such as:

```text
NET_AFTER > NET_BEFORE * 1.50
```

was rejected because no adequate evidence supported the threshold.

Replacement:

```text
HEDGE_INTEGRITY = CONSTRAINT SET
```

**Decision:** approved conceptually; thresholds remain calibration items.

## 6.4 Smart Closure

The candidate architecture was validated:

```text
GENERATE
→ SIMULATE
→ ELIMINATE INVALID
→ RANK
→ EXECUTE
```

**Decision:** approved.

## 6.5 Reduction Score

The previously proposed 40/30/20/10 weighted score was rejected.

The replacement was:

```text
HARD CONSTRAINTS
→ LEXICOGRAPHIC OBJECTIVES
```

This avoids false precision before telemetry exists.

## 6.6 Simulation Before Execution

Approved as mandatory.

A candidate must have a measurable before/after state before execution.

**Decision:** approved.

---

# 7. Iteration 3 — Formal Boundary Validation

Iteration 3 resolved ownership and decision semantics.

## 7.1 Recovery Debt Lifecycle

The lifecycle was defined as an R10.2 concern:

```text
RECOVERY_IDLE
→ RECOVERY_ACTIVE
→ RECOVERY_PROGRESS
→ RECOVERY_CLEARED
```

R10 contributes reduction events but does not own debt accounting.

## 7.2 Smart Closure Ranking

The final ranking is lexicographic rather than weighted.

Priority order:

1. hard constraints;
2. directional safety;
3. gross exposure relief;
4. hedge integrity;
5. margin improvement;
6. recovery-state improvement;
7. economic result;
8. operational simplicity;
9. deterministic tie-break.

## 7.3 Context Boundary

R10 context was explicitly separated into:

### Operational context

- spread;
- Bid/Ask;
- broker capability;
- lot constraints;
- margin;
- trade permission;
- execution state;
- basket state.

### Market prediction

Indicators such as MACD, IFR, MMA and VWAP are not automatically R10 signals.

This prevents R10 from becoming a hidden trading strategy.

## 7.4 Failure Architecture

Execution failures were divided into:

```text
BLOCK
RETRY
ABORT
VERIFY
SUCCESS
```

This is superior to a binary success/failure model because execution errors have different operational meanings.

---

# 8. Iteration 4 — Formal Closure

Iteration 4 converted the architecture into an implementation-ready specification.

## 8.1 Mathematical state

The final state includes:

```text
BUY
SELL
NET
GROSS
HEDGE_VOLUME
HEDGE_RATIO
FLOATING_RESULT
MARGIN
FREE_MARGIN
MARGIN_LEVEL
RECOVERY_STATE
RECOVERY_DEBT
RECOVERY_REMAINING
RECOVERY_SURPLUS
```

## 8.2 Candidate contract

Every candidate receives a stable identity and explicit requested action.

## 8.3 Simulation contract

Every candidate receives a before/after comparison.

## 8.4 Hard constraints

The final constraint set covers:

- ownership;
- ticket validity;
- volume;
- minimum retained exposure;
- CloseBy capability;
- gross-exposure reduction;
- directional safety where required;
- hedge integrity;
- margin safety;
- no-new-exposure rule;
- recovery ownership boundary;
- idempotency.

## 8.5 Execution verification

The final contract requires:

```text
REQUEST
→ RETURN/ERROR
→ RESELECT
→ VERIFY
→ REBUILD BASKET
→ RECONCILE
→ EVENT
```

---

# 9. External Research Strategy

The research included three evidence classes of external material.

## 9.1 Official MQL4/MQL5 documentation

Used to establish what the platform technically supports, including:

- order selection;
- order closing;
- CloseBy;
- order profit/swap/commission;
- order history;
- account margin information;
- broker lot constraints;
- trading error codes.

These sources were treated as the strongest technical authority for platform behavior.

## 9.2 Community research

MQL5 community discussions and examples were used to identify established patterns involving:

- hedge management;
- basket management;
- partial close;
- profitable-position funding;
- CloseBy;
- recovery zones;
- staged recovery.

Community evidence established feasibility and common practice, but not optimality.

## 9.3 Commercial recovery systems

Public documentation from recovery-oriented products was examined for recurring architectural patterns:

- fragmentation;
- smart closure;
- hedge preservation;
- partial recovery;
- drawdown arming;
- broker lot fragmentation.

These patterns were explicitly treated as **design references**, not as proof that their algorithms are optimal for EAGOLD.

---

# 10. Rejected Concepts and Why

## 10.1 Arbitrary Basket Balance Score

Rejected due to lack of evidence and excessive compression of multiple risk dimensions into one number.

## 10.2 Arbitrary weighted Reduction Score

Rejected because numerical weights were not empirically justified.

## 10.3 Fixed 1.50x Hedge Integrity threshold

Rejected because the threshold was invented rather than evidenced.

## 10.4 Universal ATR 2.5x condition

Rejected because no adequate evidence established it as a universal R10 rule.

## 10.5 Automatic 50% reduction based on ATR

Rejected for the same reason.

## 10.6 Positive Grid inside R10

Rejected architecturally because it adds exposure rather than reducing existing exposure.

## 10.7 R10-owned Recovery Debt

Rejected because it creates duplicated accounting responsibility with R10.2.

## 10.8 R10-owned Recovery Step

Rejected because progression belongs to R11.

---

# 11. Current EAGOLD Baseline

The current EAGOLD source is v0.106 and already contains R10 controls and R10.2 recovery-cycle state.

Existing R10 configuration includes:

```text
EnableR10Reduce
R10MinExposureLots
EnableR10PairReduction
R10PairMinProfit
R10PairMaxLots
R10PairCooldownSeconds
```

The current source also contains exposure helpers based on BUY/SELL lot aggregation and an R10.2 equity-cycle model. The formal specification therefore extends a real existing architecture rather than defining an unrelated theoretical system.

---

# 12. Backtest Evidence Used in the Research

The 2026-09-09 backtest analysis was used as behavioral evidence.

Observed facts included:

- R10.2 HOLD states occurred frequently;
- R10 executed normal reductions and a pair reduction in the examined H1 run;
- R10.2 did not reach its configured realization target in the analyzed period;
- R11 actions occurred at shallow recovery level;
- ticket lifecycle anomalies were observed in the log.

The analysis produced an important methodological conclusion:

> **A backtest log cannot be interpreted only through final P/L. Event chronology and ticket lifecycle must also be reconstructed.**

This is why ticket auditing and state transition telemetry became mandatory components of the formal specification.

---

# 13. Telemetry Methodology

Telemetry must be event-oriented.

Required information includes:

```text
TIMESTAMP
ACTION_ID
CYCLE_ID
ACTION_TYPE
STATE_BEFORE
CANDIDATE_COUNT
SELECTED_CANDIDATE
CONSTRAINT_RESULT
EXECUTION_RESULT
ERROR_CODE
STATE_AFTER
NET_BEFORE
NET_AFTER
GROSS_BEFORE
GROSS_AFTER
HEDGE_BEFORE
HEDGE_AFTER
REALIZED_NET
RECOVERY_STATE
```

Repeated identical HOLD messages on every tick should not be the primary diagnostic mechanism.

The objective is to make each state transition reconstructable.

---

# 14. Validation Method

A change is not considered validated because:

- it compiles;
- it increases profit in one backtest;
- it reduces one drawdown episode;
- it produces visually attractive telemetry.

A change is considered validated only after it demonstrates:

1. correct behavior under controlled scenarios;
2. preservation of hard constraints;
3. deterministic decisions;
4. correct execution verification;
5. correct accounting boundaries;
6. acceptable backtest behavior;
7. out-of-sample robustness.

---

# 15. Test Methodology

The test matrix contains position, broker, risk, execution, accounting and determinism tests.

Minimum groups:

### Position

- directional imbalance;
- balanced hedge;
- empty basket;
- pair reduction.

### Broker

- minimum lot;
- lot step;
- maximum lot;
- CloseBy permission.

### Risk

- gross exposure increase;
- directional exposure increase;
- hedge destruction;
- margin violation.

### Execution

- successful close;
- failed close;
- duplicate action;
- stale ticket;
- residual volume.

### Accounting

- profit;
- loss;
- swap;
- commission;
- recovery-cycle event.

### Determinism

- multiple candidates;
- different enumeration order;
- tie-breaking.

---

# 16. Institutional Decision Record

The research concludes that the following statements are sufficiently established for the logical R10 contract:

### Approved

- R10 reduces existing exposure.
- Net and gross exposure are separate dimensions.
- Pair reduction is a valid technical mechanism when broker-supported.
- Broker volume constraints are hard constraints.
- Candidate simulation must precede execution.
- Hard constraints precede optimization.
- Lexicographic ranking is preferable to arbitrary weights at this stage.
- Execution must be verified against actual state.
- Ticket lifecycle must be auditable.
- R10.2 owns recovery accounting.
- R11 owns recovery progression.
- R10 must not create exposure merely to enable reduction.

### Open only for empirical calibration

- exact hedge thresholds;
- smart-closure thresholds;
- reduction granularity;
- cooldown values;
- advanced economic tie-breaks.

These are not architectural gaps.

---

# 17. Final Research Conclusion

The four-iteration process transformed R10 from a collection of proposed ideas into a controlled engineering specification.

The final conceptual model is:

```text
             BASKET STATE
                  ↓
        OPERATIONAL CONTEXT
                  ↓
        CANDIDATE GENERATION
                  ↓
              SIMULATION
                  ↓
          HARD CONSTRAINTS
                  ↓
       LEXICOGRAPHIC RANKING
                  ↓
             EXECUTION
                  ↓
             VERIFICATION
                  ↓
             RECONCILIATION
                  ↓
           REDUCTION EVENT
              ↙       ↘
           R10.2       R11
```

The research therefore declares:

> **R10 is logically closed and ready for controlled implementation.**

This declaration does **not** mean that every parameter is optimized. It means that the responsibilities, boundaries, state model, candidate architecture, constraints, execution contract, failure handling and validation methodology are sufficiently defined to begin engineering without relying on undocumented assumptions.

---

# 18. Next Engineering Gate

The next phase must be implementation and validation, not another conceptual redesign.

Recommended sequence:

```text
R10 FORMAL SPECIFICATION
        ↓
IMPLEMENTATION
        ↓
MT4 COMPILATION
        ↓
SCENARIO TESTS
        ↓
CONTROLLED BACKTEST
        ↓
TELEMETRY AUDIT
        ↓
OUT-OF-SAMPLE TEST
        ↓
PARAMETER CALIBRATION
```

Any proposed deviation from this specification should itself be documented as a change request with evidence and rationale.

---

## 19. Document Control

| Field | Value |
|---|---|
| System | EAGOLD |
| Engine | R10 |
| Document | Research Methodology and Validation Report |
| Version | 1.0 |
| Status | Final |
| Research iterations | 1–4 |
| Logical R10 status | Closed |
| Implementation status | Pending controlled implementation |
| Empirical parameter validation | Pending |

