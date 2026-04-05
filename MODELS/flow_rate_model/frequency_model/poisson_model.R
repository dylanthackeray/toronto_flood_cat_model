# ============================================================
# poisson_model.R
# Bayesian Poisson Model (Frequency)
# Author: Dylan
# ============================================================

library(cmdstanr)

fit_poisson_model <- function(freq_df, seed = 1234) {
  
  poisson_data <- list(
    T = nrow(freq_df),
    N = freq_df$n_events
  )
  
  model <- cmdstan_model(stan_file = "MODELS/flow_rate_model/frequency_model/poisson_model.stan")
  
  fit <- model$sample(
    data = poisson_data,
    chains = 4,
    iter_sampling = 2000,
    iter_warmup = 1000,
    seed = seed
  )
  
  return(fit)
}