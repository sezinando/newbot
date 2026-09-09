# EAGOLD — R10 EXPOSURE REDUCTION ENGINE v1.0

## 1. Purpose

R10 — Exposure Reduction is the EAGOLD layer responsible for **reducing an already-existing exposure** in a controlled manner.

R10 is not a recovery engine and must not be treated as a mechanism that magically erases realized losses. Its primary purpose is to reduce risk, margin consumption, gross exposure and future recovery burden carried by the active cycle.

The central design principle is:

> **R10 reduces exposure; it does not create new exposure merely to justify a reduction.**

The current EAGOLD implementation already exposes R10 controls for general reduction, minimum exposure, pair reduction, minimum pair profit, maximum pair volume, cooldown and visual markers.

This document is the conceptual contract and implementation roadmap. It does not authorize code changes by itself.

---

## 2. Architectural Position

```text
R1  FIRST ENGINE
        |
        v
BUY / SELL lifecycle
        |
        +----------------+
        |                |
        v                v
R9 EXPOSURE        R10 EXPOSURE
CONTROLLER         REDUCTION
        |                |
        +--------+-------+
                 |
                 v
        R11 RECOVERY STEP
```

Responsibilities must remain separated:

- **R9** identifies/manages exposure conditions and hedge behavior.
- **R10** reduces existing exposure.
- **R11** controls recovery-step distance and progression.
- R10 must not silently become a second R9 or R11.

---

## 3. Current R10 Contract

### 3.1 Main switch

`EnableR10Reduce`

Enables or disables the R10 reduction engine.

### 3.2 Minimum exposure

`R10MinExposureLots`

Defines the minimum exposure level that R10 should preserve.

### 3.3 Pair reduction

`EnableR10PairReduction`

Allows R10 to use opposite BUY/SELL positions as a reduction mechanism.

### 3.4 Pair profitability requirement

`R10PairMinProfit`

Defines the minimum profitability condition required before a pair-reduction action is considered.

### 3.5 Pair volume limit

`R10PairMaxLots`

Limits the maximum volume processed by a pair-reduction operation.

### 3.6 Cooldown

`R10PairCooldownSeconds`

Prevents repeated pair-reduction actions from being executed too close together.

### 3.7 Visual telemetry

`EnableR10VisualMarker`, `R10MarkerFont`, `R10MarkerFontSize`, `R10BuyMarkerColor`, `R10SellMarkerColor`, `R10MarkerOffsetPoints`

Provide visual evidence that an R10 action occurred.

---

## 4. Core Risk Model

R10 must distinguish at least six concepts.

### 4.1 Net exposure

```text
NET_EXPOSURE = abs(BuyLots - SellLots)
```

Measures directional imbalance.

### 4.2 Gross exposure

```text
GROSS_EXPOSURE = BuyLots + SellLots
```

Measures total open directional inventory, including hedged positions.

### 4.3 Hedge volume / hedge ratio

```text
HEDGE_VOLUME = min(BuyLots, SellLots)
HEDGE_RATIO  = HEDGE_VOLUME / max(BuyLots, SellLots)
```

These describe how much of the dominant side is currently offset by the opposite side.

### 4.4 Recovery debt

**Recovery Debt** is a proposed EAGOLD abstraction representing the remaining problematic volume/economic burden that the active cycle still needs to resolve. It must not be treated as identical to monetary loss.

The implementation should eventually expose at least:

```text
R10_RECOVERY_DEBT
R10_HEDGE_VOLUME
R10_HEDGE_RATIO
```

### 4.5 Margin load

The engine should observe margin used and free margin remaining, preferably as a normalized load ratio as well as absolute account values.

### 4.6 Floating drawdown

R10 should observe floating P/L, including swap and commission where appropriate, rather than relying only on realized P/L.

### Important distinction

A BUY 1.00 + SELL 1.00 structure has approximately zero net exposure but 2.00 lots of gross exposure.

