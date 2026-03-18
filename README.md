# Don River Flood Risk Model

An open-source Bayesian flood risk model for Toronto's Don River, 
built as part of an independent research project.

---

## What This Is

Canada has no national flood map, flood insurance only became widely 
available after 2015, and the catastrophe models that exist cost a lot 
annually — pricing out the small insurers that need them most. This 
project is my attempt to build something open and accessible.

The model estimates the probability that annual flood losses on the 
Don River exceed a given threshold, with full uncertainty quantification 
throughout. It is a work in progress.

---

## How It Works

The model separates flood risk into two questions:
- **How often do floods happen?** → Poisson(λ) frequency model
- **How bad are they?** → GPD(σ, ξ) severity model

These are combined through a Monte Carlo engine that simulates 
10,000 synthetic years to produce an Annual Exceedance Probability 
(AEP) curve.

The framework is Bayesian hierarchical — parameters are treated as 
random variables with prior distributions rather than fixed point 
estimates, so uncertainty is carried through to the final output.

Key statistical choices:
- Threshold `u` selected via Bayesian grid search with Mean Residual 
  Life diagnostics
- Priors constructed via ESS-scaled Method of Moments to prevent 
  double dipping:
```
α_prior = ESS_prior / 2
β_prior = ESS_prior / (2 * X̄)
ESS_prior = (w / 1-w) × n_events, w = 0.05
```

---

## Data

| Data | Source |
|---|---|
| Daily streamflow | Water Survey of Canada — HYDAT |
| Station | Don River at Todmorden (02HC024), 1961–2023 |
| Historical loss events | IBC, Canadian Disaster Database |

---

## Getting Started
```r
# install required packages
install.packages(c(
  "tidyhydat",
  "tidyverse",
  "extRemes",
  "rstan",
  "ggplot2"
))

# download HYDAT database (run once)
library(tidyhydat)
download_hydat()

# Note: model scripts are currently in progress.

```
---

## Current Status

- [ ] Data collection and cleaning
- [ ] EDA
- [ ] Threshold selection
- [ ] Frequency model
- [ ] Severity model
- [ ] Loss function calibration
- [ ] Monte Carlo simulation
- [ ] Results and visualizations

---

## Limitations

This is V1 — a stationary baseline model. Known limitations:

- Assumes stationarity — flood frequency and severity are fixed 
  over time, ignoring climate change
- Frequency and severity are modeled independently — underestimates 
  joint tail risk
- Loss function calibrated from very limited fluvial loss data
- Single gauge only — no spatial variation in risk

---

## Author

Dylan — Actuarial Science & Statistics, University of Toronto  
Working toward ACAS | Exam P — Summer 2026
