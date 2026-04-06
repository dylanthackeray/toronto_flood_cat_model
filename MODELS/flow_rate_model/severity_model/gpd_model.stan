
// GPD model for flood exceedances (peaks over threshold)
//
// Prior on xi follows Martins & Stedinger (2001, WRR): the shape
// parameter for river flood data is physically bounded above at 0.5
// (below this, the distribution has finite variance and MLE asymptotics
// hold). No lower hard constraint is imposed — the GPD likelihood
// naturally becomes -inf when xi < -sigma/max(x), so the data
// constrains the lower tail directly. Prior centered at -0.1 with
// sd=0.2 reflects hydrological evidence that urban catchments tend
// toward bounded tails (xi slightly negative) without over-constraining.
//
// References:
//   Martins & Stedinger (2001). Generalized maximum-likelihood GEV
//     quantile estimators. Water Resour. Res. 37(3), 747-754.
//   Coles (2001). An Introduction to Statistical Modeling of Extreme
//     Values. Springer.

functions {

  real gpd_lpdf(real x, real sigma, real xi) {
    // All local variables declared at top of function body (Stan requirement)
    real z;
    if (abs(xi) < 1e-8) {
      // Exponential limit as xi -> 0 (L'Hopital)
      return -log(sigma) - x / sigma;
    }
    z = 1.0 + xi * x / sigma;
    if (z <= 0.0) {
      return negative_infinity();
    }
    return -log(sigma) - (1.0 / xi + 1.0) * log(z);
  }

  real gpd_rng(real sigma, real xi) {
    // Inverse-CDF method. All locals declared at top.
    real u;
    u = uniform_rng(0.0, 1.0);
    if (abs(xi) < 1e-8) {
      return -sigma * log(u);
    }
    return sigma / xi * (pow(u, -xi) - 1.0);
  }

}

data {
  int<lower=1> N;            // number of exceedances
  vector<lower=0>[N] x;     // exceedances (Q_peak - u_physical)
}

parameters {
  real<lower=0> sigma;       // GPD scale (m^3/s)
  real<upper=0.5> xi;        // GPD shape: upper bound at 0.5 (finite variance)
                             // lower end unconstrained — likelihood handles support
}

model {
  sigma ~ gamma(2, 0.1);
  xi    ~ normal(-0.1, 0.2);

  for (n in 1:N) {
    target += gpd_lpdf(x[n] | sigma, xi);
  }
}

generated quantities {
  vector[N] y_rep;
  vector[N] log_lik;

  for (n in 1:N) {
    log_lik[n] = gpd_lpdf(x[n] | sigma, xi);
    y_rep[n]   = gpd_rng(sigma, xi);
  }
}
