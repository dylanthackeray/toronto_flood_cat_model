### 2. No Flow-to-Impact Pipeline

**The problem:** Model outputs m³/s above threshold. Decision-makers need flood impact: depth, inundation area, economic loss.

**Missing chain:**

Flow (m³/s)
  → Flood depth (m)        [requires channel geometry, DEM]
  → Inundated area (m²)    [requires LiDAR]
  → Property exposure       [requires cadastre]
  → Depth-damage curves     [literature or expert elicitation]
  → Economic/Insurer loss ($)       [final output]
```

**Current placeholder:** Power-law proxy function (v1_loss_model/) calibrated to Hurricane Hazel. This is **not suitable for decision-making**—too few calibration points, fragile extrapolation.

**Timeline:**
- **V1.1:** Integrate published depth-damage functions by building type
- **V1.5:** LiDAR-based flood depth mapping or simplified proxy
- **V2:** Hydraulic model or distributed lookup tableation:** Don River at Todmorden (02HC024)  
**Period:** 1961–2023 (63 years, ~22,000 daily observations)  
**Variable:** Daily mean discharge Q (m³/s)

The Todmorden station captures the full Don River watershed above the confluence with the Humber. This is the longest continuous record available for the Don and is the official gauge used by TRCA for flood monitoring.

**Data extracted from:** [R_scripts/01_data_collection.R](R_scripts/01_data_collection.R)

### Secondary: Environment Canada Historical Data Portal

**Station:** Don River at Todmorden (02HC024)  
**Period:** 2002–2023 (water level observations)  
**Variables:** Daily mean discharge (m³/s) and daily mean water level (m, local datum)

Water level data was used to construct a rating curve—the discharge-to-stage relationship—necessary for understanding what discharge values correspond to elevated water levels and for informing the physical threshold. This data does not reach the estimated flood warning threshold during the observation window but provides validation of mid-range discharge-stage relationships.

**Limitation:** Water level observations only span 2002 onward and never exceed the estimated flood stage during this period.

| Variable | Definition | Purpose |
|---|---|---|
| water_level_m | Daily mean water level (m, local datum) | Rating curve construction |
| discharge_m3s | Daily mean discharge (m³/s) | Rating curve construction |

---

### Physical Threshold
**u_physical = 40 m³/s**

The physical flood threshold was determined through three independent empirical approaches applied directly to the discharge record: log-linear extrapolation from the rating curve (discarded — physically impossible result), cross-referencing known historical flood dates against HYDAT discharge records, and flow percentile analysis. The final value of 40 m³/s was selected because it sits above the p99.9 of 52.5 m³/s, the mean Q_peak of documented flood events in the rating curve is 53.4 m³/s, and it retains 54 independent events after declustering; which is above the practical minimum of 50 for GPD fitting. Full justification is in notebook [02_physical_threshold_selection.Rmd](R_notebooks/02_physical_threshold_selection.Rmd).

**Note:** An initial estimate of 30 m³/s was revised to 40 m³/s after declustering revealed that events at 30 m³/s had a median duration of 1 day and a mean Q_peak of 42.2 m³/s -> consistent with elevated flow rather than genuine flooding.

---

## Event Definition & Declustering

A flood event is defined as a period where daily flow exceeds the 
physical flood stage — the flow level at which water leaves the Don 
River channel and causes real world damage.

**Why declustering matters:**

A single storm can keep flow elevated for several days. Without 
declustering those days would be counted as separate events — 
inflating the frequency estimate and violating the independence 
assumption the Poisson model depends on. Declustering ensures 
every event in the dataset is independent.

**Independence criterion:**

Two exceedances are treated as separate events if flow drops below 
the physical threshold for at least 3 consecutive days between them. 
The Don River is a small urban catchment that responds quickly to 
rainfall and recovers within 1-3 days — making 3 days a physically 
appropriate separation window.

This declustering decision also turned out to matter for the prior 
construction step later — the number of independent events becomes 
the degrees of freedom in the ESS calculation. Getting this right 
early mattered more than I initially realized.

---

## Threshold Selection

There are two distinct thresholds in this model and keeping them 
separate was one of the more confusing parts of building this.

### Physical Threshold (u_physical)

The flow level where flooding actually starts — where water leaves 
the channel and causes damage. This comes from TRCA engineering 
reports, not from my data. It defines what counts as a flood event 
for the frequency model.

### Statistical Threshold (u_statistical)

This one took longer to understand. Even after defining a flood as 
exceeding u_physical, I still needed a separate threshold for the 
GPD — the level above which extreme value tail behavior actually 
kicks in. These are not the same thing.

u_physical marks where flooding begins.
u_statistical marks where the mathematics of extreme value theory 
apply. It's always at or above u_physical.

**Why this distinction matters:**

If I fit the GPD to all flows above u_physical I might be fitting 
it to moderate floods that don't actually behave like GPD tail 
events yet. The Pickands-Balkema-de Haan theorem — which justifies 
using GPD in the first place — only guarantees convergence to GPD 
above a sufficiently high threshold. Finding that threshold is the 
job of the grid search.

### Bayesian Grid Search With MRL Diagnostics
#### Note: NOT implemented yet, will evaluate if necessary after V1 is completed. Chose u_statistical based on flow (m^3/s) percentiles. 
#### To see justification go to [02_physical_threshold_selection.Rmd](R_notebooks/02_physical_threshold_selection.Rmd).

Classical threshold selection eyeballs a Mean Residual Life plot 
and picks where it looks linear. That felt too subjective for 
something the entire GPD fit depends on.

The MRL function for a GPD has a closed form:

MRL(u) = (σ + ξu) / (1 - ξ)
```

