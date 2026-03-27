# ============================================================
# 04_fit_model.R
# Don River Flood Risk Model
# Goal: Fit Poisson + GPD using MLE (frequenst method first)
# ============================================================

# --- Load Libraries ---
library(tidyverse)
library(here)
library(evd)

# ============================================================
# 1. Load Model Data
# ============================================================

freq_floods <- read_csv(here::here("data", "model", "frequency_data.csv"))
severity_df <- read_csv(here::here("data", "model", "severity_data.csv"))

# Extract exceedances
exceedances <- severity_df$exceedance


# ============================================================
# 2. Fit Frequency Model (Poisson)
# ============================================================

lambda_hat <- mean(freq_floods$n_events)

# ============================================================
# 3. Fit Severity Model (GPD)
# ============================================================

gpd_fit <- evd::fpot(exceedances, threshold = 0)

sigma_hat <- gpd_fit$estimate["scale"]
xi_hat    <- gpd_fit$estimate["shape"]


# ============================================================
# 4. Output Results
# ============================================================

cat("MODEL FIT RESULTS (MLE)\n")
cat("==========================================\n")

cat("\n--- Frequency (Poisson) ---\n")
cat(sprintf("Lambda (mean events/year): %.3f\n", lambda_hat))

cat("\n--- Severity (GPD) ---\n")
cat(sprintf("Sigma (scale): %.3f\n", sigma_hat))
cat(sprintf("Xi (shape):    %.3f\n", xi_hat))

# ============================================================
# 5.Visual Check
# ============================================================


# Overlay fitted GPD density
x_vals <- seq(min(exceedances), max(exceedances), length.out = 100)

gpd_density <- dgpd(x_vals,
                    loc = 0,
                    scale = sigma_hat,
                    shape = xi_hat)

ggplot() +
  geom_histogram(aes(x = exceedances, y = after_stat(density)),
                 bins = 20, alpha = 0.5) +
  geom_line(aes(x = x_vals, y = gpd_density),
            linewidth = 1) +
  labs(
    title = "GPD Fit to Exceedances",
    x = "Exceedance",
    y = "Density"
  )


# ============================================================
# 6.Save Frequentist Data for Review
# ============================================================


# Save Poisson MLE
saveRDS(lambda_hat,
        here::here("data", "model", "frequentist_model_fits", "lambda_hat.rds"))

# Save full GPD fit object
saveRDS(gpd_fit,
        here::here("data", "model", "frequentist_model_fits", "gpd_fit.rds"))

cat("MLE results saved to data/model/frequentist_model_fits/\n")