Therefore:

> **Net exposure reduction and gross exposure reduction are not the same operation.**

A pair reduction can reduce gross exposure while leaving net exposure unchanged.

---

## 5. What R10 Must Optimize

R10 should evaluate reduction quality using more than realized profit.

Preferred objectives:

1. Reduce gross exposure.
2. Reduce margin load.
3. Reduce future recovery requirement / recovery debt.
4. Reduce floating drawdown when economically possible.
5. Preserve enough structure for the lifecycle engine to continue operating.
6. Minimize spread, commission and slippage costs.
7. Avoid immediately recreating the exposure through another engine.
8. Preserve hedge integrity when the hedge is still required.

The term **Risk Relief** is proposed as a future R10 metric:

```text
RISK_RELIEF = improvement in risk/exposure state caused by the R10 action
```

It must not be equated automatically with profit.

A future conceptual score is:

```text
REDUCTION_SCORE =
      exposure_relief
    + margin_relief
    + drawdown_relief
    + recoverability
    - transaction_cost
    - spread_penalty
    - market_regime_penalty
```

Weights remain deliberately unfrozen until deterministic telemetry is validated.

---

## 6. Reduction Modes

### R10-A — Pair Reduction

Use opposite BUY/SELL exposure to reduce gross exposure.

Example:

```text
BUY  1.00
SELL 0.40

R10 pair reduction 0.40

BUY  0.60
SELL 0.00
```

When the broker/account configuration permits, MQL4 `OrderCloseBy()` is the native operation for closing an opened order by an opposite opened order.

### R10-B — Profit-Funded Reduction

Use qualifying profitable positions to finance a partial reduction of a losing position.

Concept:

```text
PROFITABLE POSITIONS
        |
        v
REDUCTION CAPITAL
        |
        v
LOSING POSITION
        |
        v
PARTIAL REDUCTION
```

This is closely related to the Smart Closure / profitable-order approach documented by Forex Recovery Bot and AW Close By Profitables.

This mechanism is a **design reference**, not a rule to copy directly into EAGOLD.

### R10-C — Basket Reduction

Future extension in which R10 evaluates the basket as a whole and realizes/reduces exposure when the overall state reaches a defined risk-relief condition.

This mode should be introduced only after R10-A and R10-B are validated.

---

## 7. Forex Recovery Bot — Research Findings

A dedicated research pass was performed on **Forex Recovery Bot**, its official helpdesk and public release notes. The software is relevant because it combines hedging, position fragmentation, recovery management and staged closure.

Official documentation describes a three-step process:

1. **Position Hedging** — hedge the volume of losing positions.
2. **Recovery Orders** — use Grid Recovery or Zone Recovery.
3. **Smart Position Recovery** — fragment positions into smaller pieces and progressively close recovery/hedge/original-loss components when profit targets are reached.

The documented example explicitly shows recovery orders, part of the hedge and part of the original losing order being closed together, then restarting the process for the remaining portion.

### 7.1 Idea adopted: Recovery Debt

The software's fragmentation model reinforces the idea that the system should reason about the **remaining burden** instead of treating the original losing position as one indivisible object.

EAGOLD should therefore eventually track:

```text
ORIGINAL PROBLEM VOLUME
        |
        +--> HEDGED VOLUME
        |
        +--> ALREADY REDUCED VOLUME
        |
        +--> REMAINING RECOVERY DEBT
```

This does not mean that every lot maps one-to-one to monetary debt. The term is an operational state variable.

### 7.2 Idea adopted: Smart Closure Threshold

Forex Recovery Bot documents a `Smart Closure Threshold` expressed as a percentage. For example, a threshold of 20 means the bot can act when it can close 20% of the total losing-order volume using profitable orders.

For EAGOLD, adopt the principle as a configurable minimum opportunity threshold:

```text
R10ReductionThresholdPct
```

The threshold should prevent meaningless micro-reductions and excessive transaction churn.

