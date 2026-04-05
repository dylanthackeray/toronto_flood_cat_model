# ============================================================
# gpd_model.R
# Bayesian GPD Model (Severity)
# Author: Dylan
# ============================================================

library(cmdstanr)

fit_gpd_model <- function(severity_df, seed = 1234) {
  
  gpd_data <- list(
    N = nrow(severity_df),
    x = severity_df$exceedance
  )
  
  model <- cmdstan_model("MODELS/flow_rate_model/severity_model/gpd_model.stan")
  
  fit <- model$sample(
    data = gpd_data,
    chains = 4,
    iter_sampling = 2000,
    iter_warmup = 1000,
    seed = seed
  )
  
  return(fit)
}