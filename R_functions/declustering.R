# ============================================================
# de-clustering.R
# Don River Flood Risk Model
# Goal: A data-frame where each row is one independent flood event
# Process: Manipulate "02HC024_clean.csv" to obtain data-frame
# ============================================================

# --- Load Data/Packages ---
library(tidyverse)
library(here)

flow_data <- read_csv(here::here("data", "clean", "02HC024_clean.csv"))

# --- Define Physical Threshold ---
# Link to threshold data (Don At Todmodern)

rating_curve_data <- NA

# --- Define Minimum Days Separate ---
min_sep <- 3