### 7.3 Idea adopted: Profit-funded staged reduction

The bot fragments the problem and uses available profitable recovery opportunities to close portions rather than requiring a single full recovery.

EAGOLD should evaluate this as **R10-B Profit-Funded Reduction**.

The important distinction is:

> A profitable operation can fund a reduction; it does not automatically mean the underlying economic loss has been recovered.

### 7.4 Idea adopted: Hedge Integrity

Forex Recovery Bot release notes explicitly mention improvements to ensure the hedge remains in place and to re-align the hedge after Smart Closure.

EAGOLD should therefore track:

```text
EXPECTED_HEDGE
ACTUAL_HEDGE
HEDGE_DEFICIT
HEDGE_SURPLUS
```

After every R10 action:

```text
EXECUTE
   |
   v
RECONCILE
   |
   v
RECALCULATE HEDGE INTEGRITY
```

### 7.5 Idea adopted: Hedge re-alignment

A reduction that is locally profitable can still leave the overall structure worse if it destroys too much hedge.

Therefore R10 must calculate the **post-action state** before accepting a candidate.

The question is not only:

> Can I close this?

It is:

> **What does the account/cycle risk look like after I close it?**

### 7.6 Idea adopted: Second hedge / protection escalation

Forex Recovery Bot release notes describe an optional second hedge when recovery trades are adding additional drawdown.

We should not copy this into R10. However, it suggests a useful observation state:

```text
R10_HEDGE_DEFICIT
R10_RECOVERY_DRAWdown_ACCELERATION
```

If protection becomes insufficient, R10 should signal the condition to the responsible exposure controller rather than opening its own hedge.

This preserves the R9/R10 separation.

### 7.7 Idea adopted: Broker lot fragmentation

Forex Recovery Bot documents splitting a hedge into smaller trades when the desired hedge exceeds the broker's maximum allowed lot.

This is useful as a generic execution utility:

```text
REQUEST = 1.37 lots
BROKER MAX = 1.00

EXECUTE:
1.00 + 0.37
```

For EAGOLD, this should be implemented as broker-compliant volume planning, not as an excuse to bypass exposure limits.

### 7.8 Idea adopted: Maximum recovery lot cap

Forex Recovery Bot exposes a maximum lot size for recovery trades.

This is valuable, but the responsibility belongs primarily to R11/recovery progression, not R10:

```text
R11_LOT_CAP
R11_GROSS_EXPOSURE_CAP
R11_MAX_RECOVERY_ORDERS
```

R10 may observe these limits but should not silently rewrite them.

### 7.9 Idea considered but rejected: Positive Grid

Forex Recovery Bot offers Positive Grid behavior that can add recovery trades while price is moving favorably.

This is **not adopted for R10**.

Reason:

> R10 is a risk-reduction engine. Opening additional exposure to accelerate recovery is a recovery/progression behavior, not exposure reduction.

Such behavior, if ever required, belongs in a separately controlled recovery layer.

### 7.10 Idea adapted: Trend/context filter

Forex Recovery Bot provides trend filtering and can limit additional recovery actions to the trend direction.

EAGOLD should adapt this idea to the existing context architecture rather than copy the vendor's indicator logic.

Potential context inputs:

```text
M5 / M15 regime
MMA21
MMA34
MACD
IFR
VWAP
Context Memory
```

Proposed control:

```text
R10_RECOVERY_DIRECTION_FILTER
```

If a recovery action is trying to increase exposure in a direction contradicted by the context, the action should be blocked or downgraded.

For pure R10 reduction, the context filter should mainly affect **candidate quality**, not create a new trading strategy.

### 7.11 Idea adopted: Drawdown-triggered arming

Forex Recovery Bot supports delayed recovery launch based on drawdown and floating-loss conditions.

EAGOLD can adapt this to R10 state management:

