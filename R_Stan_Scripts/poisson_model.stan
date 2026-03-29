

data {
  int<lower=1> T;                  // number of years
  array[T] int<lower=0> N;        // event counts per year
}

parameters {
  real<lower=0> lambda;     // Poisson rate
}

model {
  // Prior
  lambda ~ gamma(2, 1);   // weak prior (I will change later)

  // Likelihood
  N ~ poisson(lambda);    // stan automatically computes the log prior and log likehood to obtain posterior shape
}