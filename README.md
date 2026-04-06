# Don River Flood Risk Model

An open-source Bayesian extreme value model for flood risk on Toronto's Don River. Built as an independent research project to develop accessible catastrophe modeling outside the commercial insurance space.

---

## What This Is / Motivation

Canada lacks a unified, publicly accessible national flood risk model. At the same time, modern catastrophe models used to price and manage flood risk are proprietary, expensive, and largely inaccessible to smaller insurers, municipalities, and researchers.

This creates a gap between who needs risk insight and who can actually access it.

This project is an attempt to close that gap.

It builds a transparent, reproducible Bayesian framework to model flood frequency and severity, with a focus on:

 - explicit uncertainty quantification
 - interpretability of assumptions
 - modular, extensible design

Rather than producing a single deterministic estimate, the model represents a distribution of plausible flood outcomes, making uncertainty -  especially in extreme events - central to the analysis.

The goal is not to replicate commercial catastrophe models, but to provide a credible, open foundation that others can inspect, challenge, and build upon.

---

## How It Works (V1 Baseline)

The model separates flood risk into two components:

**Frequency:** How often do floods occur?
- Poisson(λ) model for annual event counts
- λ ~ Gamma(α, β) prior encoding physical prior knowledge
- Fitted to 63 years of independent flood events (1961–2023)
- Result: λ ≈ 1.55 events/year [95% CI: 1.15–2.00]

**Severity:** When a flood occurs, how large is it?
- Generalized Pareto Distribution (σ, ξ) for exceedances above threshold
- σ ~ Gamma(2, 0.1) and ξ ~ N(-0.3, 0.3) priors with physical justification
- Fitted to 54 independent exceedances (m³/s above u_physical)
- Result: σ ≈ 13.2 m³/s, ξ ≈ -0.12 [both with uncertainty intervals]

**Pipeline:**
Joint (independent) posterior over (λ, σ, ξ) → 10,000 Monte Carlo samples → distribution of plausible flood seasons → Annual Exceedance Probability (AEP) curve.

---

## Current Status (V1 Complete)

### ✅ Completed

- [x] Data collection and cleaning (HYDAT 1961–2023)
- [x] Exploratory data analysis
- [x] Physical threshold selection (u_physical = 40 m³/s)
- [x] Statistical threshold selection (u_statistical = p99.9)
- [x] Event definition and declustering (3-day independence window)
- [x] Frequency model (Poisson with Gamma prior)
- [x] Severity model (GPD with informed priors)
- [x] Hamiltonian Monte Carlo fitting (Stan, 4 chains × 2000 iter)
- [x] Posterior predictive checks (central tendency + tail behavior)
- [x] MCMC diagnostics (trace plots, R-hat, ESS)

### 🔄 In Progress

- [ ] Loss function pipeline (flow → depth → exposure → loss)
  - Current status: placeholder power-law function (inadequate)
  - Next step: integrate depth-damage curves from literature

### 📋 Roadmap (V1.1 → V2+)

