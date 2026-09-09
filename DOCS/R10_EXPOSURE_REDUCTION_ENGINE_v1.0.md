# EAGOLD — R10 EXPOSURE REDUCTION ENGINE v1.0

## 1. Purpose

R10 — Exposure Reduction is the EAGOLD layer responsible for **reducing an already-existing exposure** in a controlled manner.

R10 is not a recovery engine and must not be treated as a mechanism that magically erases realized losses. Its primary purpose is to reduce the amount of risk, margin consumption and future recovery burden carried by the active cycle.

The central design principle is:

> **R10 reduces exposure; it does not create new exposure merely to justify a reduction.**

The current EAGOLD implementation already exposes R10 controls for general reduction, minimum exposure, pair reduction, minimum pair profit, maximum pair volume, cooldown and visual markers.

---

## 2. Architectural Position

R10 belongs to the EAGOLD lifecycle as an exposure-management layer:

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
- **R11** controls recovery-step distance.
- R10 must not silently become a second R9 or R11.

---

## 3. Current R10 Contract

### 3.1 Main switch

`EnableR10Reduce`

Enables or disables the R10 reduction engine.

### 3.2 Minimum exposure

`R10MinExposureLots`

Defines the minimum exposure level that R10 should preserve. The engine must not blindly reduce below the configured safety boundary.

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

R10 must distinguish at least four different concepts.

### 4.1 Net exposure

```text
NET_EXPOSURE = abs(BuyLots - SellLots)
```

This measures directional imbalance.

### 4.2 Gross exposure

```text
GROSS_EXPOSURE = BuyLots + SellLots
```

This measures the total amount of open directional inventory, including hedged positions.

### 4.3 Margin load

The engine should observe the amount of account margin consumed by the current structure and the free margin remaining.

### 4.4 Floating drawdown

R10 should observe floating P/L, including swap and commission where appropriate, rather than relying only on realized P/L.

### Important distinction

A BUY 1.00 + SELL 1.00 structure has approximately zero net exposure but 2.00 lots of gross exposure.

Therefore:

> **Net exposure reduction and gross exposure reduction are not the same operation.**

A pair reduction can reduce gross exposure while leaving net exposure unchanged.

---

## 5. What R10 Must Optimize

R10 should evaluate reduction quality using more than realized profit.

The preferred objectives are:

1. Reduce gross exposure.
2. Reduce margin load.
3. Reduce future recovery requirement.
4. Reduce floating drawdown when economically possible.
5. Preserve enough structure for the lifecycle engine to continue operating.
6. Minimize spread, commission and slippage costs.
7. Avoid immediately recreating the exposure through another engine.

The term **Risk Relief** is proposed as a future R10 metric:

```text
RISK_RELIEF = improvement in risk/exposure state caused by the R10 action
```

It should not be equated automatically with profit.

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

This reduces gross exposure and changes net exposure.

When the account/broker configuration permits, MQL4 `OrderCloseBy()` is the native operation for closing an opened order by an opposite opened order.

Reference: MQL4 `OrderCloseBy` documentation.

### R10-B — Profit-Funded Reduction

Use realized/available profit from qualifying profitable positions to finance a partial reduction of a losing position.

Concept:

```text
PROFITABLE POSITIONS
        |
        v
RECOVERY / REDUCTION CAPITAL
        |
        v
LOSING POSITION
        |
        v
PARTIAL REDUCTION
```

This concept is documented by AW Trading Software's `AW Close By Profitables`, which selects profitable positions capable of covering a losing position and uses that profit to close an unprofitable order or group of orders.

This mechanism is a **design reference**, not a rule to copy directly into EAGOLD.

### R10-C — Basket Reduction

Future extension in which R10 evaluates the basket as a whole and realizes/reduces exposure when the overall state reaches a defined risk-relief condition.

This mode must be introduced only after R10-A is validated.

---

## 7. Partial Close Principle

Partial closure is a key design reference for R10.

AW Recovery documentation describes splitting an unprofitable position into smaller portions and closing those portions independently. The stated rationale is to reduce account load, preserve free funds and avoid requiring large one-shot recovery volumes.

For EAGOLD, the principle should be adapted as:

> **Reduce in controlled increments instead of making a single irreversible reduction whenever the market and lifecycle state permit staged reduction.**

The volume must respect:

- broker minimum lot;
- lot step;
- maximum volume;
- minimum remaining volume;
- R10 minimum exposure;
- current margin condition.

Never silently alter the requested reduction in a way that changes strategy intent.

---

## 8. Candidate Selection

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
- resulting margin load;
- resulting floating drawdown.

A future **Reduction Score** is proposed:

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

The formula is intentionally conceptual at v1.0. It must be calibrated from EAGOLD telemetry before numerical weights are frozen.

---

## 9. Execution Pipeline