```text
LOW DD
  -> MONITOR

MODERATE DD
  -> ARMED

HIGH DD
  -> CONSERVATIVE RISK-RELIEF ONLY
```

The important principle is to avoid making R10 an always-active closure mechanism.

### 7.12 Idea adapted: One action per market event

Forex Recovery Bot documents controls that limit repeated recovery activity. EAGOLD should use a stronger event/idempotency model rather than blindly using one-trade-per-candle.

Proposed behavior:

```text
CANDIDATE
   |
EXECUTE
   |
RECONCILE
   |
ACTION_ID consumed
   |
COOLDOWN
```

Repeated ticks must not execute the same logical reduction twice.

---

## 8. Forex Recovery Architecture — What We Adopt and What We Reject

| Forex Recovery concept | EAGOLD decision | Destination |
|---|---|---|
| Initial hedge | Adopt as reference | R9 |
| Recovery Debt / remaining burden | **Adopt** | R10 observability |
| Smart Closure | **Adopt** | R10-B |
| Smart Closure Threshold | **Adopt** | R10-B |
| Partial/staged closure | **Adopt** | R10-A/R10-B |
| Hedge integrity | **Adopt** | R10 + R9 contract |
| Hedge re-alignment | **Adopt** | R10 reconciliation |
| Second hedge | Observe, do not implement in R10 | R9 future |
| Broker lot fragmentation | **Adopt** | execution utility |
| Maximum recovery lot | **Adopt conceptually** | R11 |
| Maximum recovery exposure | **Adopt conceptually** | R11/risk layer |
| Trend filter | **Adapt** | Context/R11 |
| Drawdown-triggered arming | **Adapt** | R10 state machine |
| One action per event | **Adapt** | R10 idempotency |
| Positive Grid | **Reject for R10** | none |
| New exposure solely to enable reduction | **Reject** | hard R10 rule |

---

## 9. Partial Close Principle

Partial closure is a key design reference for R10.

AW Recovery documentation explicitly describes splitting an unprofitable position into smaller portions and closing those portions independently. The stated rationale is to reduce account load and allow staged recovery.

Forex Recovery Bot similarly documents order fragmentation and progressive closure.

For EAGOLD:

> **Reduce in controlled increments instead of making a single irreversible reduction whenever the market and lifecycle state permit staged reduction.**

Volume must respect:

- broker minimum lot;
- lot step;
- maximum volume;
- minimum remaining volume;
- R10 minimum exposure;
- current margin condition;
- cycle ownership.

Never silently alter requested reduction in a way that changes strategy intent.

---

## 10. Candidate Selection

Future R10 versions should not simply select the largest winner or largest loser.

A candidate should be evaluated using:

- symbol;
- Magic Number;
- cycle ownership;
- ticket;
- direction;
- lots;
- open price;
- current price;
- floating P/L;
- age;
- distance from current market;
- opposite-side availability;
- spread;
- expected transaction cost;
- resulting net exposure;
- resulting gross exposure;
- resulting hedge ratio;
- resulting margin load;
- resulting floating drawdown;
- recovery debt before/after;
- context/regime.

A future **Reduction Score** is proposed:

```text
REDUCTION_SCORE =
      exposure_relief
    + margin_relief
    + drawdown_relief
    + recoverability
    + hedge_integrity
    - transaction_cost
    - spread_penalty
    - market_regime_penalty
```

The formula is intentionally conceptual. Numerical weights must be calibrated from telemetry before being frozen.

---

## 11. Execution Pipeline

Recommended R10 execution contract:

```text
1. DETECT
   |
   v
2. MEASURE CURRENT RISK
   |
   v
3. CHECK OWNERSHIP / CYCLE
   |
   v
4. FIND CANDIDATES
   |
   v
5. RANK CANDIDATES
   |
   v
6. SIMULATE POST-ACTION STATE
   |
   v
7. CHECK SPREAD / COST
   |
   v
8. CHECK LOT RULES
   |
   v
9. CHECK MARGIN / SAFETY
   |
   v
10. EXECUTE ONE REDUCTION
   |
   v
11. RECONCILE ORDERS
   |
   v
12. RECHECK HEDGE INTEGRITY
   |
   v
13. WRITE R10 LEDGER
   |
   v
14. ENTER COOLDOWN
```

