# ============================================================
# 03_model_dataset.R
# Don River Flood Risk Model
# Output X_i (exceedances) vector and N (frequency floods) table
# ============================================================


# Load flood_events.csv + u_physical
flood_events <- read_csv(here::here("data", "clean","flood_events.csv"))

u_physical <- read_rds(here::here("data", "clean", "u_physical.rds"))


# Create Frequency table (for Poisson) and Exceedances Vector (for GPD)

freq_floods <- flood_events %>%
  mutate(n_events = count(~year)) %>%
  select(year, n_events)

# X = 