Recommended future R10 execution contract:

```text
1. DETECT
   |
   v
2. MEASURE CURRENT RISK
   |
   v
3. FIND CANDIDATES
   |
   v
4. RANK CANDIDATES
   |
   v
5. CHECK SPREAD / COST
   |
   v
6. CHECK LOT RULES
   |
   v
7. CHECK MARGIN / SAFETY
   |
   v
8. EXECUTE ONE REDUCTION
   |
   v
9. RECONCILE ORDERS
   |
   v
10. WRITE R10 LEDGER
   |
   v
11. ENTER COOLDOWN
```

The engine must execute one logically atomic reduction decision at a time and reconcile the account state before attempting another reduction.

---

## 10. R10 State Machine — Proposed

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
 |        \--> BLOCKED
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

This state machine is recommended to prevent multiple reductions from being triggered by repeated ticks before the broker/account state has been reconciled.

---

## 11. Cooldown and Idempotency

The existing `R10PairCooldownSeconds` is directionally correct but should eventually be complemented by an action identity.

Recommended identity:

```text
symbol + MagicNumber + cycle_id + ticket_a + ticket_b + reduction_volume
```

The same logical reduction must not execute twice because multiple ticks observed the same condition.

Persistent state may use terminal Global Variables or another durable mechanism.

The MQL4 community explicitly recommends persistent flags/state when an EA needs to remember that a partial-close operation has already been executed.

---

## 12. R10 Reduction Ledger

A dedicated telemetry record should be created for every R10 action.

Recommended fields:

```text
Timestamp
Symbol
MagicNumber
CycleID
Mode
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
MarginBefore
MarginAfter
Spread
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
MARGIN 420 -> 385
RESULT=SUCCESS
```

The ledger is considered an important part of R10 because a reduction must be evaluated by its actual effect, not only by whether an order-close API call returned success.

---

## 13. Non-Interference Rules

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
- claim that realized reduction equals recovery of an already-realized loss.

A key lesson from public discussion around profitable-order utilities is that Magic Number and ownership filtering must be treated as hard boundaries. Public user feedback on AW Close By Profitables has also highlighted the danger of unintended cross-Magic processing.

---

## 14. Important Economic Constraint

Reducing both sides of a locked hedge does **not** automatically erase an existing monetary loss.

Example:

```text
BUY  1.00  = -$100
SELL 1.00  = +$100
```

Reducing both sides by 0.50 reduces volume but does not transform the historical/economic loss into -$50 merely by arithmetic symmetry.

Therefore R10 must distinguish:

```text
EXPOSURE RELIEF
```
from:

```text
LOSS RECOVERY
```

This distinction is mandatory in the implementation and telemetry.

---

## 15. Risk Controls

R10 should observe at least:

```text
Gross Exposure
Net Exposure
Floating Drawdown
Margin Used
Free Margin
Spread
Lot Step
Minimum Lot
Maximum Lot
Cycle Exposure
```

Future hard gates should include:

- maximum gross exposure;
- maximum net exposure;
- maximum margin load;
- maximum floating drawdown;
- maximum number of R10 actions per cycle;
- minimum time between reductions;
- maximum reduction volume per action;
- session restrictions if required.

The broader MQL5 risk-management literature supports separating risk controls from strategy logic and using drawdown-aware behavior rather than treating every trade identically.

---

## 16. Proposed R10 Evolution Roadmap

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
- Hedge Ratio;
- Margin Load;
- Floating Drawdown;
- Reduction Ledger;
- action identity/idempotency.

### R10 v3 — Robust Pair Engine

Add:

- candidate ranking;
- `OrderCloseBy()` where appropriate;
- partial-volume normalization;
- post-execution reconciliation;
- stronger broker-error handling.

### R10 v4 — Profit-Funded Reduction

Add:

- profitable-position selection;
- loss-position selection;
- available-profit budget;
- partial reduction;
- cycle ownership rules.

### R10 v5 — Smart Reduction

Evaluate:

- spread;
- volatility;
- trend/regime;
- margin pressure;
- drawdown;
- future recovery requirement;
- Reduction/Risk-Relief Score.

ML should not be introduced before deterministic R10 telemetry and baseline behavior are validated.

---

## 17. Testing Contract

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

### Test E — Cooldown

Two identical opportunities arrive on consecutive ticks.

Expected: only one action.

### Test F — Reconciliation

Broker execution changes ticket/remaining volume.

Expected: R10 refreshes state before another decision.

### Test G — Magic isolation

Another EA has profitable positions.

Expected: EAGOLD R10 ignores them unless an explicit future cross-Magic contract exists.

### Test H — Margin pressure

Free margin approaches the configured safety boundary.

Expected: R10 becomes more conservative rather than increasing exposure.

---

## 18. Design Principles Adopted From External Research