Since σ and ξ are random variables in my model, MRL(u) is also a 
random variable — it inherits the uncertainty from the parameters. 
Instead of a single line I get a posterior distribution at each 
candidate threshold, which means a credibility band across the 
entire grid.

This matters because a wide band at some threshold u means the 
data doesn't have enough events above that level to confidently 
say GPD holds there. A narrow band means the data strongly supports 
it. The optimal threshold is where the posterior mean is 
approximately linear AND the band is narrow enough to trust — 
both conditions together, not just one.

**Selection criteria:**
- Posterior mean MRL is approximately linear
- Credibility band is sufficiently narrow
- σ and ξ are stable across nearby thresholds
- At least 50 independent events exceed the threshold

---

## Frequency Model

**Question:** How often do flood events occur per year?

### Model Specification

$$N \sim \text{Poisson}(\lambda)$$
$$\lambda \sim \text{Gamma}(\alpha_\lambda, \beta_\lambda)$$

### Prior for λ

**Shape (α) and rate (β):** Chosen to encode physical prior knowledge without overstating confidence.

The mean of the prior: $E[\lambda] = \alpha / \beta$  
The variance: $\text{Var}[\lambda] = \alpha / \beta^2$

From exploratory analysis (01_EDA.Rmd): observed frequency is 1.56 events/year over 34 years. This becomes the prior mean. Uncertainty is encoded as a variance reflecting the limited sample size (34 years).

**Why Poisson:**

Floods on the Don River are rare — flow exceeds flood stage on 
maybe 2-5% of days. There are many opportunities for a flood to 
occur (365 days a year). And after declustering, events are 
approximately independent of each other. Those three conditions 
together are exactly what the Poisson Limit Theorem requires — 
the count of events follows a Poisson distribution naturally.

**Why Gamma prior for λ:**

I needed a prior that was strictly positive — a negative flood 
rate is physically meaningless. I also needed something flexible 
enough to encode what I actually believed about Don River flood 
frequency without being too rigid.

Gamma satisfied both. But the deeper reason is that Gamma is 
parameterized by mean and variance — two quantities I can actually 
reason about physically and estimate from my data. The mean is 
my best guess at the flood rate. The variance is how uncertain I 
am about that guess. That made Gamma feel like the right choice 
rather than an arbitrary one.

There's also a mathematical bonus: Gamma is the conjugate prior 
for Poisson, meaning the posterior is also Gamma — analytically 
tractable, no sampling needed:

λ | data ~ Gamma(α + total_events, β + n_years)
```

### Fitting

**Data:** Annual event counts from 1961–2023 (34 years)

$$\lambda | \text{data} \sim \text{Gamma}(\alpha + \sum n_i, \beta + n_{\text{years}})$$

The Stan model [05_run_bayesian_pipeline.R](R_scripts/05_run_bayesian_pipeline.R) fits this using HMC with 4 chains × 2000 iterations (1000 warmup).

**Posterior mean:** λ ≈ 1.55 events/year  
**95% credible interval:** [1.15, 2.00] events/year

**V1 status:** λ is estimated as fixed over time (stationary). 
Climate change and long-term trend effects are not captured — 
addressed in V2.

**PPC result:** Posterior predictive mean matches observed 
frequency well (1.56 → 1.61 events/year).

---

## Severity Model

**Question:** When a flood occurs, how large is it?

### Model Specification

$$X_i | \sigma, \xi \sim \text{GPD}(0, \sigma, \xi)$$

where $X_i = Q_{\text{peak},i} - u_{\text{statistical}}$ is the exceedance above the statistical threshold.

**Why GPD and not GEV:**

This was one of the clearer decisions once I thought it through. 
GEV models annual maxima — one value per year, the single largest 
event. That throws away a lot of information. If three floods occur 
in a year GEV only sees the biggest one.

More importantly I had already defined floods as exceedances above 
a threshold. Once I made that definition, modeling the exceedances 
themselves — how far above the threshold each flood peak went — 
was the natural next step. And the distribution for exceedances 
above a threshold is the GPD, not the GEV.

The key insight was realizing the threshold u_statistical is 
already doing the work of the location parameter μ in GEV. By 
subtracting u from each peak I've already removed the location — 
the GPD only needs two parameters, σ and ξ, to describe what's 
left. That felt cleaner and more honest than carrying μ as a 
separate estimated parameter.

The Pickands-Balkema-de Haan theorem provides the theoretical 
backing: above a high enough threshold, exceedance distributions 
converge to GPD regardless of the underlying flow distribution. 
I don't need to assume anything about how Don River flows are 
distributed overall — the GPD emerges from extreme value theory.

### Parameters

**σ (scale, m³/s):** Typical size of exceedances above the threshold. Larger σ means floods tend to be severely above the threshold when they occur.

**ξ (shape, dimensionless):** Controls tail weight:

ξ > 0 → heavy tail, no physical upper bound on flood magnitude
ξ = 0 → exponential tail
ξ < 0 → bounded tail, physical maximum = u + σ/|ξ|
```