The engine must execute one logically atomic reduction decision at a time and reconcile account state before another reduction.

---

## 12. R10 State Machine — Proposed

```text
IDLE
 |
 v
ARMED
 |
 v
CANDIDATE_FOUND
 |
 v
VALIDATING
 |       \
 |        +--> BLOCKED
 v
EXECUTING
 |
 v
RECONCILING
 |
 +--> SUCCESS --> COOLDOWN --> IDLE
 |
 +--> FAILED  --> COOLDOWN / BLOCKED
```

Future risk states may be exposed explicitly:

```text
R10_CONSERVATIVE
R10_BALANCED
R10_RECOVERY_AWARE
```

These are states, not trading modes, and should not be implemented as fixed magic behavior until validated.

---

## 13. Cooldown and Idempotency

The existing `R10PairCooldownSeconds` is directionally correct but should eventually be complemented by an action identity.

Recommended identity:

```text
symbol + MagicNumber + cycle_id + ticket_a + ticket_b + reduction_volume
```

The same logical reduction must not execute twice because multiple ticks observed the same condition.

Persistent state may use terminal Global Variables or another durable mechanism.

The MQL4 community also uses persistent flags/state for partial-close workflows so that a completed reduction is not repeated on subsequent ticks.

---

## 14. R10 Reduction Ledger

A dedicated telemetry record should be created for every R10 action.

Recommended fields:

```text
Timestamp
Symbol
MagicNumber
CycleID
Mode
ActionID
TicketA
TicketB
DirectionA
DirectionB
LotsBeforeA
LotsBeforeB
LotsReducedA
LotsReducedB
LotsAfterA
LotsAfterB
ProfitBefore
ProfitRealized
FloatingPLBefore
FloatingPLAfter
GrossExposureBefore
GrossExposureAfter
NetExposureBefore
NetExposureAfter
HedgeBefore
HedgeAfter
RecoveryDebtBefore
RecoveryDebtAfter
MarginBefore
MarginAfter
Spread
ContextState
Reason
Result
BrokerError
```

Example:

```text
R10 | PAIR_REDUCTION
BUY #12345
SELL #12352
reduced=0.10
GROSS 1.20 -> 1.00
NET   0.40 -> 0.40
HEDGE 0.40 -> 0.30
MARGIN 420 -> 385
RESULT=SUCCESS
```

The ledger is an essential part of R10 because a reduction must be evaluated by its actual post-action effect, not only by whether an order-close API call returned success.

---

## 15. Non-Interference Rules

R10 must not:

- open a new recovery position solely to enable a reduction;
- increase lot size as a recovery mechanism;
- modify R1 rules;
- modify R11 step parameters directly;
- override broker lot constraints;
- ignore margin safety;
- repeatedly act on the same candidate without reconciliation;
- operate on another EA's Magic Number;
- use another cycle's positions without explicit ownership rules;
- claim that realized reduction equals recovery of an already-realized loss;
- destroy a required hedge without explicitly evaluating the post-action hedge state.

Magic Number and cycle ownership are hard boundaries unless a future explicit cross-Magic contract is approved.

---

## 16. Important Economic Constraint

Reducing both sides of a locked hedge does **not** automatically erase an existing monetary loss.

Example:

```text
BUY  1.00  = -$100
SELL 1.00  = +$100
```

Reducing both sides by 0.50 reduces volume but does not magically transform historical/economic loss into a smaller loss merely by arithmetic symmetry.

Therefore R10 must distinguish:

```text
EXPOSURE RELIEF
```

from:

```text
LOSS RECOVERY
```

