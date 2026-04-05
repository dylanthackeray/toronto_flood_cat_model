# Don River Flood Risk Model

An open-source Bayesian extreme value model for flood risk on Toronto's Don River. Built as an independent research project to develop accessible catastrophe modeling outside the commercial insurance space.

---

## What This Is

Canada has no national flood map. Flood insurance became widely available only after 2015. Catastrophe models that price flood risk are expensive and closed-source—pricing out the small insurers and municipalities that need them most.

This project builds something different: a transparent, reproducible Bayesian model that estimates flood frequency and severity with full uncertainty quantification. It's designed to be readable, defensible, and improvable by anyone interested in flood risk.

---

## How It Works (V1 Baseline)

The model separates flood risk into two components:

**Frequency:** How often do floods occur?
- Poisson(λ) model for annual event counts
- λ ~ Gamma(α, β) prior encoding physical prior knowledge
- Fitted to 34 years of independent flood events (1961–2023)
- Result: λ ≈ 1.55 events/year [95% CI: 1.15–2.00]

**Severity:** When a flood occurs, how large is it?
- Generalized Pareto Distribution (σ, ξ) for exceedances above threshold
- σ ~ Gamma(2, 0.1) and ξ ~ N(-0.3, 0.3) priors with physical justification
- Fitted to 54 independent exceedances (m³/s above u_statistical)
- Result: σ ≈ 13.2 m³/s, ξ ≈ -0.12 [both with uncertainty intervals]

**Pipeline:**
Joint posterior over (λ, σ, ξ) → 10,000 Monte Carlo samples → distribution of plausible flood seasons → Annual Exceedance Probability (AEP) curve.

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

**V1.1 (Immediate):**
- Shape parameter (ξ) robustness: sensitivity analysis on priors
- Loss pipeline: depth mapping + depth-damage curves + exposure data
- Economic loss output

**V1.5 (Short term):**
- Non-stationarity diagnostics (trend detection, changepoint analysis)
- Bayesian grid search for statistical threshold (MRL diagnostics)
- Loss model refinement and calibration

**V2 (Medium term):**
- Non-stationary frequency model with climate/rainfall covariates
- Frequency-severity dependence structure
- Partial hydraulic model (1D or lookup table)

**V2+ (Long term):**
- Parent-child framework (climate → rainfall → event generation)
- Spatial model across Don watershed
- Upstream-downstream correlation

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

# Download HYDAT database (run once)
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
If tail behavior is uncertain (it is), that uncertainty appears in credible intervals. 
No false precision.

**Modular improvement:**  
V1 is a stationary baseline. Each component (frequency, severity, loss) can be upgraded 
independently as better data or models emerge.

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
- Roadmap prioritization

The model represents a lot of trial and error on paper, conversations with hydrologists and actuaries, and careful reading of extreme value theory literature.

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
Retrieved from https://github.com/[your-repo]
\`\`\`

---

*Last updated: April 2026. This represents V1 baseline—a stationary model with full 
uncertainty quantification over frequency and severity. See roadmap for planned extensions.*