### Prior for ξ: Physical Reasoning

Understanding ξ took the most work because it sits at the 
intersection of statistics and physics.

My first instinct was that ξ should be positive — Don River is an 
urban catchment with lots of impervious surfaces that produce fast 
sharp flood peaks, which is consistent with heavy tailed behavior.

But then I thought more carefully about what actually limits flood 
magnitude. Two things:

First, once water leaves the Don River channel it spreads 
horizontally across the floodplain rather than continuing to rise 
vertically. The lateral spread absorbs energy and limits how high 
the peak flow can get.

Second, Toronto has built infrastructure specifically to handle 
flooding — detention ponds, channelization, storm drains. This 
infrastructure doesn't eliminate flooding but it does impose a 
physical ceiling on how bad things can get before water is 
redirected elsewhere.

These two mechanisms together suggest a plausible physical upper 
bound on Don River flood magnitude — which means ξ could 
legitimately be slightly negative. Not strongly negative, but 
the possibility shouldn't be ruled out.

The mathematical constraint is that ξ cannot go below -0.5 — 
at that point the GPD mean stops existing, which is physically 
nonsensical for a real river. So the prior on ξ is shifted to 
allow values down to -0.3, which implies a physical maximum of 
u + σ/0.3. With plausible values of u and σ for Don River this 
gives a physically reasonable ceiling consistent with the 
historical record.

**Prior specification:** $\xi \sim N(-0.3, 0.3)$  
This allows values down to -0.5 (mathematical limit where mean diverges) but centers on -0.3, consistent with bounded-tail physics.

### Prior for σ

$$\sigma \sim \text{Gamma}(2, 0.1)$$

This encodes weak prior knowledge: exceedances are typically in the range of 5–30 m³/s based on historical extremes. The Gamma prior is flexible and strictly positive.

### Fitting

**Data:** 54 independent exceedances from 1961–2023

Fitted via Stan HMC with 4 chains × 2000 iterations (1000 warmup) in [05_run_bayesian_pipeline.R](R_scripts/05_run_bayesian_pipeline.R).

**Posterior summaries:**
- σ: mean ≈ 13.2 m³/s, 95% CI [10.1, 17.2]
- ξ: mean ≈ -0.12, 95% CI [-0.35, 0.10]

**Interpretation:** The posterior centers on slightly negative ξ (bounded tail) but the credible interval includes zero and positive values. This uncertainty is intentional and honest—with only 54 extremes, the data doesn't strongly constrain tail shape.

---

## Posterior Predictive Checks

All checks compare observed data against samples drawn from the posterior predictive distribution. See [R_notebooks/Posterior Predictive Checks/](R_notebooks/Posterior\ Predictive\ Checks/) for full analysis.

### Frequency: Event Counts

**Observed:** 53 total events over 34 years → 1.56 events/year mean

**Posterior predictive:** 500 simulated event counts drawn from posterior samples
- Mean: 1.61 events/year
- Range: 0–6 events in a single simulated year

**Assessment:** ✓ **Central tendency matches well.** The posterior mean event frequency reproduces observed data, indicating the Gamma prior and likelihood are well-calibrated.

### Severity: Exceedance Distribution

**Observed:** 54 exceedances, summary statistics:
- Mean: 13.4 m³/s
- p95: 42.2 m³/s
- Maximum: 68 m³/s

**Posterior predictive:** 806 simulated exceedances from 500 posterior samples
- Mean: 14.4 m³/s (small overshoot, ±1.0 m³/s)
- p95: 42.9 m³/s (excellent match)
- Maximum: 188 m³/s (wide range, see below)

