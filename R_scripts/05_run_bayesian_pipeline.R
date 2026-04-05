# ============================================================
# run_bayesian_pipeline.R
# Don River Flood Risk Model
# ============================================================

SEED <- 1234
set.seed(SEED)

library(tidyverse)
library(here)

# Load model functions
source(here::here("models", "flow_rate_model", "frequency_model", "poisson_model.R"))
source(here::here("models","flow_rate_model", "severity_model", "gpd_model.R"))

# ------------------------------------------------------------
# Load Data
# ------------------------------------------------------------

freq_df <- read_csv(here::here("data", "model", "frequency_data.csv"))
severity_df <- read_csv(here::here("data", "model", "severity_data.csv"))

# ------------------------------------------------------------
# Fit Models
# ------------------------------------------------------------

fit_poisson <- fit_poisson_model(freq_df, seed = SEED)
fit_gpd     <- fit_gpd_model(severity_df, seed = SEED)

# ------------------------------------------------------------
# Save Outputs
# ------------------------------------------------------------

fit_poisson$save_object(
  file = here::here("data/model/bayesian_model_fits/poisson_fit.rds")
)

fit_gpd$save_object(
  file = here::here("data/model/bayesian_model_fits/gpd_fit.rds")
)