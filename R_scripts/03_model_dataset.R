# ============================================================
# 03_model_dataset.R
# Don River Flood Risk Model
# Output:
#   - X: exceedance vector (GPD)
#   - N_year: yearly event counts (Poisson)
# ============================================================

library(tidyverse)
library(here)

# --- Load data ---
flood_events <- read_csv(here::here("data", "clean", "flood_events.csv"))
u_physical   <- read_rds(here::here("data", "clean", "u_physical.rds"))

# ============================================================
# 1. Frequency Dataset (Poisson)
# ============================================================

freq_floods <- flood_events %>%
  group_by(year) %>%
  summarise(
    n_events = n()
  )

# ============================================================
# 2. Severity Dataset (GPD)
# ============================================================

severity_floods <- flood_events %>%
  mutate(exceedance = Q_peak - u_physical) %>%
  pull(exceedance)

# ============================================================
# 3. Save outputs
# ============================================================

write_csv(freq_floods,
          here::here("data", "model", "frequency_data.csv"))

write_csv(tibble(exceedance = severity_floods),
          here::here("data", "model", "severity_data.csv"))

# ============================================================
# 4. Check Diagnostics
# ============================================================

cat("Model Dataset Created\n")
cat("==========================================\n")
cat(sprintf("Years: %d\n", nrow(freq_floods)))
cat(sprintf("Total events: %d\n", sum(freq_floods$n_events)))
cat(sprintf("Mean events/year: %.2f\n", mean(freq_floods$n_events)))
cat(sprintf("Number of exceedances: %d\n", length(severity_floods)))