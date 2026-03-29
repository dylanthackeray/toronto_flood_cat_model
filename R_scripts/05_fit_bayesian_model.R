# ============================================================
# 05_fit_bayesian_model.R
# Don River Flood Risk Model
# Goal: Fit Poisson + GPD using the Bayesian Framework
# ============================================================

SEED <- 1234

set.seed(SEED)

library(cmdstanr)
library(tidyverse)
library(here)

# ------------------------------------------------------------
# Load Data
# ------------------------------------------------------------

freq_df <- read_csv(here::here("data", "model", "frequency_data.csv"))
severity_df <- read_csv(here::here("data", "model", "severity_data.csv"))

# ------------------------------------------------------------
# Prepare Data for Stan
# ------------------------------------------------------------

poisson_data <- list(
  T = nrow(freq_df),
  N = freq_df$n_events
)

gpd_data <- list(
  N = nrow(severity_df),
  x = severity_df$exceedance
)

# ------------------------------------------------------------
# Compile Models
# ------------------------------------------------------------

poisson_model <- cmdstan_model("R_stan_Scripts/poisson_model.stan")
gpd_model     <- cmdstan_model("R_stan_Scripts/gpd_model.stan")

# ------------------------------------------------------------
# Sample
# ------------------------------------------------------------

fit_poisson <- poisson_model$sample(
  data = poisson_data,
  chains = 4,
  iter_sampling = 2000,
  iter_warmup = 1000,
  seed = SEED
)

fit_gpd <- gpd_model$sample(
  data = gpd_data,
  chains = 4,
  iter_sampling = 2000,
  iter_warmup = 1000,
  seed = SEED
)

# ------------------------------------------------------------
# Save Outputs
# ------------------------------------------------------------

fit_poisson$save_object(
  file = here::here("data", "model", "bayesian_model_fits", "poisson_fit.rds")
)

fit_gpd$save_object(
  file = here::here("data", "model", "bayesian_model_fits", "gpd_fit.rds")
)