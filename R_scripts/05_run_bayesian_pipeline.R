# ============================================================
# 05_run_bayesian_pipeline.R
# Don River Flood Risk Model
#
# Runs the full Bayesian fitting pipeline:
#   1. Regenerates model datasets (includes zero-event years)
#   2. Fits Poisson frequency model via HMC
#   3. Fits GPD severity model via HMC
#   4. Prints convergence diagnostics
#   5. Runs LOO-CV on both models
#   6. Saves fitted objects to data/model/bayesian_model_fits/
# ============================================================

SEED <- 1234
set.seed(SEED)

library(tidyverse)
library(here)
library(cmdstanr)
library(posterior)
library(loo)

# ------------------------------------------------------------
# Step 1: Regenerate model datasets
# Ensures frequency_data.csv includes all years (with zeros).
# ------------------------------------------------------------

cat("Step 1: Regenerating model datasets...\n")
source(here::here("R_scripts", "03_model_dataset.R"))

# ------------------------------------------------------------
# Step 2: Load data
# ------------------------------------------------------------

freq_df     <- read_csv(here::here("data", "model", "frequency_data.csv"),
                        show_col_types = FALSE)
severity_df <- read_csv(here::here("data", "model", "severity_data.csv"),
                        show_col_types = FALSE)

cat(sprintf("\nFrequency data: %d years, %d total events (%.3f events/yr)\n",
            nrow(freq_df),
            sum(freq_df$n_events),
            mean(freq_df$n_events)))
cat(sprintf("Severity data:  %d exceedances\n\n", nrow(severity_df)))

# ------------------------------------------------------------
# Step 3: Load model functions
# ------------------------------------------------------------

source(here::here("MODELS", "flow_rate_model", "frequency_model", "poisson_model.R"))
source(here::here("MODELS", "flow_rate_model", "severity_model", "gpd_model.R"))

# ------------------------------------------------------------
# Step 4: Fit models
# ------------------------------------------------------------

cat("Fitting Poisson frequency model...\n")
fit_poisson <- fit_poisson_model(freq_df, seed = SEED)

cat("\nFitting GPD severity model...\n")
fit_gpd <- fit_gpd_model(severity_df, seed = SEED)

# ------------------------------------------------------------
# Step 5: Convergence diagnostics
# ------------------------------------------------------------

cat("\n==========================================\n")
cat("CONVERGENCE DIAGNOSTICS\n")
cat("==========================================\n")

cat("\n--- Poisson (lambda) ---\n")
print(fit_poisson$summary("lambda"))
cat(sprintf("Divergences: %d\n",
            sum(fit_poisson$sampler_diagnostics()[,,"divergent__"])))

cat("\n--- GPD (sigma, xi) ---\n")
print(fit_gpd$summary(c("sigma", "xi")))
cat(sprintf("Divergences: %d\n",
            sum(fit_gpd$sampler_diagnostics()[,,"divergent__"])))

# ------------------------------------------------------------
# Step 6: LOO cross-validation
# ------------------------------------------------------------

cat("\n==========================================\n")
cat("LOO CROSS-VALIDATION\n")
cat("==========================================\n")

log_lik_pois <- fit_poisson$draws("log_lik", format = "matrix")
log_lik_gpd  <- fit_gpd$draws("log_lik", format = "matrix")

loo_pois <- loo(log_lik_pois)
loo_gpd  <- loo(log_lik_gpd)

cat("\nPoisson LOO:\n")
print(loo_pois)

cat("\nGPD LOO:\n")
print(loo_gpd)

# Flag any high Pareto-k values (k > 0.7 = unreliable)
k_pois <- loo_pois$diagnostics$pareto_k
k_gpd  <- loo_gpd$diagnostics$pareto_k

if (any(k_gpd > 0.7)) {
  cat(sprintf("\nWARNING: %d GPD observations have Pareto-k > 0.7 (unreliable LOO).\n",
              sum(k_gpd > 0.7)))
  cat("Indices:", which(k_gpd > 0.7), "\n")
}

# ------------------------------------------------------------
# Step 7: Save outputs
# ------------------------------------------------------------

cat("\n==========================================\n")
cat("SAVING MODEL FITS\n")
cat("==========================================\n")

fit_poisson$save_object(
  file = here::here("data", "model", "bayesian_model_fits", "poisson_fit.rds")
)
cat("Saved: data/model/bayesian_model_fits/poisson_fit.rds\n")

fit_gpd$save_object(
  file = here::here("data", "model", "bayesian_model_fits", "gpd_fit.rds")
)
cat("Saved: data/model/bayesian_model_fits/gpd_fit.rds\n")

cat("\nPipeline complete.\n")
