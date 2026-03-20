# ============================================================
# 01_data_collection_flow_rate.R
# Don River Flood Risk Model
# Extracts from HYDAT DATA (flow data) specific to Don Todmodern
# ============================================================


library(tidyhydat)
library(tidyverse)
library(lubridate)
library(here)

# --- Parameters ---
STATION_ID <- "02HC024" # Don Todmodern ID
START_DATE <- "1960-01-01"
END_DATE   <- Sys.Date()

# --- Define paths ---
DATA_DIR <- here("data", "raw")
FILE_PATH <- file.path(DATA_DIR, paste0(STATION_ID, "_raw.csv"))

# --- Create directories ---
if(!dir.exists(DATA_DIR)) dir.create(DATA_DIR, recursive = TRUE)

# --- Download HYDAT ---
tidyhydat::download_hydat()

# --- Pull data ---
cat("Pulling streamflow data for station", STATION_ID, "...\n")
raw_flow <- hy_daily_flows(
  station_number = STATION_ID,
  start_date     = START_DATE,
  end_date       = END_DATE
)

# --- Basic summary ---
cat("Observations:", nrow(raw_flow), "from", min(raw_flow$Date), "to", max(raw_flow$Date), "\n")

# --- Save raw data ---
write_csv(raw_flow, FILE_PATH)
cat("Raw data saved to:", FILE_PATH, "\n")

# ============================================================
# 01_data_collection_rating_curve.R
# Don River Flood Risk Model
# Purpose: Parse and reshape Environment Canada rating curve data
# Source: https://wateroffice.ec.gc.ca/download/index_e.html
# ============================================================

# IMPORTANT: This file is a static historical download
# The water level data only starts from 2002
# This is a known limitation for future automation — see METHODOLOGY.md

# --- Load Packages ---
library(tidyverse)
library(here)

# --- Load Raw Data ---
rating_data <- read_csv(
  here::here("data", "raw", "02HC024_rating_curve_Environment_Canada.csv"),
  skip = 1
)

# --- Separate Discharge and Water Level ---
discharge <- rating_data %>%
  filter(PARAM == 1)

water_level <- rating_data %>%
  filter(PARAM == 2)

# --- Reshape To Long Format ---
water_level_long <- water_level %>%
  select(YEAR, DD, Jan, Feb, Mar, Apr, May,
         Jun, Jul, Aug, Sep, Oct, Nov, Dec) %>%
  pivot_longer(
    cols      = Jan:Dec,
    names_to  = "month_name",
    values_to = "water_level_m"
  ) %>%
  filter(!is.na(water_level_m))

discharge_long <- discharge %>%
  select(YEAR, DD, Jan, Feb, Mar, Apr, May,
         Jun, Jul, Aug, Sep, Oct, Nov, Dec) %>%
  pivot_longer(
    cols      = Jan:Dec,
    names_to  = "month_name",
    values_to = "discharge_m3s"
  ) %>%
  filter(!is.na(discharge_m3s))

# --- Join Discharge and Water Level ---
rating_curve <- discharge_long %>%
  inner_join(water_level_long,
             by = c("YEAR", "DD", "month_name"))

# --- Save Processed Rating Curve ---
write_csv(rating_curve, here::here("data", "clean", "02HC024_rating_curve_clean.csv"))
cat("Rating curve saved to data/clean/02HC024_rating_curve_clean.csv\n")
cat("Observations:", nrow(rating_curve), "\n")
cat("Water level range:", round(min(rating_curve$water_level_m), 2),
    "->", round(max(rating_curve$water_level_m), 2), "m\n")
cat("Discharge range:", round(min(rating_curve$discharge_m3s), 2),
    "->", round(max(rating_curve$discharge_m3s), 2), "m³/s\n")