This distinction is mandatory in implementation and telemetry.

---

## 17. Risk Controls

R10 should observe at least:

```text
Gross Exposure
Net Exposure
Hedge Volume
Hedge Ratio
Recovery Debt
Floating Drawdown
Margin Used
Free Margin
Spread
Lot Step
Minimum Lot
Maximum Lot
Cycle Exposure
Context / Regime
```

Future hard gates should include:

- maximum gross exposure;
- maximum net exposure;
- maximum margin load;
- maximum floating drawdown;
- maximum number of R10 actions per cycle;
- minimum time between reductions;
- maximum reduction volume per action;
- minimum reduction threshold;
- hedge integrity threshold;
- session restrictions if required.

Risk management should be separated from strategy logic. Account-level drawdown and margin conditions are more important than treating each individual order in isolation.

---

## 18. Proposed R10 Evolution Roadmap

### R10 v1 — Current foundation

- general reduction;
- minimum exposure;
- pair reduction;
- pair minimum profit;
- maximum pair lots;
- cooldown;
- visual marker.

### R10 v2 — Observability

Add:

- Gross Exposure;
- Net Exposure;
- Hedge Volume;
- Hedge Ratio;
- Recovery Debt;
- Margin Load;
- Floating Drawdown;
- Reduction Ledger;
- action identity/idempotency.

### R10 v3 — Robust Pair Engine

Add:

- candidate ranking;
- post-action simulation;
- `OrderCloseBy()` where appropriate;
- partial-volume normalization;
- post-execution reconciliation;
- stronger broker-error handling;
- hedge-integrity validation.

### R10 v4 — Profit-Funded / Smart Closure

Add:

- profitable-position selection;
- loss-position selection;
- available-profit budget;
- Smart Closure threshold;
- partial reduction;
- cycle ownership rules;
- profit-funding ledger.

### R10 v5 — Smart Risk Relief

Evaluate:

- spread;
- volatility;
- trend/regime;
- margin pressure;
- drawdown;
- future recovery requirement;
- hedge integrity;
- Reduction/Risk-Relief Score.

ML should not be introduced before deterministic R10 telemetry and baseline behavior are validated.

---

## 19. Testing Contract

R10 must be tested with controlled scenarios before optimization.

### Test A — Neutral hedge

```text
BUY 1.00
SELL 1.00
```

Expected: pair reduction can reduce gross exposure while net exposure remains near zero.

### Test B — Directional imbalance

```text
BUY 1.00
SELL 0.40
```

Expected: reduction of the opposite pair decreases both gross and net exposure.

### Test C — Insufficient profit

Candidate pair does not satisfy `R10PairMinProfit`.

Expected: no action.

### Test D — Lot-step violation

Requested reduction is not compatible with broker lot step.

Expected: no unsafe silent adjustment.

### Test E — Cooldown / idempotency

Two identical opportunities arrive on consecutive ticks.

Expected: only one action.

### Test F — Reconciliation

Broker execution changes ticket/remaining volume.

Expected: R10 refreshes state before another decision.

### Test G — Magic isolation

Another EA has profitable positions.

Expected: EAGOLD R10 ignores them unless an explicit future cross-Magic contract exists.

### Test H — Margin pressure

Free margin approaches configured safety boundary.

Expected: R10 becomes more conservative rather than increasing exposure.

### Test I — Hedge integrity

A candidate reduction would destroy more hedge than permitted.

Expected: candidate is blocked or downgraded.

### Test J — Smart Closure threshold

Profit is sufficient to reduce only 10% of the losing volume while threshold is 20%.

Expected: no Smart Closure.

When the opportunity reaches 20% or more and all risk checks pass:

Expected: candidate becomes executable.

### Test K — Post-action risk relief

Compare before/after:

```text
Gross Exposure
Net Exposure
Hedge Ratio
Margin Load
Floating DD
Recovery Debt
```

Expected: every successful R10 action has an auditable before/after state.

