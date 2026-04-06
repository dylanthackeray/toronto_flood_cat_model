
// Poisson model for annual flood event counts (frequency layer)
//
// DATA REQUIREMENT: freq_df must include ALL years in the gauging
// record, including years with zero events. Omitting zero-event years
// fits a zero-truncated Poisson and inflates lambda.
//
// Prior: Gamma(2, 2) — mean=1 event/year, variance=0.5.
// Centered near the observed Don River rate (~0.86 events/year at
// u=40 m^3/s). Diffuse enough to be regularizing rather than
// constraining. With 60+ years of data the prior has small influence.

data {
  int<lower=1> T;                  // number of years (ALL years, including zeros)
  array[T] int<lower=0> N;        // event counts per year
}

parameters {
  real<lower=0> lambda;     // Poisson rate (events/year)
}

model {
  // Prior: Gamma(alpha=2, beta=2) — mean=1, variance=0.5
  lambda ~ gamma(2, 2);

  // Likelihood
  N ~ poisson(lambda);
}

generated quantities {
  // n_rep: posterior predictive counts for PPC
  // log_lik: pointwise log-likelihood for LOO-CV
  array[T] int n_rep;
  vector[T] log_lik;

  for (t in 1:T) {
    n_rep[t]    = poisson_rng(lambda);
    log_lik[t]  = poisson_lpmf(N[t] | lambda);
  }
}