### Central & Upper Quantiles

| Statistic | Observed | Simulated | Status |
|-----------|----------|-----------|--------|
| Mean | 13.4 | 14.4 | ✓ Good |
| p90 | 35.8 | 36.9 | ✓ Good |
| p95 | 42.2 | 42.9 | ✓ Excellent |
| p99 | — | 70.3 | — |
| Maximum | 68 | 188 | ⚠ Wide range |

### Tail Behavior

**Key finding:** The posterior predictive maximum (188 m³/s) is **2.8× the observed maximum (68 m³/s).**

**Is this a problem?** No—this is **correct behavior for extreme value theory.**

The Poisson-GPD model is designed to represent uncertainty beyond observed extremes. Historical data is sparse in the tail. With only 54 extremes, the posterior must propagate this uncertainty into tail predictions. The simulated extremes can legitimately exceed observed extremes.

**Why the range is wide:** ξ is weakly identified. The posterior credible interval on ξ ranges from -0.35 to +0.10:
- If ξ ≈ -0.35 (strong bounded tail), the physical maximum is ~u + σ/0.35 ≈ 75 m³/s
- If ξ ≈ +0.10 (weak unbounded tail), there is no physical maximum
- The 188 m³/s comes from the tail of the posterior ξ distribution

**Implication:** We are honest about ξ uncertainty. Plausible scenarios range from bounded tails (max ~75 m³/s) to unbounded tails (no limit). The model captures this uncertainty rather than hiding it.

### Empirical Survival Function

The empirical (observed) and simulated survival functions are visually similar in the observed range (0–68 m³/s). Above 68 m³/s, the simulated tail spreads wider, consistent with posterior ξ uncertainty.

---

## Loss Function

**Problem:** Convert Q_peak in m³/s to insured loss in CAD.

This is honestly the weakest part of the model and I want to 
be upfront about that.

**Approach:** Proxy stage-damage function

Loss = scale × (Q_peak - u)^exponent
```

**Why this form:**
- Zero loss at exactly threshold → physically correct
- Nonlinear growth → catastrophic floods cause 
  disproportionate damage relative to moderate ones
- Flexible → scale and exponent calibrated to known events

**Calibration:**

Publicly available fluvial loss data for Toronto is extremely 
sparse — maybe one or two genuinely fluvial events with 
documented insured losses. Hurricane Hazel 1954 is the primary 
anchor, adjusted for inflation. The scale parameter is treated 
as uncertain and given its own prior so that calibration 
uncertainty propagates through rather than being hidden as a 
fixed assumption.

I'm still working through the best approach here. The sparsity 
of the data makes any calibration fragile. Future versions will 
incorporate published depth-damage curves from the literature 
as an independent check.

---

## Monte Carlo Simulation

The Monte Carlo engine is how frequency and severity combine 
into a final loss probability.

**Each simulated year:**

1. Draw λ from posterior
2. N ~ Poisson(λ)              how many floods this year?
3. Draw σ, ξ from posteriors
4. For each of N floods:
   X ~ GPD(σ, ξ)              how large is this flood?
   Q_peak = X + u             actual peak flow
   Loss = f(Q_peak)           dollar loss
5. Sum all losses              total annual loss
6. Did total exceed threshold?
```

**After 10,000 simulations:**

P(loss > threshold) = years exceeding threshold / 10,000
```

**Why sample from posteriors rather than point estimates:**

This is the part that connects everything back to the Bayesian 
motivation at the start. If I used point estimates for λ, σ, 
and ξ I'd be running a classical simulation — fast and clean 
but overconfident. By sampling from the full posterior 
distributions I'm propagating two kinds of uncertainty 
simultaneously:

Aleatory uncertainty  → floods are inherently random
                        even if you knew the parameters perfectly
                        you couldn't predict exactly when they occur

Epistemic uncertainty → I estimated the parameters from limited data
                        I could be wrong about λ or σ or ξ
                        that uncertainty matters for the final answer
```

Both end up in the final credibility band around the AEP curve. 
That's what makes the output honest rather than just precise.

---

## Assumptions & Limitations

The hardest part of building this model wasn't the statistics — 
it was reasoning carefully about what I was assuming and whether 
those assumptions were defensible. Every time I thought I had 
something figured out I'd find a theoretical or empirical reason 
it wasn't quite right. The model reflects the best balance I 
could find between statistical rigor and practical buildability 
as a second year undergrad.

**Stationarity**
λ and σ are fixed over time. Climate change almost certainly 
violates this — flood frequency and severity are shifting. 
This is the most important limitation of V1 and the first 
thing addressed in V2.

**Frequency-severity independence**
N and Xᵢ are modeled independently. In reality the same climate 
signal drives both — bad years tend to have more floods AND 
bigger floods simultaneously. Ignoring this likely leads to 
underestimating joint tail risk.

