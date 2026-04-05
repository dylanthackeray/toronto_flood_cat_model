# Statistical Methodology

This document describes the statistical framework for the Don River Flood Risk Model.

## Overview

**Problem:** Canada has no national flood map. Catastrophe models that price flood risk are expensive and closed-source.

**Solution:** A transparent Bayesian extreme value model that estimates flood frequency and severity with full uncertainty quantification.

Separate flood risk into two independent components:
- **Frequency (λ):** Poisson(λ) with Gamma prior. Result: λ ≈ 1.55 events/year [95% CI: 1.15–2.00]
- **Severity (σ, ξ):** GPD with priors σ ~ Gamma(2, 0.1), ξ ~ N(-0.3, 0.3). Result: σ ≈ 13.2 m³/s, ξ ≈ -0.12

## Data Sources

**Primary:** Water Survey of Canada (HYDAT), Don River at Todmorden (02HC024), 1961–2023

**Secondary:** Environment Canada water level data 2002–2023 (rating curve construction)

## Event Definition & Declustering

**Definition:** Continuous period where daily discharge exceeds u_physical = 40 m³/s

**Declustering rule:** 3 consecutive days below threshold = separate events

**Result:** 34 years with events, 53 total independent events, mean 1.56 events/year

## Threshold Selection

**Physical threshold (u_physical = 40 m³/s):** Flow level where water leaves channel and causes damage
- Sits above p99.9 (52.5 m³/s)
- Mean Q_peak of documented floods: 53.4 m³/s
- Yields 54 independent events after declustering (practical minimum ~50)

**Statistical threshold (u_statistical):** p99.9 of all observations. Where GPD math applies.

## Frequency Model

$$N \sim \text{Poisson}(\lambda), \quad \lambda \sim \text{Gamma}(\alpha_\lambda, \beta_\lambda)$$

**Why Poisson?** Floods rare (2-5% of days), many daily opportunities, events independent after declustering.

**Why Gamma prior?** Strictly positive, conjugate to Poisson, parameterized by mean/variance.

**Posterior:** λ ≈ 1.55 events/year [1.15, 2.00], R-hat < 1.01

**PPC result:** Posterior predictive mean matches observed (1.56 → 1.61 events/year)

## Severity Model

$$X_i | \sigma, \xi \sim \text{GPD}(0, \sigma, \xi), \quad X_i = Q_{\text{peak},i} - u_{\text{statistical}}$$

**Why GPD not GEV?** GEV discards multi-event years. GPD models exceedances—the right quantity after threshold definition. Pickands-Balkema-de Haan theorem justifies this.

**Parameters:**
- σ (scale): Typical exceedance size above threshold
- ξ (shape): Tail weight (positive = unbounded, negative = bounded)

**Prior for ξ:** N(-0.3, 0.3)
- Physical reasoning: Floodplain dissipation and Toronto infrastructure suggest bounded tail
- Allows slightly negative ξ, consistent with physical upper bound on floods

**Posterior:** σ ≈ 13.2 [10.1, 17.2], ξ ≈ -0.12 [-0.35, 0.10], R-hat < 1.01


## Posterior Predictive Checks

### Frequency
- Observed: 1.56 events/year
- Simulated (500 draws): mean 1.61, range 0–6
- **✓ Central tendency matches well**

### Severity
- Observed: mean 13.4, p95 42.2, max 68 m³/s
- Simulated (806 draws): mean 14.4, p95 42.9, max 188 m³/s
- **✓ Central quantiles excellent, tail wide (expected for EVT with sparse extremes)**

**Key finding:** Posterior predictive max (188 m³/s) is 2.8× observed (68 m³/s). This is **correct behavior**—EVT predicts beyond observed extremes. The range is wide because ξ is weakly identified (only 54 extremes), creating posterior credible interval [-0.35, +0.10]:
- ξ ≈ -0.35 → physical max ~75 m³/s
- ξ ≈ +0.10 → unbounded
- Model captures this uncertainty honestly rather than hiding it

## Loss Function

**Approach:** Proxy power-law function: $\text{Loss} = \text{scale} \times (Q_{\text{peak}} - u)^{\text{exponent}}$

**Status:** This is the weakest part of V1. Calibrated to Hurricane Hazel 1954 (sparse data). Scale parameter treated as uncertain with its own prior to propagate calibration uncertainty.

**Not suitable for decision-making** without depth-damage curves from literature.

## Monte Carlo Simulation

**Each simulated year:**
1. Draw λ from posterior → N ~ Poisson(λ)
2. Draw σ, ξ from posteriors
3. For each of N floods: X ~ GPD(σ, ξ), Q_peak = X + u, Loss = f(Q_peak)
4. Sum annual losses
5. Repeat 10,000 times

**Why sample posteriors?** Propagates both aleatory (natural randomness) and epistemic (estimation uncertainty) into final credibility bands.

## Current Limitations

### 1. Tail Uncertainty in ξ
- Weakly identified with 54 extremes
- Posterior sensitive to prior assumptions
- Mitigation (V1.1): sensitivity analysis on ξ priors, literature priors, identifiability diagnostics

### 2. No Flow-to-Impact Link
Model outputs m³/s, not economic loss. Missing: depth → inundation → exposure → loss
- V1.1: depth-damage curves from literature
- V1.5: LiDAR-based depth mapping
- V2: hydraulic model

### 3. Stationarity Assumption
Assumes constant λ, σ, ξ over 1961–2023 and future. Ignores climate change, urban development, infrastructure.
- V1.5: trend detection, changepoint analysis
- V2: non-stationary Poisson(λ(t)) with climate/rainfall covariates
- V2+: parent-child framework

## Structural Roadmap

**V1 (Current):** ✓ Poisson + GPD fitted, ✓ PPCs, ✓ Monte Carlo pipeline, ⚠ Proxy loss

**V1.1:** ξ robustness, loss pipeline, depth-damage curves

**V1.5:** Non-stationarity diagnostics, trend tests, threshold refinement

**V2:** Non-stationary frequency model, rainfall-conditional GPD, partial hydraulic model

**V2+:** Parent-child climate framework, spatial model, upstream-downstream correlation

## Key Philosophy

- **Honest uncertainty:** Tall credible intervals rather than false precision
- **Modular improvement:** V1 is stationary baseline; each component upgraded independently
- **Bayesian reasoning:** Explicit priors force clear thinking about constraints
- **Physical grounding:** Thresholds and priors justified by hydrology, not just data optimization

10,000 Monte Carlo samples from posterior (λ, σ, ξ) = 10,000 plausible flood seasons = distribution of what we know and don't know about future risk.

---

*Last updated: April 2026. V1 baseline.*
