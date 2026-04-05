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
- [Bayesian Inference](#bayesian-inference-via-hamiltonian-monte-carlo-hmc)
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
- Frequency (how often floods occur)
- Severity (how extreme they are)

Both components are modeled probabilistically, with full uncertainty propagation.

---

## Why Bayesian?

This project did not begin as a Bayesian model.

The initial approach was a Monte Carlo simulation using point estimates and confidence intervals. While this produced reasonable outputs, uncertainty was not being handled coherently. Confidence intervals were applied after estimation rather than integrated into the generative process.

This raised a key issue: extreme value problems are fundamentally driven by uncertainty, especially in the tail, yet parameters were treated as fixed.

The shift to a Bayesian approach addressed this directly.

Instead of single estimates, parameters are treated as distributions. This allows uncertainty in frequency (λ) and severity (σ, ξ) to propagate naturally into simulated outcomes. In particular, uncertainty in the shape parameter (ξ) is explicitly represented.

The result is not just a model that fits historical data, but one that represents a range of plausible futures, including unobserved extremes.

The goal is not to eliminate uncertainty, but to model it explicitly and propagate it through the system.

---

## Model Structure

Flood risk is modeled as two components:

### Frequency

$$
N \sim \text{Poisson}(\lambda), \quad \lambda \sim \text{Gamma}(\alpha_\lambda, \beta_\lambda)
$$

Posterior estimate:  
λ ≈ 1.55 events/year (95% CI: [1.15, 2.00])

---

### Severity

$$
X_i \mid \sigma, \xi \sim \text{GPD}(0, \sigma, \xi), \quad X_i = Q_{\text{peak},i} - u
$$

Posterior estimates:
- σ ≈ 13.2 (95% CI: [10.1, 17.2])
- ξ ≈ -0.12 (95% CI: [-0.35, 0.10])

---

## Data Sources

- Water Survey of Canada (HYDAT), Don River at Todmorden (1961–2023)  
- Environment Canada water level data (rating curve construction)

---

## Event Definition & Declustering

Threshold:

$$
u_{\text{physical}} = 40 \, \text{m}^3/\text{s}
$$

- Events defined as continuous exceedances
- 3-day dry period separates events

Result:
- 53 independent flood events
- Mean frequency ≈ 1.56 events/year

---

## Threshold Selection

Two thresholds:

- Physical threshold ($u_{\text{physical}}$): flood onset
- Statistical threshold (p99.9): GPD validity

This preserves both physical meaning and statistical correctness.

---

## Frequency Model

Poisson assumption:
- Events are rare
- Independence after declustering

Gamma prior ensures:
- positivity
- flexible uncertainty

Result: frequency is stable and well-identified.

---

## Severity Model

GPD justified by extreme value theory.

### Parameters
- σ: scale of exceedances
- ξ: tail behavior

Prior:

$$
\xi \sim \mathcal{N}(-0.3, 0.3)
$$

---

## Bayesian Inference via Hamiltonian Monte Carlo (HMC)

The posterior distributions for all model parameters are estimated using Hamiltonian Monte Carlo (HMC) as implemented in `cmdstanr`.

Rather than relying on closed-form solutions, the model uses numerical sampling to approximate:

$$
p(\lambda, \sigma, \xi \mid \text{data})
$$

---

### Sampling Setup

- Number of chains: 4  
- Warmup iterations: 1000  
- Sampling iterations: 2000 per chain  
- Total posterior draws: 8000 per parameter (before diagnostics filtering)

---

### Why HMC

HMC is used because:

- It efficiently explores high-dimensional, correlated posterior spaces  
- It avoids random-walk behavior seen in basic MCMC  
- It is well-suited for hierarchical and non-linear models like the Poisson–GPD structure

This is particularly important for the shape parameter (ξ), which exhibits weak identifiability and strong posterior curvature in the tail region.

---

### Diagnostics and Model Validity

Model validity is assessed using:

- $\hat{R}$ convergence diagnostics  
- Effective sample size (ESS)  
- Divergent transition checks  
- Trace stability across chains  

Only converged posterior draws are carried forward into predictive simulation.

---

### Role in the Pipeline

HMC forms the inference layer of the model:

1. Data informs likelihood (Poisson + GPD structure)  
2. HMC samples parameter posterior distributions  
3. Posterior draws are passed into Monte Carlo simulation  
4. Forward simulations generate predictive flood distributions  

This separation ensures that uncertainty is fully propagated from parameter estimation into downstream risk metrics.

---

## Posterior Predictive Checks (PPCs)

### Frequency
- Observed: 1.56/year  
- Simulated: ~1.61/year  

Good calibration.

---

### Severity
- Observed mean: 13.4, max: 68  
- Simulated max: ~188  

Central behavior matches; tails diverge.

---

### Key Insight: Tail Uncertainty

ξ is weakly identified due to limited extreme observations.

Posterior range:
ξ ∈ [-0.35, 0.10]

Implications:
- ξ < 0 → bounded tail  
- ξ > 0 → heavy tail  

This is not model failure — it is explicit uncertainty in extreme behavior.

---

## Loss Function (Current)

$$
\text{Loss} = \alpha (Q_{\text{peak}} - u)^\beta
$$

Simplified proxy.

Limitations:
- no depth modeling
- no exposure
- no infrastructure vulnerability

---

## Monte Carlo Simulation

Each iteration:
1. Sample λ → event count
2. Sample σ, ξ → severity
3. Simulate flows
4. Aggregate annual loss

10,000 simulations used.

Both:
- aleatory uncertainty
- epistemic uncertainty

are propagated.

---

## Current Limitations

### 1. Tail Uncertainty (ξ)
Weak identification due to sparse extremes.

### 2. No Physical Loss Model
Flow → Depth → Damage → Loss is missing.

### 3. Stationarity
Assumes constant climate and infrastructure.

---

## Structural Roadmap

- V1: Bayesian Poisson + GPD
- V1.1: improve ξ stability
- V1.5: threshold refinement
- V2: non-stationary climate model
- V2+: spatial + parent–child structure

---

## Key Philosophy

- Uncertainty is explicit, not hidden
- Model structure > parameter fitting
- Physical interpretability matters
- Model represents futures, not just history

---

**Summary:**  
A baseline Bayesian extreme value model with full uncertainty propagation. Strong on structure and transparency, but future work must focus on tail stability, physical loss modeling, and non-stationarity.

---

*Last updated: April 2026*
