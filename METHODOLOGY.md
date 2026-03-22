# Statistical Methodology

This document explains the statistical framework behind the Don River 
Flood Risk Model — not just what choices were made, but why, and how 
I actually got there.

---

## Table of Contents

1. [Why Bayesian](#why-bayesian)
2. [Data](#data)
3. [Event Definition & Declustering](#event-definition--declustering)
4. [Threshold Selection](#threshold-selection)
5. [Frequency Model](#frequency-model)
6. [Severity Model](#severity-model)
7. [Prior Construction](#prior-construction)
8. [Loss Function](#loss-function)
9. [Monte Carlo Simulation](#monte-carlo-simulation)
10. [Assumptions & Limitations](#assumptions--limitations)

---

## Why Bayesian

This project didn't start as a Bayesian model. It started with 
something much simpler — confidence intervals and a Monte Carlo 
simulation running through those ranges. That approach works fine 
for a lot of problems, but the more I thought about flood risk the 
more it felt wrong.

Flooding is a rare extreme event. The whole point of this model is 
to say something meaningful about events that barely appear in 60 
years of historical data. With that little information, a point 
estimate felt falsely precise. I wasn't uncertain about floods in 
a way that could be captured by a confidence interval around a fixed 
estimate. I was uncertain about the parameters themselves.

That's when I realized the uncertainty needed to be baked into the 
model itself, not tacked on afterward. A Bayesian framework treats 
parameters as random variables with full distributions rather than 
fixed numbers — so when I say lambda is 2.3 floods per year, I'm 
not pretending that's exactly right. I'm saying it's probably 
somewhere in a range, with some values more likely than others, and 
that entire distribution of belief propagates through to the final 
loss estimate. That felt honest in a way the frequentist approach 
didn't for this problem.

---

## Data

### Primary Data Source
**Source:** Water Survey of Canada — HYDAT database
**Station:** Don River at Todmorden (02HC024)
**Period:** 1961–2023 (~22,000 daily observations)
**Variable:** Daily mean discharge (m³/s)

**Why this station:**
- Longest continuous record available for Don River
- Located at Todmorden — captures the full upper watershed
- Official gauge used by TRCA for flood monitoring

**Variables derived from raw flow:**

| Variable | Definition | Used for |
|---|---|---|
| Q_peak | Maximum flow during independent event | Severity model |
| duration | Duration above threshold (days) | Event characterization |
| volume_excess | Volume above threshold (sum of excess flow) | Event characterization |
| n_events | Annual count of independent events | Frequency model |
| excess_peak | Q_peak - u for each event | GPD fitting |

---

### Secondary Data Source
**Source:** Environment Canada Water Office — Historical Data Portal
**Link:** [historical_hydrology_data](https://wateroffice.ec.gc.ca/mainmenu/historical_data_index_e.html)
**Station:** Don River at Todmorden (02HC024)
**Period:** 2002–2023 (water level data only)
**Variables:** Daily mean discharge (m³/s) and daily mean water level (m, local gauge datum)

**Why this source:**
The HYDAT database does not include water level observations for this station. The Environment Canada historical download provides paired discharge and water level observations from 2002 onward, enabling construction of a rating curve — the relationship between water level and discharge. This rating curve was used during physical threshold selection to understand what discharge values correspond to elevated water levels.

**Known limitation:** Water level data only covers 2002 onward and never reaches the estimated flood warning threshold of 14.0m (local datum) during the recording period. The rating curve therefore cannot be validated against observed flood conditions. Full details are documented in notebook [02_physical_threshold_selection.Rmd](R_notebooks/02_physical_threshold_selection.Rmd).

**Variables used:**

| Variable | Definition | Used for |
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

**V1 assumption:** λ is fixed over time. Climate change almost 
certainly violates this — addressed in V2.

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

## Prior Construction

Building priors was the part of this project I found hardest — 
not technically, but conceptually. The challenge was finding the 
balance between using what I knew and not imposing too much 
structure on a model that should be driven by data.

My first instinct was to just pick priors from the literature. 
But I wanted something more grounded in the actual Don River 
data I had.

**Step 1 — Method of Moments**

I decided to use my empirical data to anchor the priors. Gamma 
is parameterized by mean and variance — so I estimated both from 
my observed data and solved for α and β:
```
α_emp = X̄² / S²
β_emp = X̄  / S²
```

This gives a prior centered exactly on what the data suggests. 
But then I realized the problem.

**The Double Dipping Problem**

I was using the same data to set the prior AND to update it to 
the posterior. That means the data is counted twice — once in 
the prior and once in the likelihood. The result is a posterior 
that's overconfident — the credibility bands are narrower than 
they should be because the data has more influence than it 
should.

The fix was to inflate the prior variance — making the prior 
weaker so the data has to work harder to update it. But I needed 
a principled way to decide how much to inflate, not just 
arbitrarily multiply by 3 or 5.

**Step 2 — ESS Scaling**

This is where declustering connected back in a way I hadn't 
anticipated. Because I had declustered my events I knew exactly 
how many independent observations I had — n_events. 
That's the degrees of freedom in the Gamma-Chi-squared 
relationship, where ESS ≈ 2α.

Setting a desired prior weight of w = 0.05 — meaning the prior 
carries 5% of total information and the data carries 95%:
```
ESS_prior = (w / 1-w) × n_events
scale     = (ESS_prior / 2) / α_emp
α_prior   = α_emp × scale
β_prior   = β_emp × scale
```

Scaling both α and β by the same factor preserves the prior mean 
while widening the variance — the prior stays anchored to the 
data but loses enough weight that double dipping stops being a 
problem.

**Final priors:**
```
λ ~ Gamma(α_λ,prior, β_λ,prior)
σ ~ Gamma(α_σ,prior, β_σ,prior)
ξ ~ Gamma(α_ξ,prior, β_ξ,prior) - 0.3
```

σ gets no shift — negative scale is mathematically undefined.
ξ gets the -0.3 shift for the physical reasons described above.

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

*This methodology will be updated as the model develops. 
V1 is a stationary baseline — the foundation everything 
else builds on.*