### Test L — Broker maximum lot

Requested operation exceeds broker maximum volume.

Expected: execution planner fragments the volume or blocks safely; it must never exceed broker constraints.

---

## 20. Design Principles Adopted From External Research

### Principle 1 — Partial reduction is preferable to blind full closure when staged recovery is appropriate

AW Recovery and Forex Recovery Bot both document fragmentation/partial closure as a way to reduce account load and progressively resolve problematic positions.

### Principle 2 — Profit from one position can be deliberately used to reduce another losing position

AW Close By Profitables demonstrates a dedicated utility pattern for selecting profitable orders capable of covering a losing order.

### Principle 3 — A minimum opportunity threshold prevents trivial Smart Closure actions

Forex Recovery Bot documents a Smart Closure percentage threshold. EAGOLD adopts the principle, not the vendor's exact parameters.

### Principle 4 — Hedge integrity must be checked after reduction

Forex Recovery Bot release notes explicitly mention ensuring the hedge remains in place and re-aligning it after Smart Closure.

### Principle 5 — Recovery debt should be represented as a state, not assumed to equal monetary loss

Fragmented recovery architectures work with remaining portions of the problem. EAGOLD formalizes this as Recovery Debt while preserving the economic distinction between exposure and loss.

### Principle 6 — Broker volume limits must be treated as execution constraints

Recovery systems must fragment volumes when broker maximum lot size is exceeded. EAGOLD should perform this deterministically and transparently.

### Principle 7 — Drawdown can be used to arm more conservative risk behavior

Forex Recovery Bot supports drawdown/floating-loss based activation. EAGOLD adapts this into R10 states rather than copying recovery behavior.

### Principle 8 — Trend/context should constrain new recovery exposure

Forex Recovery Bot documents trend filtering. EAGOLD should integrate this with its existing M5/M15/context architecture if future recovery logic needs it.

### Principle 9 — Risk reduction and loss recovery are different objectives

Closing or reducing hedged volume does not retroactively erase realized economic loss. R10 must report exposure relief separately from recovery P/L.

### Principle 10 — Positive Grid is not an R10 responsibility

Opening new positions while price moves favorably may accelerate recovery, but it increases exposure. That contradicts R10's risk-reduction contract.

---

## 21. Sources

### Forex Recovery Bot

1. **Forex Recovery Bot — How Forex Recovery Bot Works**
   https://knowledgebase.forexrecoverybot.com/en/article/how-forex-recovery-bot-works-hjjm0k/
   Official helpdesk. Documents position hedging, Grid/Zone Recovery, order fragmentation and Smart Position Recovery.

2. **Forex Recovery Bot — Input Settings Guide**
   https://knowledgebase.forexrecoverybot.com/en/article/input-settings-guide-1f13j0g/
   Official helpdesk. Documents Smart Closure, Smart Closure Threshold, recovery-close settings, positive-grid settings and other configuration concepts.

3. **Forex Recovery Bot — Release Notes & Changelog**
   https://knowledgebase.forexrecoverybot.com/en/article/release-notes-changelog-1hckb4f/
   Official helpdesk. Documents second-hedge behavior, hedge integrity, hedge re-alignment, broker maximum-lot fragmentation and recovery max-lot safety improvements.

4. **Forex Recovery Bot — Settings & Usage**
   https://knowledgebase.forexrecoverybot.com/en/category/settings-usage-1ax0nk/
   Official helpdesk index for configuration and operational documentation.

### AW Trading Software / MQL5

5. **AW Recovery EA — MQL5 Market**
   https://www.mql5.com/en/market/product/49453
   Developer product page. Documents locking losing positions, splitting positions, partial closing, delayed launch, trend filtering and recovery behavior.

6. **AW Recovery EA — What's New / Changelog**
   https://www.mql5.com/en/market/product/49453/updates
   Public release history; useful for identifying how the developer evolved locking and volume normalization.

