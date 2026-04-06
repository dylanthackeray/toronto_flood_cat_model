# Don River Flood Risk Model

An open-source Bayesian extreme value model for flood risk on Toronto's Don River. Built as an independent research project to develop transparent catastrophe modeling outside the commercial insurance space.

---

## What This Is

Canada lacks a unified, publicly accessible national flood risk model. Existing catastrophe models are proprietary, expensive, and largely inaccessible to smaller insurers, municipalities, and researchers.

This project is an attempt to close that gap — a transparent, reproducible Bayesian framework that models flood frequency and severity with full uncertainty quantification. Rather than producing a single deterministic estimate, the model represents a distribution of plausible flood outcomes, making uncertainty in extreme events central to the analysis.

The goal is not to replicate commercial catastrophe models, but to provide a credible, open foundation that others can inspect, challenge, and build upon.

---

## How It Works

The model separates flood risk into two independently estimated components.

**Frequency** — How often do floods occur?

$$N \sim \text{Poisson}(\lambda), \quad \lambda \sim \text{Gamma}(2, 2)$$

- Fitted to all 63 years of record (1961–2023), including zero-event years
- Prior: Gamma(2, 2), mean = 1 event/year — consistent with observed Don River rate

**Severity** — When a flood occurs, how large is it?

$$X_i \sim \text{GPD}(0, \sigma, \xi), \quad X_i = Q_{\text{peak}} - u$$

- $\sigma \sim \text{Gamma}(2, 0.1)$, $\xi \sim \mathcal{N}(-0.1, 0.2)$
- Prior on ξ follows Martins & Stedinger (2001): centered slightly negative (bounded tail behavior), upper-constrained at 0.5 (finite variance requirement)
- Fitted to 54 independent exceedances above u = 40 m³/s

**Pipeline:**
Joint posterior over (λ, σ, ξ) → Monte Carlo simulation → distribution of plausible flood seasons → Annual Exceedance Probability (AEP) curve.

---

## Current Status

### Completed

- Data collection and cleaning (HYDAT 1961–2023)
- Exploratory data analysis
- Physical threshold selection (u = 40 m³/s, justified against rating curve and historical flood events)
- Event definition and declustering (3-day independence window, 54 independent events)
- Bayesian Poisson frequency model (Stan/HMC)
- Bayesian GPD severity model (Stan/HMC)
- MCMC diagnostics (R-hat, ESS, trace plots, divergence checks)
- Posterior predictive checks (central tendency + tail behavior)
- LOO cross-validation (via `loo` package, using `generated_quantities` log-likelihood)
- V1.1 model corrections (see below)

### In Progress

- Loss function pipeline (flow → depth → exposure → loss)
  - Current: placeholder power-law function
  - Next: depth-damage curves from literature

### Roadmap

See [METHODOLOGY.md](METHODOLOGY.md) for the full roadmap from V1.1 to V2+.

---

## V1.1 Model Corrections

Three bugs were identified and corrected after the initial V1 fit. The stored posteriors have been updated to reflect these fixes.

**1. Zero-truncated Poisson (critical)**
`03_model_dataset.R` was only passing years with observed events (n=34) to Stan instead of all 63 years of record. This fit a zero-truncated Poisson and inflated λ from the true rate of ~0.86 to ~1.55. Fixed by completing the year range and zero-filling inactive years.

**2. GPD shape parameter constraint truncated its own prior**
The Stan model had `real<lower=-0.3> xi` with prior Normal(-0.3, 0.3). The hard lower bound at -0.3 was the prior mean, silently cutting the left half of the prior distribution. Fixed by removing the lower bound — the GPD likelihood naturally becomes -∞ when ξ < -σ/max(x), so the data constrains the lower tail directly. Upper bound changed to 0.5 (Martins & Stedinger finite-variance requirement). Prior updated to Normal(-0.1, 0.2).

**3. No generated quantities in either Stan model**
Neither model had a `generated_quantities` block, preventing LOO cross-validation and native posterior predictive sampling from Stan. Both models now output `log_lik` (for `loo`) and `y_rep`/`n_rep` (for PPCs).

---

## Key Results

Results below are from the corrected V1.1 fit. The posterior λ dropped substantially after fixing the zero-truncation bug.

| Parameter | Posterior Mean | 95% CI |
|---|---|---|
| λ (events/year) | — | — |
| σ (GPD scale, m³/s) | — | — |
| ξ (GPD shape) | — | — |

*Run the pipeline to populate these values. See `METHODOLOGY.md` for interpretation.*

### What the model gets right