**Single gauge**
One streamflow gauge captures no spatial variation across the 
watershed. Two properties on opposite sides of the Don River 
watershed can have very different flood exposure.

**Daily flow resolution**
Daily mean discharge may miss sub-daily flash flood peaks — 
particularly relevant for intense summer convective storms 
like the 2013 event.

**Proxy loss function**
Dollar outputs are order-of-magnitude estimates calibrated 
from very limited data. This is the weakest link in the 
model and should be interpreted accordingly.

---

## Current Issues

The model correctly captures central behavior and frequency. However, three major gaps prevent this from being a complete flood risk assessment tool.

### 1. Tail Uncertainty in ξ

**The problem:** Shape parameter ξ is weakly identified. With only 54 extremes, the data contains limited information about true tail weight. The posterior is sensitive to prior assumptions (see ξ prior specification above).

**Manifestation:**
- Wide posterior credible interval on ξ: [-0.35, 0.10]
- Small prior changes shift tail probabilities by orders of magnitude
- 95% posterior predictive interval on maximum is enormous (68–188 m³/s)

**Mitigation (V1.1):**
- Sensitivity analysis on ξ prior (e.g., test N(-0.2, 0.2), N(-0.4, 0.3))
- Informative priors from published GPD studies of similar urban watersheds
- Diagnostics for weak identifiability (effective sample size, correlation matrices)

### 2. No Physical or Economic Link

**The problem:**
The current model outputs exceedance flow (m³/s above threshold). It does not 
connect flow to the quantity decision-makers actually care about: flood impact.

**What is missing:**

Flow (m³/s) 
  → Flood depth (m) [depends on channel geometry, floodplain slope]
  → Inundated area (m²) [depends on DEM/LiDAR]
  → Property exposure [depends on cadastre]
  → Depth-damage function [depends on building type, content value]
  → Economic loss ($) [depends on insurance penetration]