7. **AW Close By Profitables — MQL5 Market**
   https://www.mql5.com/en/market/product/28258
   Developer utility that selects losing orders and profitable orders capable of covering them, with Magic Number, symbol, direction and profit-selection controls.

8. **AW Close By Profitables — Comments**
   https://www.mql5.com/en/market/product/28258/comments
   Public developer/user discussion clarifying that maximum profitable-order count is a cap on the number used to cover a loss, not a minimum trigger count.

9. **AW Trading Software — Developer profile**
   https://www.mql5.com/en/users/nechaevrealle
   Public developer profile and product references.

### Official MQL4 documentation

10. **MQL4 Reference — OrderCloseBy**
    https://docs.mql4.com/trading/ordercloseby
    Official documentation for closing one opened order by an opposite opened order.

11. **MQL4 Reference — OrderClose**
    https://docs.mql4.com/trading/orderclose
    Official documentation for closing an order, including partial requested volume.

### MQL4/MQL5 community and engineering references

12. **MQL5 Forum — Partial Close / OrderCloseBy discussion**
    https://www.mql5.com/en/forum/202961
    Community discussion of partial-close mechanics and persistent state/idempotency considerations.

13. **MQL5 Forum — Hedged partial-close economics discussion**
    https://www.mql5.com/en/forum/468416
    Useful economic caution: reducing equal portions of hedged positions reduces volume but does not magically erase already-realized loss.

14. **MQL5 — Risk management / centralized risk-control literature**
    https://www.mql5.com/en/articles/21720
    MetaQuotes article on centralized risk control, account-wide exposure, explicit risk decisions and auditability.

15. **MQL5 — Adaptive risk during drawdown**
    https://www.mql5.com/en/articles/23638
    MetaQuotes material supporting drawdown-aware reduction of risk rather than fixed exposure.

16. **MQL5 — Daily loss / drawdown circuit breaker**
    https://www.mql5.com/en/articles/23732
    Supports real-time floating P/L and hard risk gates.

17. **MQL5 — Position closing manager / risk separation**
    https://www.mql5.com/en/articles/17608
    Reference for separating position-closing/risk-management responsibilities from strategy logic.

18. **GitHub — dingmaotu/mql4-lib Order abstraction**
    https://github.com/dingmaotu/mql4-lib/blob/master/Trade/Order.mqh
    Open-source MQL4 order abstractions including close-by/hedge and partial-close handling patterns.

---

## 22. Final Architectural Recommendation

The research strengthens, rather than changes, the core EAGOLD architecture:

```text
R9 = EXPOSURE / HEDGE CONTROL

R10 = EXPOSURE REDUCTION
      |
      +-- Observability
      +-- Recovery Debt
      +-- Hedge Integrity
      +-- Pair Reduction
      +-- Smart / Profit-Funded Reduction
      +-- Basket Reduction
      +-- Risk Relief Score

R11 = RECOVERY STEP / PROGRESSION
```

The implementation sequence should be:

```text
PHASE 1
Observability
  ↓
PHASE 2
Recovery Debt + Hedge Integrity
  ↓
PHASE 3
Robust Pair Reduction
  ↓
PHASE 4
Smart Closure / Profit-Funded Reduction
  ↓
PHASE 5
Context-aware Risk Relief
```

The strongest idea obtained from Forex Recovery Bot is not its grid or recovery sizing. It is the **fragmentation of the recovery problem into measurable portions**, combined with **Smart Closure**, **hedge re-alignment**, and explicit thresholds.

The strongest idea obtained from AW Recovery / AW Close By Profitables is the deliberate use of profitable positions to reduce losing exposure, under strict ownership and selection rules.

The EAGOLD implementation should combine these principles without turning R10 into another martingale/grid engine.

> **Final rule: R10 may reduce risk; R10 may use profit to fund a reduction; R10 must never increase exposure merely because recovery is difficult.**