- Central tendency of exceedances is well-captured (σ is data-identified)
- Frequency model converges cleanly with adequate ESS
- MCMC diagnostics are clean across all parameters (R-hat < 1.01)

### Where uncertainty is large

- **Tail shape (ξ):** Weakly identified with 54 observations. The posterior spans bounded (ξ < 0) and unbounded (ξ > 0) tails. This is honest, not a failure — extreme value theory predicts beyond observed extremes.
- **Extreme events:** Posterior predictive maximum substantially exceeds the observed record. Expected given ξ uncertainty.

---

## Limitations

1. **Tail uncertainty** — ξ remains weakly identified at n=54. Prior sensitivity analysis planned for V1.1.

2. **No physical loss pipeline** — The model outputs flow in m³/s. A full risk model requires flow → depth → damage → loss. The current power-law proxy is inadequate.

3. **Stationarity** — λ, σ, ξ are assumed constant over 1961–2023. Climate change, urban development, and infrastructure changes are not modeled. Non-stationary extension planned for V2.

4. **Single gauge** — No spatial variation across the Don watershed.

5. **Frequency–severity independence** — Modeled separately. Correlation planned for V2.

---

## Getting Started

### Requirements

```r
install.packages(c(
  "tidyhydat",   # HYDAT water data access
  "tidyverse",
  "evd",         # GPD tools
  "cmdstanr",    # HMC via Stan
  "posterior",   # Draw processing
  "bayesplot",   # MCMC diagnostics
  "loo",         # LOO cross-validation
  "here"
))

# Install CmdStan (run once)
cmdstanr::install_cmdstan()

# Download HYDAT database (run once)
tidyhydat::download_hydat()
```

### Run the pipeline

```r
# 1. Data prep (download + clean HYDAT, build rating curve)
source("R_scripts/01_data_collection.R")
source("R_scripts/02_data_cleaning.R")

# 2. Threshold selection and event extraction
# See R_notebooks/02_physical_threshold_selection.Rmd

# 3. Fit both Bayesian models (also regenerates model datasets)
source("R_scripts/05_run_bayesian_pipeline.R")

# 4. Posterior predictive checks
# See R_notebooks/Posterior Predictive Checks/01_Posterior_Predictive_Checks.Rmd
```

### Workflow notebooks

| Notebook | Purpose |
|---|---|
| `R_notebooks/01_EDA.Rmd` | Summary statistics, time series, tail diagnostics |
| `R_notebooks/02_physical_threshold_selection.Rmd` | Justifies u = 40 m³/s |
| `R_notebooks/03_flood_events.csv_analysis.Rmd` | Event dataset exploration |
| `R_notebooks/04_frequentist_model_analysis.Rmd` | Frequentist baseline comparison |
| `R_notebooks/05_bayesian_frequentist_comparison.Rmd` | Bayesian vs frequentist |
| `R_notebooks/Posterior Predictive Checks/01_...Rmd` | PPC, tail checks, LOO |

---

## Data Sources

**Primary:** Water Survey of Canada (HYDAT)
- Station: Don River at Todmorden (02HC024)
- Period: 1961–2023 (63 years)

**Secondary:** Environment Canada Water Office
- Water level data 2002–2023, used to construct the rating curve and justify u_physical

---

## Design Philosophy

**Transparency over complexity:** Every statistical choice — prior, threshold, declustering window — is justified in `METHODOLOGY.md` and code comments. You should be able to disagree with a choice and modify it.

**Uncertainty quantification over point estimates:** If tail behavior is uncertain (it is), that uncertainty appears in the model. No false precision.

**Modular improvement:** Each component (frequency, severity, loss) is independently replaceable as better data and methods emerge.

**Physical reasoning:** Priors and thresholds are grounded in hydrology, not just data-driven optimization.

---

## A Note on AI Use

This project was developed as an independent research project.

AI tools were used for coding assistance, syntax checking, and document formatting. All statistical reasoning, physical justifications, modeling decisions, prior choices, and critical evaluation of results are my own.

---

## Creator

**Dylan Thackeray**
Actuarial Science & Statistics, University of Toronto
Working toward ACAS | Exam P — Summer 2026

Contact: dylanthackeray55@gmail.com

---

## License

MIT License. See [LICENSE](LICENSE).

---

## Citation

Thackeray, D. (2026). *Don River Flood Risk Model* (Version 1.1).
GitHub: https://github.com/dylanthackeray/toronto_flood_cat_model

---

*Last updated: April 2026. V1.1 — corrected Poisson zero-truncation, GPD prior constraint, and added LOO-CV. See roadmap in METHODOLOGY.md for planned extensions.*