```

**Current workaround:**
Preliminary proxy loss function (power law) calibrated to Hurricane Hazel. 
This is fragile and unsuitable for a real risk model.

**Timeline:**
- **Immediate (V1.1):** Depth-damage functions from literature
- **Medium term (V1.5):** LiDAR-based or simplified proxy depth mapping
- **Long term (V2):** Full hydraulic model or distributed lookup table

### 3. Stationarity Assumption

**The problem:** Model assumes λ, σ, ξ are constant 1961–2023 and will remain constant. Reality violates this.

**What actually changes:**
- **Rainfall patterns:** Convective summer storms intensifying in southern Ontario
- **Urban development:** Don watershed densified; land-use shift from permeable to impervious
- **Climate:** Seasonal flow shifts, potential changes in extreme precipitation intensity
- **Infrastructure:** Detention ponds, stormwater management systems, channelization

**Current impact:** Posterior intervals mask trends. A 1975 flood and a 2020 flood are treated identically by the model despite different hydroclimate contexts.

**Evidence of non-stationarity:** Qualitative inspection of [01_EDA.Rmd](R_notebooks/01_EDA.Rmd) shows visually higher event counts and magnitudes in recent decades (1990–2023) vs. earlier decades (1961–1989). Formal trend testing planned for V1.5.

**Timeline:**
- **V1.5:** PELT changepoint detection, trend tests on annual n_events and Q_peak
- **V2:** Non-stationary Poisson(λ(t)) where λ depends on rainfall or climate index
- **V2+:** Stochastic parent-child: climate state (parent) → rainfall patterns → event generation

---

## Structural Roadmap

Each release adds one layer of realism.

### V1 (Current)

- ✓ Poisson(λ) frequency with Gamma prior
- ✓ GPD(σ, ξ) severity with informative priors
- ✓ HMC fitting via Stan
- ✓ Posterior predictive validation (PPCs)
- ✓ Monte Carlo simulation pipeline
- ⚠ Proxy loss function (inadequate)

### V1.1 (Immediate: ξ Robustness & Loss Pipeline)

- [ ] ξ sensitivity analysis (test 3–5 prior specifications)
- [ ] Informative priors from literature (similar urban watersheds)
- [ ] Weak identifiability diagnostics
- [ ] Depth-damage curves by building type (from literature)
- [ ] Deterministic depth mapping (simplified or LiDAR)
- [ ] Exposure data integration (cadastre or parcel-level assets)

### V1.5 (Short term: Non-stationarity Diagnostics & Threshold Refinement)

- [ ] Trend detection (PELT changepoint, Mann-Kendall test)
- [ ] Structural break tests on frequency and severity
- [ ] Bayesian grid search for u_statistical (MRL diagnostics)
- [ ] Loss function calibration refinement
- [ ] Frequency-severity dependence tests

### V2 (Medium term: Non-stationary Model)

- [ ] Non-stationary Poisson: λ(t) with time, rainfall, or climate covariate
- [ ] Severity: test for rainfall-conditional GPD
- [ ] Partial hydraulic model (1D routing or lookup table depth(Q))
- [ ] Validation against historical high-water marks
- [ ] Spatial extension (multi-location model)

### V2+ (Long term: Stochastic Parent-Child & Clustering)

- [ ] Parent-child structure: climate state → rainfall patterns → event clusters
- [ ] Event clustering induces frequency-severity dependence
- [ ] Stochastic seasonal structure
- [ ] Multi-location spatial model across Don watershed
- [ ] Upstream-downstream correlation

---

## Key Philosophy

**This model is:**
- A Bayesian framework for quantifying uncertainty in rare extreme events
- A tool to propagate both aleatory (natural variability) and epistemic (estimation) uncertainty
- A modular baseline that improves with new data and refined components
- Transparent about what is and isn't known

**This model is not:**
- Exact reproduction of historical floods
- A deterministic prediction of the next flood
- A complete hydraulic-hydrologic simulation
- Suitable for operational flood forecasting (different problem domain)

**Design principle:**
Honest representation of uncertainty over false precision. If tail behavior is uncertain (which it is, with 54 data points), that uncertainty appears in the credible intervals—not hidden in a point estimate.

**Interpretation:**
Draw 10,000 Monte Carlo samples from the joint posterior of (λ, σ, ξ). Each sample generates one plausible flood season with its own random event count and magnitudes. The distribution of outcomes across 10,000 seasons represents what the historical data and physical priors tell us about future flood risk.

---

### Physical Threshold
**u_physical = 40 m³/s**

The physical flood threshold was determined through three independent empirical approaches applied directly to the discharge record: log-linear extrapolation from the rating curve (discarded — physically impossible result), cross-referencing known historical flood dates against HYDAT discharge records, and flow percentile analysis. The final value of 40 m³/s was selected because it sits above the p99.9 of 52.5 m³/s, the mean Q_peak of documented flood events in the rating curve is 53.4 m³/s, and it retains 54 independent events after declustering; which is above the practical minimum of 50 for GPD fitting. Full justification is in notebook [02_physical_threshold_selection.Rmd](R_notebooks/02_physical_threshold_selection.Rmd).

**Note:** An initial estimate of 30 m³/s was revised to 40 m³/s after declustering revealed that events at 30 m³/s had a median duration of 1 day and a mean Q_peak of 42.2 m³/s -> consistent with elevated flow rather than genuine flooding.

---

## Event Definition & Declustering

A flood event is defined as a period where daily flow exceeds the 
physical flood stage — the flow level at which water leaves the Don 
River channel and causes real world damage.

**Why declustering matters:**

A single storm can keep flow elevated for several days. Without 
declustering those days would be counted as separate events — 
inflating the frequency estimate and violating the independence 
assumption the Poisson model depends on. Declustering ensures 
every event in the dataset is independent.

**Independence criterion:**

Two exceedances are treated as separate events if flow drops below 
the physical threshold for at least 3 consecutive days between them. 
The Don River is a small urban catchment that responds quickly to 
rainfall and recovers within 1-3 days — making 3 days a physically 
appropriate separation window.

This declustering decision also turned out to matter for the prior 
construction step later — the number of independent events becomes 
the degrees of freedom in the ESS calculation. Getting this right 
early mattered more than I initially realized.

---

## Threshold Selection

There are two distinct thresholds in this model and keeping them 
separate was one of the more confusing parts of building this.

### Physical Threshold (u_physical)

The flow level where flooding actually starts — where water leaves 
the channel and causes damage. This comes from TRCA engineering 
reports, not from my data. It defines what counts as a flood event 
for the frequency model.

### Statistical Threshold (u_statistical)

This one took longer to understand. Even after defining a flood as 
exceeding u_physical, I still needed a separate threshold for the 
GPD — the level above which extreme value tail behavior actually 
kicks in. These are not the same thing.

u_physical marks where flooding begins.
u_statistical marks where the mathematics of extreme value theory 
apply. It's always at or above u_physical.

**Why this distinction matters:**

If I fit the GPD to all flows above u_physical I might be fitting 
it to moderate floods that don't actually behave like GPD tail 
events yet. The Pickands-Balkema-de Haan theorem — which justifies 
using GPD in the first place — only guarantees convergence to GPD 
above a sufficiently high threshold. Finding that threshold is the 
job of the grid search.

### Bayesian Grid Search With MRL Diagnostics
#### Note: NOT implemented yet, will evaluate if necessary after V1 is completed. Chose u_statistical based on flow (m^3/s) percentiles. 
#### To see justification go to [02_physical_threshold_selection.Rmd](R_notebooks/02_physical_threshold_selection.Rmd).

Classical threshold selection eyeballs a Mean Residual Life plot 
and picks where it looks linear. That felt too subjective for 
something the entire GPD fit depends on.

The MRL function for a GPD has a closed form:
```
MRL(u) = (σ + ξu) / (1 - ξ)
```

Since σ and ξ are random variables in my model, MRL(u) is also a 
random variable — it inherits the uncertainty from the parameters. 
Instead of a single line I get a posterior distribution at each 
candidate threshold, which means a credibility band across the 
entire grid.

This matters because a wide band at some threshold u means the 
data doesn't have enough events above that level to confidently 
say GPD holds there. A narrow band means the data strongly supports 
it. The optimal threshold is where the posterior mean is 
approximately linear AND the band is narrow enough to trust — 
both conditions together, not just one.

**Selection criteria:**
- Posterior mean MRL is approximately linear
- Credibility band is sufficiently narrow
- σ and ξ are stable across nearby thresholds
- At least 50 independent events exceed the threshold

---

## Frequency Model

**Question:** How often do flood events occur per year?

**Model:**
```
N ~ Poisson(λ)
λ ~ Gamma(α_λ, β_λ)
```

**Why Poisson:**

Floods on the Don River are rare — flow exceeds flood stage on 
maybe 2-5% of days. There are many opportunities for a flood to 
occur (365 days a year). And after declustering, events are 
approximately independent of each other. Those three conditions 
together are exactly what the Poisson Limit Theorem requires — 
the count of events follows a Poisson distribution naturally.

**Why Gamma prior for λ:**

I needed a prior that was strictly positive — a negative flood 
rate is physically meaningless. I also needed something flexible 
enough to encode what I actually believed about Don River flood 
frequency without being too rigid.

Gamma satisfied both. But the deeper reason is that Gamma is 
parameterized by mean and variance — two quantities I can actually 
reason about physically and estimate from my data. The mean is 
my best guess at the flood rate. The variance is how uncertain I 
am about that guess. That made Gamma feel like the right choice 
rather than an arbitrary one.

There's also a mathematical bonus: Gamma is the conjugate prior 
for Poisson, meaning the posterior is also Gamma — analytically 
tractable, no sampling needed:
```
λ | data ~ Gamma(α + total_events, β + n_years)
```

**V1 status:** λ is estimated as fixed over time (stationary). 
Climate change and long-term trend effects are not captured — 
addressed in V2.

**PPC result:** Posterior predictive mean matches observed 
frequency well (1.56 → 1.61 events/year).

---

## Severity Model

**Question:** When a flood occurs, how large is it?

**Model:**
```
Xᵢ | σ, ξ ~ GPD(σ, ξ)
where Xᵢ = Q_peak,i - u_statistical
```

**Why GPD and not GEV:**

This was one of the clearer decisions once I thought it through. 
GEV models annual maxima — one value per year, the single largest 
event. That throws away a lot of information. If three floods occur 
in a year GEV only sees the biggest one.

More importantly I had already defined floods as exceedances above 
a threshold. Once I made that definition, modeling the exceedances 
themselves — how far above the threshold each flood peak went — 
was the natural next step. And the distribution for exceedances 
above a threshold is the GPD, not the GEV.

The key insight was realizing the threshold u_statistical is 
already doing the work of the location parameter μ in GEV. By 
subtracting u from each peak I've already removed the location — 
the GPD only needs two parameters, σ and ξ, to describe what's 
left. That felt cleaner and more honest than carrying μ as a 
separate estimated parameter.

The Pickands-Balkema-de Haan theorem provides the theoretical 
backing: above a high enough threshold, exceedance distributions 
converge to GPD regardless of the underlying flow distribution. 
I don't need to assume anything about how Don River flows are 
distributed overall — the GPD emerges from extreme value theory.

**What σ and ξ mean physically:**

σ (scale) — how large exceedances typically are above the 
threshold. Larger σ means floods tend to be severely above the 
threshold when they occur.

ξ (shape) — how heavy the tail is. This one required the most 
physical reasoning.

---

## Shape Parameter ξ — Physical Reasoning

Understanding ξ took the most work because it sits at the 
intersection of statistics and physics.
```
ξ > 0 → heavy tail, no physical upper bound on flood magnitude
ξ = 0 → exponential tail
ξ < 0 → bounded tail, physical maximum flood = u + σ/|ξ|
```

My first instinct was that ξ should be positive — Don River is an 
urban catchment with lots of impervious surfaces that produce fast 
sharp flood peaks, which is consistent with heavy tailed behavior.

But then I thought more carefully about what actually limits flood 
magnitude. Two things:

First, once water leaves the Don River channel it spreads 
horizontally across the floodplain rather than continuing to rise 
vertically. The lateral spread absorbs energy and limits how high 
the peak flow can get.

Second, Toronto has built infrastructure specifically to handle 
flooding — detention ponds, channelization, storm drains. This 
infrastructure doesn't eliminate flooding but it does impose a 
physical ceiling on how bad things can get before water is 
redirected elsewhere.

These two mechanisms together suggest a plausible physical upper 
bound on Don River flood magnitude — which means ξ could 
legitimately be slightly negative. Not strongly negative, but 
the possibility shouldn't be ruled out.

The mathematical constraint is that ξ cannot go below -0.5 — 
at that point the GPD mean stops existing, which is physically 
nonsensical for a real river. So the prior on ξ is shifted to 
allow values down to -0.3, which implies a physical maximum of 
u + σ/0.3. With plausible values of u and σ for Don River this 
gives a physically reasonable ceiling consistent with the 
historical record.

---

## Loss Function

**Problem:** Convert Q_peak in m³/s to insured loss in CAD.

This is honestly the weakest part of the model and I want to 
be upfront about that.

**Approach:** Proxy stage-damage function
```
Loss = scale × (Q_peak - u)^exponent
```

**Why this form:**
- Zero loss at exactly threshold → physically correct
- Nonlinear growth → catastrophic floods cause 
  disproportionate damage relative to moderate ones
- Flexible → scale and exponent calibrated to known events

**Calibration:**

Publicly available fluvial loss data for Toronto is extremely 
sparse — maybe one or two genuinely fluvial events with 
documented insured losses. Hurricane Hazel 1954 is the primary 
anchor, adjusted for inflation. The scale parameter is treated 
as uncertain and given its own prior so that calibration 
uncertainty propagates through rather than being hidden as a 
fixed assumption.

I'm still working through the best approach here. The sparsity 
of the data makes any calibration fragile. Future versions will 
incorporate published depth-damage curves from the literature 
as an independent check.

---

## Monte Carlo Simulation

The Monte Carlo engine is how frequency and severity combine 
into a final loss probability.

**Each simulated year:**
```
1. Draw λ from posterior
2. N ~ Poisson(λ)              how many floods this year?
3. Draw σ, ξ from posteriors
4. For each of N floods:
   X ~ GPD(σ, ξ)              how large is this flood?
   Q_peak = X + u             actual peak flow
   Loss = f(Q_peak)           dollar loss