See [Structural Roadmap](METHODOLOGY.md#structural-roadmap) in METHODOLOGY.md for full detail.

---

## Key Findings from V1

### What Works Well

- **Central tendency:** Posterior predictive mean matches observed frequency (1.56 → 1.61 events/year)
- **Upper quantiles:** p95 of exceedances matches observed data (42.2 → 42.9 m³/s)
- **MCMC convergence:** All R-hat values < 1.01, effective sample sizes adequate

### Where Uncertainty is Large

- **Tail shape (ξ):** Weakly identified with 54 data points
  - 95% credible interval: [-0.35, +0.10]
  - Posterior allows plausible bounds from ~75 m³/s (strong bounded tail) to unbounded
  - This is **honest**, not a problem—extreme value theory predicts beyond observed extremes
  
- **Extreme events:** Posterior predictive maximum can be 2.8× observed max (68 → 188 m³/s)
  - This is **expected and correct** given ξ uncertainty
  - Reflects data sparsity in the tail, not model failure

See [Posterior Predictive Checks](METHODOLOGY.md#posterior-predictive-checks) for full diagnostics.

---

## Limitations (V1)

**Honest assessment of what is and isn't done:**

1. **Tail Uncertainty**  
   ξ is weakly identified. Extreme tail probabilities are sensitive to prior assumptions. 
   Mitigation planned for V1.1 (sensitivity analysis + literature priors).

2. **No Flow-to-Impact Link**  
   Model outputs m³/s. Decision-makers need economic loss (flood depth → property damage → $).
   Current proxy function is inadequate. Full pipeline in V1.1.

3. **Stationarity Assumption**  
   Assumes constant λ, σ, ξ over 1961–2023 and future. Ignores climate change, urban 
   development, and infrastructure changes. Trend diagnostics in V1.5, non-stationary 
   model in V2.

4. **Single Gauge**  
   No spatial variation across Don watershed. Planned for V2+.

5. **Independence Assumption**  
   Frequency and severity are modeled separately. In reality, large rainfall events can 
   generate both high frequency and high severity. V2 will model this dependence.

---

## Getting Started

### Requirements

\`\`\`r
install.packages(c(
  "tidyhydat",   # Water data access
  "tidyverse",   # Data wrangling
  "evd",         # GPD tools
  "cmdstanr",    # HMC via Stan
  "posterior",   # Draw processing
  "bayesplot",   # MCMC diagnostics
  "ggplot2"      # Visualization
))
\`\`\`

# Download HYDAT database (run once)
\`\`\`r
library(tidyhydat)
download_hydat()
\`\`\`

### Workflow

1. **Data prep:** \`R_scripts/01_data_collection.R\`
   - Downloads HYDAT data for Don River at Todmorden (02HC024)
   - Cleans and declusters to produce independent events

2. **Exploration:** \`R_notebooks/01_EDA.Rmd\`
   - Summary statistics, time series, histograms
   - Visual assessment of trend and structure

3. **Threshold selection:** \`R_notebooks/02_physical_threshold_selection.Rmd\`
   - Justifies u_physical = 40 m³/s from rating curve and historical flood dates
   - Determines u_statistical from flow percentiles

4. **Model fitting:** \`R_scripts/05_run_bayesian_pipeline.R\`
   - Fits Poisson frequency model (Stan)
   - Fits GPD severity model (Stan)
   - Extracts posterior draws

5. **Validation:** \`R_notebooks/Posterior Predictive Checks/\`
   - Compares observed vs simulated event counts and exceedances
   - Tail behavior diagnostics
   - Uncertainty quantification

6. **Simulation:** (In progress)
   - Monte Carlo engine to produce AEP curves and loss distributions

---

## Data Sources

**Primary:** Water Survey of Canada (HYDAT)  
- Station: Don River at Todmorden (02HC024)
- Period: 1961–2023 (63 years)
- Access: \`tidyhydat::get_hydat_stations()\` and \`get_hy_data()\`

**Secondary:** Environment Canada Water Office  
- Water level data 2002–2023 (for rating curve construction)
- Used to understand discharge-stage relationship

Full data documentation in [METHODOLOGY.md](METHODOLOGY.md#data-sources).

---

## Design Philosophy

**Transparency over complexity:**  
Every statistical choice (prior, threshold, declustering window) is justified in METHODOLOGY.md 
and code comments. You should be able to disagree with a choice and modify it.

**Uncertainty quantification over point estimates:**  
If tail behavior is uncertain (it is), that uncertainty appears in the model. 
No false precision.

**Modular improvement:**  
V1 is a stationary baseline. Each component (frequency, severity, loss) can and will be upgraded as better data emerges and as I progress throughout my undergrad.

**Physical reasoning:**  
Priors and thresholds are grounded in hydrology and watershed characteristics, not just 
data-driven optimization.

---

## A Note on Process & AI Use

This project was developed as an independent research project outside of coursework.

**AI tools were used for:**
- Coding assistance and syntax checking
- Document formatting and organization
- Code refactoring for readability

**All of the following are my own work:**
- Statistical reasoning and modeling decisions
- Physical justifications for thresholds and priors
- Posterior predictive check design and interpretation
- Critical evaluation of model limitations
- Roadmap Construction and Implementation

The model represents a lot of trial and error on paper and careful reading of extreme value theory, hydrology, bayesian statistics, and climate change literature.

---

## Creator

**Dylan Thackeray**  
Actuarial Science & Statistics, University of Toronto  
Working toward ACAS | Exam P — Summer 2026

Contact: dylanthackeray55@gmail.com

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Citation

If you use this model or adapt it for your own work, please cite:

\`\`\`
Thackeray, D. (2026). Don River Flood Risk Model (Version 1.0). 
Retrieved from https://github.com/[toronto_flood_cat_model]
\`\`\`

---

*Last updated: April 2026. This represents V1 baseline—a stationary model with full 
uncertainty quantification over frequency and severity. See roadmap for planned extensions.*
