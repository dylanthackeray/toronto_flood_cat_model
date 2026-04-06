# ============================================================
# simulate_loss.R
# Don River Flood Risk Model
# Goal: Build the engine for calculating losses
# ============================================================


# L(x) = ax^B
# a: alpha (dollars lost per exceedence flow increase)
# B: Beta ()


library(here)
library(evd)
library(tidyverse)
library(posterior)

set.seed(123)

# --- Load Bayesian fits ---
bayesian_pois <- readRDS(here::here("data", "model", "bayesian_model_fits", "poisson_fit.rds"))
bayesian_gpd  <- readRDS(here::here("data", "model", "bayesian_model_fits", "gpd_fit.rds"))

pois_draws <- as_draws_df(bayesian_pois$draws())
gpd_draws  <- as_draws_df(bayesian_gpd$draws())

posterior_sample <- tibble(
  lambda = pois_draws$lambda,
  sigma  = gpd_draws$sigma,
  xi     = gpd_draws$xi
) %>%
  sample_n(1000)

# ============================================================
# Loss simulator (single parameter set)
# ============================================================

simulate_losses <- function(lambda, sigma, xi, alpha, beta, n_years = 1) {
  
  total_losses <- numeric(n_years)
  
  for (year in 1:n_years) {
    
    N <- rpois(1, lambda)
    
    if (N > 0) {
      X <- rgpd(N, loc = 0, scale = sigma, shape = xi)
      losses <- alpha * (X ^ beta)
      total_losses[year] <- sum(losses)
    } else {
      total_losses[year] <- 0
    }
  }
  
  return(total_losses)
}

# ============================================================
# Bayesian Loss Simulation
# ============================================================

simulate_posterior_losses <- function(posterior_sample, alpha, beta, n_sim = 10000) {
  
  n_sim <- min(n_sim, nrow(posterior_sample))
  annual_losses <- numeric(n_sim)
  
  for (i in 1:n_sim) {
    
    lambda <- posterior_sample$lambda[i]
    sigma  <- posterior_sample$sigma[i]
    xi     <- posterior_sample$xi[i]
    
    annual_losses[i] <- simulate_losses(lambda, sigma, xi, alpha, beta, n_years = 1)
  }
  
  return(annual_losses)
}

# ============================================================
# Run Simulation
# ============================================================

losses <- simulate_posterior_losses(posterior_sample, alpha = 100, beta = 2)

# ============================================================
# Summary Stats
# ============================================================

cat("Loss Simulation Complete\n")
cat(sprintf("Simulations: %d\n", length(losses)))
cat(sprintf("Mean Loss: %.2f\n", mean(losses)))
cat(sprintf("Median Loss: %.2f\n", median(losses)))
cat(sprintf("90th Percentile: %.2f\n", quantile(losses, 0.9)))
cat(sprintf("99th Percentile: %.2f\n", quantile(losses, 0.99)))
cat(sprintf("Max Loss: %.2f\n", max(losses)))
