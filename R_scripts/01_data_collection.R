# ============================================================
# 01_data_collection.R
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