5. Sum all losses              total annual loss
6. Did total exceed threshold?
```

**After 10,000 simulations:**
```
P(loss > threshold) = years exceeding threshold / 10,000
```

**Why sample from posteriors rather than point estimates:**

This is the part that connects everything back to the Bayesian 
motivation at the start. If I used point estimates for λ, σ, 
and ξ I'd be running a classical simulation — fast and clean 
but overconfident. By sampling from the full posterior 
distributions I'm propagating two kinds of uncertainty 
simultaneously:
```
Aleatory uncertainty  → floods are inherently random
                        even if you knew the parameters perfectly
                        you couldn't predict exactly when they occur

Epistemic uncertainty → I estimated the parameters from limited data
                        I could be wrong about λ or σ or ξ
                        that uncertainty matters for the final answer
```

Both end up in the final credibility band around the AEP curve. 
That's what makes the output honest rather than just precise.

---

## Assumptions & Limitations

The hardest part of building this model wasn't the statistics — 
it was reasoning carefully about what I was assuming and whether 
those assumptions were defensible. Every time I thought I had 
something figured out I'd find a theoretical or empirical reason 
it wasn't quite right. The model reflects the best balance I 
could find between statistical rigor and practical buildability 
as a second year undergrad.

**Stationarity**
λ and σ are fixed over time. Climate change almost certainly 
violates this — flood frequency and severity are shifting. 
This is the most important limitation of V1 and the first 
thing addressed in V2.

**Frequency-severity independence**
N and Xᵢ are modeled independently. In reality the same climate 
signal drives both — bad years tend to have more floods AND 
bigger floods simultaneously. Ignoring this likely leads to 
underestimating joint tail risk.

**Single gauge**
One streamflow gauge captures no spatial variation across the 
watershed. Two properties on opposite sides of the Don River 
watershed can have very different flood exposure.

**Daily flow resolution**
Daily mean discharge may miss sub-daily flash flood peaks — 
particularly relevant for intense summer convective storms 
like the 2013 event.

**Proxy loss function**
Dollar outputs are order-of-magnitude estimates calibrated 
from very limited data. This is the weakest link in the 
model and should be interpreted accordingly.

---

*Last updated: April 2026. This methodology documents V1 baseline. See [Structural Roadmap](#structural-roadmap) for V1.1+ development.*