### Principle 1 — Partial reduction is preferable to blind full closure when the strategy requires staged recovery

AW Recovery explicitly describes partial closure as a way to reduce account load and preserve free funds.

### Principle 2 — Profit from one position can be used deliberately to reduce another losing position

AW Close By Profitables demonstrates this as a dedicated utility pattern.

### Principle 3 — `OrderCloseBy()` is a native MT4 mechanism for opposite-position closure

The official MQL4 documentation defines `OrderCloseBy()` specifically for closing one opened order by another opposite opened order.

### Principle 4 — Risk management should be separated from strategy logic

MetaQuotes risk-management material recommends dedicated risk/capital management rather than assuming each EA's isolated backtest drawdown represents account-level risk.

### Principle 5 — Drawdown-aware behavior is preferable to fixed exposure during deteriorating account conditions

Recent MQL5 material demonstrates adaptive risk reduction as equity drawdown increases.

### Principle 6 — R10 must not confuse risk reduction with loss erasure

Reducing hedge volume changes future exposure; it does not retroactively change realized economic loss.

---

## 19. Sources

1. **MetaQuotes / MQL4 Reference — OrderCloseBy**
   https://docs.mql4.com/trading/ordercloseby
   Official MQL4 documentation for closing an opened order by an opposite opened order.

2. **MetaQuotes / MQL4 Reference — OrderClose**
   https://docs.mql4.com/trading/orderclose
   Official MQL4 documentation for partial-volume order closure.

3. **AW Trading Software Limited — AW Recovery EA**
   https://www.mql5.com/en/market/product/49453
   Developer documentation describing partial closure, locking, recovery orders and reduction of losing positions.

4. **AW Trading Software Limited — AW Recovery comments**
   https://www.mql5.com/en/market/product/49453/comments/page17
   Developer discussion describing splitting losing positions into smaller parts and partial closure to reduce account load.

5. **AW Trading Software Limited — AW Recovery parameter guidance**
   https://www.mql5.com/en/market/product/49453/comments/page14
   Developer guidance concerning `Part to close from a loss-making position` and relationship with averaging-order volume.

6. **AW Trading Software Limited — AW Close By Profitables**
   https://www.mql5.com/en/market/product/28258
   Developer utility that selects profitable positions to cover unprofitable positions.

7. **MQL5 Forum — Hedging EA, close losing positions with profitable trades?**
   https://www.mql5.com/en/forum/295570
   Community discussion explicitly pointing to `OrderCloseBy()` for hedge-based closing.

8. **MQL5 Forum — Partial closing of position**
   https://www.mql5.com/en/forum/202961
   Community discussion describing partial closure through opposite orders and `OrderCloseBy()`, including persistent-state considerations.

9. **MQL5 Forum — Feedback on logic to handle a hedge**
   https://www.mql5.com/en/forum/468416
   Discussion highlighting the distinction between reducing hedge volume and actually reducing an already-realized monetary loss.

10. **MetaQuotes — Risk and capital management using Expert Advisors**
    https://www.mql5.com/en/articles/11500
    Discussion of account-level risk, drawdown and dedicated capital/risk management.

11. **MetaQuotes — Building Your Personal Expert Advisor, Part 2: Risk Management and Dynamic Lot Sizing**
    https://www.mql5.com/en/articles/23638
    Recent article demonstrating drawdown-aware reduction of risk/exposure and broker-constraint validation.

12. **MetaQuotes — Implementing a Daily Loss Limit and Drawdown Circuit Breaker in MQL5**
    https://www.mql5.com/en/articles/23732
    Recent risk-management work emphasizing real-time floating P/L, hard limits and reliable risk gates.

13. **MetaQuotes — Developing a Multi-Currency Expert Advisor, Part 28: Adding a Position Closing Manager**
    https://www.mql5.com/en/articles/17608
    Example of separating position-closing and risk-management responsibilities into dedicated modules.

---

## 20. Final EAGOLD Recommendation

Do not replace the current R10 implementation immediately.

The preferred development sequence is:

```text
CURRENT R10
    |
    v
OBSERVABILITY
    |
    +-- Gross Exposure
    +-- Net Exposure
    +-- Margin Load
    +-- Floating DD
    +-- Reduction Ledger
    |
    v
ROBUST PAIR REDUCTION
    |
    v
PROFIT-FUNDED REDUCTION
    |
    v
SMART RISK-RELIEF ENGINE
```

The first implementation milestone should therefore be **R10 Observability**, not a more aggressive recovery algorithm.

Only after the telemetry proves what each R10 action actually does to exposure, margin, floating drawdown and future recovery burden should numerical optimization or adaptive decision rules be introduced.

This document defines the conceptual contract and research-backed roadmap. It does **not** authorize changing the production EAGOLD code by itself.
