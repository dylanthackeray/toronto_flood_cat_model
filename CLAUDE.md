# CLAUDE.md

## Project: Don River Flood Risk Model

This is an open-source Bayesian flood risk model for Toronto’s Don River.

The goal is to build a **transparent, modular catastrophe modeling framework** that estimates flood risk with full uncertainty quantification, without relying on proprietary insurance models.

---

## Core Philosophy

- Uncertainty is **explicit**, not hidden
- Model structure is prioritized over overfitting
- Components are **modular and independently improvable**
- Outputs should represent **plausible futures**, not just historical replication
- All assumptions should be **defensible and physically grounded**

---

## Current Architecture (V1)

The model is structured into three layers:

### 1. Flow Rate Model (Hazard Layer)

Split into two independent Bayesian components:

#### Frequency Model
- Distribution: Poisson(λ)
- Prior: Gamma
- Data: annual event counts (declustered)
- Inference: HMC via `cmdstanr`

#### Severity Model
- Distribution: Generalized Pareto (GPD)
- Parameters: σ (scale), ξ (shape)
- Prior:
  - σ ~ Gamma
  - ξ ~ Normal(-0.3, 0.3)
- Data: exceedances above threshold
- Inference: HMC via `cmdstanr`

⚠️ These models are **fit independently**, NOT jointly.

---

### 2. Inference Layer

- Two separate HMC samplers:
  - One for λ
  - One for (σ, ξ)
- 4 chains, 1000 warmup, 2000 sampling
- Diagnostics:
  - R-hat
  - ESS
  - divergence checks

Output:
- Posterior samples for λ, σ, ξ

---

### 3. Simulation Layer (Monte Carlo)

Forward simulation pipeline:

1. Sample λ → simulate number of events (Poisson)
2. Sample σ, ξ → simulate exceedances (GPD)
3. Convert to flow: Q_peak = X + u
4. Apply loss function (currently proxy)
5. Aggregate annual loss
6. Repeat thousands of times

This produces a **distribution of possible flood seasons**.

---

## Current Posterior Estimates (V1 — STALE, needs re-fit)

> ⚠️ These estimates are from a **buggy V1 fit** and should not be used as reference.
> Three issues were corrected in the model that will shift posteriors:
> 1. Frequency data was zero-truncated (only 34 active years passed to Stan, not all 63).
>    This inflated λ from the true rate ~0.86 to ~1.55.
> 2. GPD ξ had `<lower=-0.3>` hard constraint, truncating the Normal(-0.3,0.3) prior at its
>    mean. Prior replaced with Normal(-0.1,0.2), upper-only constraint at 0.5.
> 3. Neither model had generated_quantities for LOO-CV.
> Re-run `03_model_dataset.R` then `05_run_bayesian_pipeline.R` to get corrected posteriors.

| Parameter | Old (buggy) mean | Expected direction after fix |
|-----------|-----------------|------------------------------|
| λ (events/yr) | 1.55 | ↓ toward ~0.86 (true rate) |
| σ (GPD scale) | 13.2 | approximately stable |
| ξ (GPD shape) | -0.12 | may shift, wider CI with correct prior |

- Threshold: u_physical = 40 m³/s
- Data: 63 years (1961–2023), 54 independent declustered flood events

⚠️ ξ is weakly identified — posterior spans both bounded (ξ < 0) and unbounded (ξ > 0) tails. Prior-sensitive. Always flag this when proposing severity model changes.

---

## Current Limitations (IMPORTANT)

### 1. Tail Uncertainty (ξ)
- Weakly identified
- Highly sensitive to prior
- Main source of extreme variability

### 2. No Physical Loss Mapping
Current pipeline:
Flow → (direct) Loss ❌

Missing:
Flow → Depth → Spatial Impact → Exposure → Loss

### 3. Stationarity Assumption
- λ, σ, ξ assumed constant over time
- No climate or rainfall covariates yet

---

## Roadmap

### V1.1 (Immediate Priority)
- Improve ξ stability
- Prior sensitivity analysis
- Introduce depth-damage curves (basic)

### V1.5
- Detect non-stationarity
- Trend analysis
- Threshold refinement

### V2
- Non-stationary Poisson (λ(t))
- Rainfall-linked severity
- Begin physical flood mapping

### V2+
- Parent–child stochastic model
- Climate → rainfall → flood hierarchy
- Spatial modeling
- Full hazard → loss pipeline

---

## Folder Structure (Important)

- `data/`
  - raw and processed data
  - includes stored `.rds` model outputs

- `models/`
  - `flow_rate_model/`
    - `frequency_model/`
    - `severity_model/`

  - `loss_model/`
    - loss simulation functions

- `scripts/`
  - data prep
  - fitting scripts
  - analysis notebooks (PPCs)

---

## Key Modeling Assumptions

- Floods follow a Poisson process after declustering
- Exceedances follow a GPD (Pickands–Balkema–de Haan)
- Frequency and severity are **independent (for now)**
- Threshold selection is valid for asymptotic EVT behavior
- Loss model is currently a **placeholder**

---

## What Claude Should Help With

Claude should assist with:

- Improving statistical modeling structure
- Debugging R / Stan code
- Designing new model components
- Ensuring Bayesian correctness
- Suggesting better priors and diagnostics
- Helping evolve the architecture toward V2

---

## What Claude Should NOT Do

- Do not oversimplify the model into basic regressions
- Do not remove Bayesian structure for convenience
- Do not assume the current model is “final”
- Do not ignore uncertainty propagation

---

## Style Guidelines

- Be concise but precise
- Prioritize clarity over jargon
- Maintain consistency with Bayesian terminology
- Keep outputs reproducible
- Avoid unnecessary abstraction

---

## Long-Term Vision

This project aims to become:

- A fully open catastrophe model
- A research-grade Bayesian risk framework
- A modular system that can incorporate:
  - climate change
  - spatial flood dynamics
  - insurance-level loss modeling

---

## Summary

This is not just a statistical model.

It is a **full probabilistic pipeline**:

Data → Bayesian inference (HMC) → Simulation → Risk distribution

Claude should treat this as a **serious, evolving modeling system**, not a one-off analysis.