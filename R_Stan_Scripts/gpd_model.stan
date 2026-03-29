
// function to handle shape = 0, "exponential" case + make GPD model since stan doesn't include it
functions {
  real gpd_lpdf(real x, real sigma, real xi) {
    if (xi == 0) {
      return -log(sigma) - x / sigma;
    } else {
      return -log(sigma) - (1/xi + 1) * log1p(xi * x / sigma);
    }
  }
}

data {
  int<lower=1> N;            // number of exceedances
  vector<lower=0>[N] x;     // exceedances
}

parameters {
  real<lower=0> sigma;                  // scale
  real<lower=-0.3, upper=1> xi;        // shape - .3
}

model {
  // Priors
  sigma ~ gamma(2, 0.1);     // weak but positive, (mean = shape/rate | variance = shape/rate^2)
  xi ~ normal(0, 0.3);       // centered near 0 (light/moderate tails)

  // Likelihood
  for (n in 1:N) {
    target += gpd_lpdf(x[n] | sigma, xi);
  }
}