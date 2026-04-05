# Statistical Methodology

This document outlines the statistical framework underlying the Don River Flood Risk Model.

---

## Table of Contents

- [Overview](#overview)
- [Why Bayesian?](#why-bayesian)
- [Model Structure](#model-structure)
- [Data Sources](#data-sources)
- [Event Definition & Declustering](#event-definition--declustering)
- [Threshold Selection](#threshold-selection)
- [Frequency Model](#frequency-model)
- [Severity Model](#severity-model)
- [Posterior Predictive Checks (PPCs)](#posterior-predictive-checks-ppcs)
- [Loss Function](#loss-function-current)
- [Monte Carlo Simulation](#monte-carlo-simulation)
- [Current Limitations](#current-limitations)
- [Structural Roadmap](#structural-roadmap)
- [Key Philosophy](#key-philosophy)

---

## Overview

**Problem:** Canada lacks an accessible, unified flood risk modeling framework, while existing catastrophe models are proprietary and costly.

**Approach:** A transparent Bayesian extreme value model that decomposes flood risk into:
- **Frequency** (how often floods occur)
- **Severity** (how extreme they are)

Both components are modeled probabilistically, with full uncertainty propagation into downstream simulations.

---

## Why Bayesian?

This project did not begin as a Bayesian model.

The initial approach was a Monte Carlo simulation using point estimates and confidence intervals. While this produced reasonable outputs, it became clear that the uncertainty was not being handled coherently. Confidence intervals were applied after estimation, rather than being integrated into the data-generating process itself.

**This raised a key issue:**  
extreme value problems are fundamentally driven by uncertainty, especially in the tail, yet the modeling framework treated parameters as fixed.

The shift to a Bayesian approach addressed this directly.

Instead of relying on single estimates, parameters are treated as distributions. This allows uncertainty in frequency (λ) and severity (σ, ξ) to propagate naturally into simulated flood outcomes. In particular, uncertainty in the shape parameter (ξ) is explicitly represented, rather than hidden behind point estimates.

The result is not just a model that fits historical data, but one that captures a range of plausible future scenarios, including events that have not yet been observed.

**This perspective is central to the project:**  
the goal is not to eliminate uncertainty, but to model it explicitly and carry it through the entire system.

---

## Model Structure

Flood risk is modeled as two components:

### Frequency
\[
N \sim \text{Poisson}(\lambda), \quad \lambda \sim \text{Gamma}(\alpha_\lambda, \beta_\lambda)
\]

- Posterior estimate: **λ ≈ 1.55 events/year** \([1.15, 2.00]\)

---

### Severity
\[
X_i \mid \sigma, \xi \sim \text{GPD}(0, \sigma, \xi), \quad X_i = Q_{\text{peak},i} - u
\]

- Posterior estimates:
  - **σ ≈ 13.2** \([10.1, 17.2]\)
  - **ξ ≈ -0.12** \([-0.35, 0.10]\)

---

## Data Sources

- **Primary:** Water Survey of Canada (HYDAT), Don River at Todmorden (1961–2023)  
- **Secondary:** Environment Canada water level data (rating curve construction)

---

## Event Definition & Declustering

- **Threshold:** \(u_{\text{physical}} = 40 \, \text{m}^3/\text{s}\)  
- **Event definition:** Continuous exceedance of threshold  
- **Declustering rule:** 3 consecutive days below threshold separates events  

**Result:**  
- 53 independent flood events  
- Mean frequency ≈ 1.56 events/year  

---

## Threshold Selection

Two thresholds are used:

- **Physical threshold (\(u_{\text{physical}}\))**
  - Represents onset of real-world flood damage  
  - Chosen based on observed flood behavior  

- **Statistical threshold (\(u_{\text{statistical}}\))**
  - Set at p99.9  
  - Ensures validity of GPD asymptotics  

This separation preserves both **physical interpretability** and **statistical correctness**.

---

## Frequency Model

The Poisson model assumes:
- Floods are rare relative to daily observations  
- Events are independent after declustering  

The Gamma prior:
- Ensures positivity  
- Provides a flexible, weakly informative structure  

**Result:** Frequency is well-identified and stable across posterior samples.

---

## Severity Model

The GPD is used based on the Pickands–Balkema–de Haan theorem, which shows that exceedances over a high threshold converge to a GPD.

### Parameter Interpretation
- **σ (scale):** magnitude of typical exceedances  
- **ξ (shape):** tail behavior  

### Prior for ξ
\[
\xi \sim \mathcal{N}(-0.3, 0.3)
\]

Motivation:
- Reflects physically bounded flood behavior  
- Allows limited probability of heavy tails  

---

## Posterior Predictive Checks (PPCs)

Posterior predictive simulations evaluate whether the model can reproduce observed data.

### Frequency
- Observed: 1.56 events/year  
- Simulated: mean ≈ 1.61  

**Result:** Strong agreement → frequency model is well-calibrated  

---

### Severity
- Observed: mean 13.4, p95 42.2, max 68  
- Simulated: mean 14.4, p95 42.9, max 188  

**Result:**  
- Central behavior well captured  
- Extreme tail significantly wider  

---

### Key Insight: Tail Uncertainty

The model generates extremes beyond observed data. This is expected:

- The shape parameter ξ is weakly identified due to limited extreme observations  
- Posterior range: \([-0.35, 0.10]\)

Implications:
- Negative ξ → bounded tail  
- Positive ξ → heavy, unbounded tail  

The model reflects this uncertainty explicitly rather than collapsing it into a single estimate.

---

## Loss Function (Current)

\[
\text{Loss} = \alpha \cdot (Q_{\text{peak}} - u)^\beta
\]

- Simple power-law proxy  
- Calibrated using limited historical data  

**Limitation:**  
This is a placeholder and does not capture:
- depth  
- spatial exposure  
- infrastructure vulnerability  

Not suitable for decision-making in its current form.

---

## Monte Carlo Simulation

Each simulated year:
1. Sample λ → draw event count \(N\)  
2. Sample σ, ξ → simulate exceedances  
3. Convert exceedances to flow and loss  
4. Aggregate annual losses  

Repeated 10,000 times to produce a distribution of outcomes.

**Key principle:**  
Both **aleatory** and **epistemic uncertainty** are propagated through the system.

---

## Current Limitations

### 1. Tail Uncertainty (ξ)
- Weakly identified due to limited extreme data  
- Sensitive to prior assumptions  

---

### 2. No Physical Loss Mapping
- Model outputs flow (m³/s), not impact  
- Missing pipeline:
\[
\text{Flow} \rightarrow \text{Depth} \rightarrow \text{Damage} \rightarrow \text{Loss}
\]

---

### 3. Stationarity Assumption
- Assumes constant parameters over time  
- Ignores climate, land use, and infrastructure changes  

---

## Structural Roadmap

**V1 (Current):**
- Bayesian Poisson + GPD  
- Posterior predictive validation  
- Monte Carlo simulation  
- Proxy loss function  

---

**V1.1 (Next):**
- Improve ξ robustness (priors, sensitivity)  
- Introduce depth–damage relationships  

---

**V1.5:**
- Detect non-stationarity  
- Refine thresholds  

---

**V2:**
- Climate-driven non-stationary models  
- Rainfall-conditioned severity  
- Partial physical flood mapping  

---

**V2+:**
- Stochastic Parent–child event structure  
- Spatial modeling  
- Full hazard-to-loss pipeline  

---

## Key Philosophy

- **Uncertainty is explicit** — wide credible intervals reflect reality  
- **Modular design** — each component can be improved independently  
- **Physical grounding** — assumptions tied to hydrology, not just statistical fit  
- **Forward-looking** — model represents plausible futures, not just past observations  

---

**Summary:**  
The current model provides a statistically sound baseline for flood frequency and severity, with transparent uncertainty quantification. However, meaningful risk estimation requires improvements in tail identification, physical interpretation, and economic mapping.

---

*Last updated: April 2026. V1 baseline.*
