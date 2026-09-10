# R10 Formal Execution Core v1.0

## Status

Implemented as an isolated MQL4 include module:

- `EA/R10_FORMAL_EXECUTION_CORE_v1.mqh`

The module formalizes the safety-critical portions of R10 without changing the existing EAGOLD v0.106 file in this commit.

## Pipeline

`MEASURE -> CLASSIFY -> CANDIDATE -> SIMULATE -> HARD CONSTRAINTS -> LEXICOGRAPHIC RANK -> EXECUTE -> VERIFY -> RECONCILE -> EVENT`

The module currently provides reusable primitives for:

1. Measuring BUY/SELL lots, net exposure, gross exposure and directional P/L.
2. Validating broker lot constraints.
3. Simulating balanced reduction before execution.
4. Simulating same-direction profit-funded pair reduction before execution.
5. Applying the hard rule that R10 must never increase net exposure.
6. Verifying post-execution exposure and gross-lot reduction.

## Critical correction validated during implementation

Pair reduction is a **same-direction** operation. Therefore its simulation cannot use the balanced-reduction formula.

For a BUY pair reduction:

`afterExposure = abs((BUY_LOTS - REDUCE_LOTS) - SELL_LOTS)`

For a SELL pair reduction:

`afterExposure = abs(BUY_LOTS - (SELL_LOTS - REDUCE_LOTS))`

The candidate is rejected before execution if this value would exceed the pre-action exposure.

## Validation

Static checks performed on the implementation:

- Balanced-bracket structural validation: PASS.
- Balanced-reduction mathematical cases: PASS.
- Pair-reduction mathematical cases: PASS, including rejection of a balanced-state pair that would increase exposure.
- Lot-step/min/max validation logic present: PASS.
- Post-execution exposure verification: PASS.

## Integration note

The current EAGOLD v0.106 remains untouched by this commit. This is deliberate: replacing the entire EA source through the repository interface would be a high-risk write operation and could reintroduce the truncation problem previously observed.

The next integration step is to include this module from `EA/EAGOLD.mq4`, route the existing `Rule10Reduce()` entry point through the formal execution core, then compile in MetaEditor/Strategy Tester and run the existing R10 regression scenarios.
