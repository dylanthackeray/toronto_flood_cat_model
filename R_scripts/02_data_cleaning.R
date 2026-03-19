# ============================================================
# 02_data_cleaning.R
# Don River Flood Risk Model
# Transform raw HYDAT flow data into an analysis-ready data set
# ============================================================

# --- Load packages ---
library(tidyverse)
library(lubridate)
library(here)

# --- Project root ---
cat("Project root:", here(), "\n")

# --- Parameters ---
STATION_ID <- "02HC024"

RAW_FILE   <- here("data", "raw", paste(STATION_ID, "_raw.csv"))
CLEAN_DIR  <- here("data", "clean")
CLEAN_FILE <- here("data", "clean", paste(STATION_ID, "_clean.csv"))

# --- Create clean directory ---
if (!dir.exists(CLEAN_DIR)) {
  dir.create(CLEAN_DIR, recursive = TRUE)
  cat("Created directory:", CLEAN_DIR, "\n")
}

# --- Load raw data ---
cat("Loading raw data...\n")
raw_flow <- read_csv(RAW_FILE, show_col_types = FALSE)

# --- Inspect structure ---
cat("Rows:", nrow(raw_flow), "\n")
cat("Columns:", paste(names(raw_flow), collapse = ", "), "\n")

# --- Standardize column names ---
raw_flow <- raw_flow %>%
  rename_with(tolower)

# --- Change Data Structure ---

raw_flow <- raw_flow %>%
  rename(flow = value, symbol_flag = symbol) %>%
  mutate(
    date = as.Date(date),
    flow = as.numeric(flow)
  ) %>%
  select(date, flow, symbol_flag)

# --- Sort by date ---
raw_flow <- raw_flow %>%
  arrange(date)

# --- Missing data summary ---
missing_flow <- sum(is.na(raw_flow$flow))
missing_symbol_flag <- sum(is.na(raw_flow$symbol_flag))


cat("Missing values for flow:", missing_flow, "\n")
cat("Missing values for symbol_flag:", missing_symbol_flag, "\n")


# --- Add time-based features --- (planned to use in future from moving to non-stationary model)
clean_flow <- raw_flow %>%
  mutate(
    year  = year(date),
    month = month(date),
    day   = day(date),
    
    # Hydrological year
    hydrologic_year = if_else(month >= 10, year + 1, year),
    
    # Seasonal grouping
    season = case_when(
      month %in% c(12, 1, 2) ~ "Winter",
      month %in% c(3, 4, 5)  ~ "Spring",
      month %in% c(6, 7, 8)  ~ "Summer",
      TRUE ~ "Fall"
    )
  )

# --- remove rows with missing flow ---
clean_flow <- clean_flow %>%
  filter(!is.na(flow))

# -- add flagging column for symbol_flag (useful for capturing all data vs most precise data) 
clean_flow <- clean_flow %>%
  mutate(quality = case_when(
    symbol_flag == "A" ~ "measured",
    symbol_flag == "E" ~ "estimated",
    symbol_flag == "B" ~ "flagged",
    TRUE ~ "unspecified"
  )) # this is the general-clean data set, one can filter / select however they like to make it more specific to what analysis they want to do. *eg: I currently limiting myself to stationarity analysis so I will not be using day, month, hydrological_year columns* 


# --- Save cleaned data set ---
write_csv(clean_flow, CLEAN_FILE)

cat("Cleaned data saved to:", CLEAN_FILE, "\n")