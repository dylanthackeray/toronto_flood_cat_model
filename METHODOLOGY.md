# Statistical Methodology

This document describes the statistical framework underlying the Don River Flood Risk Model.

---

## Table of Contents

- [Overview](#overview)
- [Why Bayesian?](#why-bayesian)
- [Data Sources](#data-sources)
- [Event Definition and Declustering](#event-definition-and-declustering)
- [Threshold Selection](#threshold-selection)
- [Frequency Model](#frequency-model)
- [Severity Model](#severity-model)
- [Inference via HMC](#inference-via-hamiltonian-monte-carlo)
- [Model Validation](#model-validation)
- [Loss Function](#loss-function)
- [Monte Carlo Simulation](#monte-carlo-simulation)
- [Current Limitations](#current-limitations)
- [Structural Roadmap](#structural-roadmap)

---

## Overview

**Problem:** Canada lacks an accessible, unified flood risk modeling framework. Existing catastrophe models are proprietary and costly.

**Approach:** A transparent Bayesian extreme value model that decomposes flood risk into frequency and severity, both modeled probabilistically with full uncertainty propagation through the simulation layer.

---

## Why Bayesian?

The initial approach used Monte Carlo simulation with point estimates and confidence intervals. While this produced outputs, uncertainty was not handled coherently — confidence intervals were applied after estimation rather than integrated into the generative process.

Extreme value problems are fundamentally driven by uncertainty, particularly in the tail. Treating parameters as fixed obscures this. The Bayesian approach addresses this directly: instead of single estimates, parameters are treated as distributions. Uncertainty in λ, σ, and ξ propagates naturally into simulated outcomes, producing a range of plausible futures rather than a replication of historical data.

The result is not just a model that fits observed data, but one that represents the full range of outcomes under the inferred process — including unobserved extremes.

---

## Data Sources

| Source | Description |
|---|---|
| Water Survey of Canada (HYDAT) | Daily discharge at Don River — Todmorden (02HC024), 1961–2023 |
| Environment Canada Water Office | Water level data 2002–2023, used for rating curve construction |

---

## Event Definition and Declustering

Flood events are identified as periods of continuous exceedance above the physical threshold, with independent events separated by a minimum dry period.

**Declustering parameters:**
- Physical threshold: u = 40 m³/s
- Minimum dry-day separation: 3 days (conservative for the Don River's fast-responding urban catchment)

**Result:** 54 independent flood events over 63 years (1961–2023).

The declustering algorithm (`R_functions/declustering.R`) walks through the daily flow record chronologically, tracking active events and resetting when the dry-period criterion is met. It captures Q_peak, duration, volume above threshold, and event dates for each independent event.

---

## Threshold Selection

Two thresholds are relevant to the model:

**Physical threshold (u_physical = 40 m³/s)**
Defined as the flow level at which the Don River leaves the channel and produces real-world damage. Justified through three independent approaches:

1. Rating curve extrapolation (log-linear, to estimated flood stage at 14.0m local datum)
2. Cross-referencing against documented flood dates (HYDAT discharge on known flood events)
3. Flow percentile analysis (40 m³/s exceeds the p99.9 of daily flows)

At u = 40 m³/s, mean Q_peak = 53.4 m³/s across events — consistent with observed flood damage range. Raising to u = 45 m³/s drops event count to 35, below the practical minimum for reliable GPD estimation.

**Statistical threshold (p99.9)**
The asymptotic GPD approximation requires exceedances to be sufficiently far into the tail. The p99.9 of the exceedance distribution serves as a diagnostic check. At u = 40 m³/s, this condition is satisfied.

---

## Frequency Model

Annual flood event counts are modeled as a Poisson process:

$$N_t \sim \text{Poisson}(\lambda), \quad \lambda \sim \text{Gamma}(2, 2)$$

**Why Poisson:** Events are rare and occur independently after declustering. The Poisson process is the natural model for independent arrivals.

**Prior — Gamma(2, 2):** Mean = 1 event/year, variance = 0.5. Centered near the observed Don River rate (~0.86 events/year at u = 40 m³/s). Informative enough to regularize with limited data but diffuse enough for the likelihood to dominate with 63+ years of record.

**Data requirement:** The frequency dataset must include **all** years of record, including zero-event years. Passing only active years fits a zero-truncated Poisson and inflates λ. See V1.1 corrections below.

---

## Severity Model

Flow exceedances above u follow a Generalized Pareto Distribution, justified by the Pickands–Balkema–de Haan theorem: for sufficiently high thresholds, excesses over threshold converge in distribution to a GPD regardless of the parent distribution.

$$X_i \mid \sigma, \xi \sim \text{GPD}(0, \sigma, \xi), \quad X_i = Q_{\text{peak},i} - u$$

**Parameters:**
- σ (scale): characteristic magnitude of exceedances
- ξ (shape): tail behavior — negative implies bounded tail, positive implies heavy tail

**Priors:**

$$\sigma \sim \text{Gamma}(2, 0.1) \quad \text{(mean = 20, weakly informative)}$$

$$\xi \sim \mathcal{N}(-0.1, 0.2), \quad \xi < 0.5$$

The ξ prior follows Martins & Stedinger (2001), who demonstrate through simulation studies that an informative prior centered slightly negative significantly reduces shape parameter bias for small flood samples. The upper constraint at 0.5 is a physical requirement: above this value, the distribution has infinite variance and standard MLE asymptotics break down. No lower hard constraint is imposed — the GPD likelihood becomes −∞ when ξ < −σ/max(x), so the data directly constrains the lower tail.

**Why no hard lower bound:** The earlier V1 model used `<lower=-0.3>` with prior Normal(-0.3, 0.3). Because the hard bound was at the prior mean, Stan's constrained parameterization silently cut the left half of the prior, making the effective prior a one-sided distribution. The posterior was prior-sensitive in ways not intended. Removing the lower bound restores the correct Normal(-0.1, 0.2) prior and allows the likelihood to govern the lower tail.

---

## Inference via Hamiltonian Monte Carlo

Posterior distributions are estimated via HMC using `cmdstanr`. The two models are fit independently:

- Poisson model → posterior over λ
- GPD model → joint posterior over (σ, ξ)

This modular structure keeps inference interpretable and computationally stable, at the cost of not modeling any correlation between frequency and severity (a known limitation, planned for V2).

**Sampling configuration:**

| Setting | Value |
|---|---|
| Chains | 4 |
| Warmup iterations | 1000 |
| Sampling iterations | 2000 per chain |
| Total posterior draws | 8000 per parameter |

**Diagnostics:** R-hat (convergence), ESS (effective sample size), divergent transitions. Only models with R-hat < 1.01 and zero divergences are accepted.

**Generated quantities:** Both Stan models include a `generated_quantities` block that outputs:
- `log_lik[N]` — pointwise log-likelihood for LOO cross-validation via the `loo` package
- `y_rep[N]` / `n_rep[T]` — posterior predictive draws for PPC

---

## Model Validation

### MCMC diagnostics

Trace plots and R-hat values confirm convergence for all parameters. The shape parameter ξ shows higher posterior variance than σ and λ — expected, as tail behavior is weakly identified by 54 observations.

### Posterior predictive checks

Observed and simulated distributions are compared on:
- Event count histograms (frequency model)
- Exceedance histograms (severity model)
- Empirical survival function vs. simulated (log scale, to assess tail behavior)
- Distribution of simulated 99th percentile vs. observed

Central behavior is well-captured. Tail divergence in the severity model reflects uncertainty in ξ, not model misspecification.

### LOO cross-validation

The `loo` package (Vehtari et al., 2024) is used to compute Pareto-smoothed importance sampling LOO (PSIS-LOO) for both models. Pareto-k diagnostics identify influential observations. Values k > 0.7 indicate observations where the LOO estimate is unreliable and warrant investigation.

---

## Loss Function

**Current (placeholder):**

$$\text{Loss} = \alpha \cdot (Q_{\text{peak}} - u)^\beta$$

This is a direct power-law mapping from exceedance flow to loss with no physical intermediate steps. The parameters α and β are uncalibrated. This function produces unitless outputs and is not suitable for decision-relevant risk quantification.

**Required pipeline (V1.1):**

$$Q_{\text{peak}} \rightarrow \text{Depth} \rightarrow \text{Inundation extent} \rightarrow \text{Exposure} \rightarrow \text{Loss (\$)}$$

This requires depth-damage curves from the literature (e.g., USACE or FEMA standard curves adapted for Canadian residential stock), a simplified hydraulic depth model relating discharge to water depth at representative cross-sections, and exposure data for the Don River corridor.

---

## Monte Carlo Simulation

For each simulation draw:

1. Sample λ from posterior → draw event count N ~ Poisson(λ)
2. Sample σ, ξ from posterior → draw N exceedances from GPD(0, σ, ξ)
3. Convert to flow: Q_peak = exceedance + u
4. Apply loss function to each event
5. Sum to annual loss

Repeated over 10,000 iterations, this produces a full distribution of annual flood outcomes. Both aleatory uncertainty (random variation in flood occurrence) and epistemic uncertainty (parameter estimation uncertainty) are propagated.

---

## Current Limitations

### 1. Tail uncertainty (ξ)
ξ is weakly identified with 54 observations. The posterior spans bounded (ξ < 0) and unbounded (ξ > 0) tails. Extreme tail probabilities remain sensitive to prior assumptions. Mitigation: prior sensitivity analysis (V1.1), regional pooling (V2).

### 2. No physical loss model
Flow → Loss mapping has no intermediate physical steps. Decision-relevant risk quantification requires the full flow → depth → damage → exposure → loss pipeline.

### 3. Stationarity
λ, σ, ξ are assumed constant over 1961–2023. Urban development of the Don watershed and climate-driven rainfall intensification likely violate this assumption. Trend diagnostics planned for V1.5; non-stationary model in V2.

### 4. Single gauge, no spatial model
The model characterizes flood risk at a single point (Todmorden). Spatial variation across the Don watershed is not captured.

### 5. Frequency–severity independence
Events are assumed independent of their magnitude. Large rainfall events may generate both high frequency and high severity; this correlation is ignored until V2.

---

## Structural Roadmap

| Version | Focus |
|---|---|
| **V1** | Stationary Bayesian Poisson + GPD baseline |
| **V1.1** | Fix model bugs; prior sensitivity analysis for ξ; depth-damage curve prototype |
| **V1.5** | Threshold refinement; non-stationarity diagnostics; trend detection in λ |
| **V2** | Non-stationary Poisson λ(t); rainfall-linked severity; basic hydraulic depth model |
| **V2+** | Parent–child stochastic structure; climate → rainfall → flood hierarchy; spatial modeling |

---

## References

- Coles, S. (2001). *An Introduction to Statistical Modeling of Extreme Values*. Springer.
- Martins, E.S., & Stedinger, J.R. (2001). Generalized maximum-likelihood GEV quantile estimators for hydrologic data. *Water Resources Research*, 37(3), 747–754.
- Vehtari, A., Gelman, A., & Gabry, J. (2017). Practical Bayesian model evaluation using leave-one-out cross-validation and WAIC. *Statistics and Computing*, 27(5), 1413–1432.
- Vehtari, A., et al. (2024). Pareto smoothed importance sampling. *Journal of Machine Learning Research*, 25(72), 1–58.
- Stan Development Team. Extreme value analysis and user-defined probability functions in Stan. https://mc-stan.org/learn-stan/case-studies/gpareto_functions.html

---

*Last updated: April 2026 — V1.1 corrections applied.*
