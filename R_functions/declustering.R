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

# --- Pull Physical Threshold ---
u_physical <- read_rds(here::here("data", "clean", "u_physical.rds"))


# --- Pull Minimum Days Separate ---
min_days_independent <- read_rds(here::here("data", "clean", "min_days_independent.rds"))

# ============================================================
# decluster_events()
#
# Arguments:
#   flow_data            → cleaned daily flow dataframe
#   threshold            → u_physical in m3/s
#   min_days_independent → minimum dry days between events
#
# Returns:
#   dataframe with one row per independent flood event
#   columns: event_id, start_date, end_date, year, month,
#            season, Q_peak, D, V, excess_peak
# ============================================================

decluster_events <- function(flow_data,
                             threshold,
                             min_days_independent = 3) {
  
  # --- initialize tracking variables ---
  events      <- list()   # stores completed events
  in_event    <- FALSE    # are we currently in a flood event
  dry_streak  <- 0        # how many consecutive days below threshold
  event_flows <- c()      # flow values during current event
  event_dates <- c()      # dates during current event
  
  # --- walk through every day chronologically ---
  for(i in seq(nrow(flow_data))) {
    
    flow_i <- flow_data$flow[i]
    date_i <- flow_data$date[i]
    
    # skip missing flow values
    if(is.na(flow_i)) next
    
    # -----------------------------------------------
    # CASE 1: flow is above threshold today
    # -----------------------------------------------
    if(flow_i >= threshold) {
      
      if(!in_event) {
        # flow just crossed above threshold
        # start tracking a new event
        in_event    <- TRUE
        dry_streak  <- 0
        event_flows <- flow_i
        event_dates <- date_i
        
      } else {
        # already in an event, flow is still high
        # keep accumulating
        dry_streak  <- 0
        event_flows <- c(event_flows, flow_i)
        event_dates <- c(event_dates, date_i)
      }
      
      # -----------------------------------------------
      # CASE 2: flow is below threshold today
      # -----------------------------------------------
    } else {
      
      if(in_event) {
        # we were in an event but flow dropped below threshold
        # increment dry day counter
        dry_streak <- dry_streak + 1
        
        if(dry_streak >= min_days_independent) {
          # flow has been below threshold for min_days_independent days
          # this event is officially over so save it
          
          excess <- event_flows - threshold
          
          events[[length(events) + 1]] <- tibble(
            event_id   = length(events) + 1,
            start_date = min(event_dates),
            end_date   = max(event_dates),
            year       = year(min(event_dates)),
            month      = month(min(event_dates)),
            season     = case_when(
              month(min(event_dates)) %in% c(3, 4, 5)  ~ "Spring",
              month(min(event_dates)) %in% c(6, 7, 8)  ~ "Summer",
              month(min(event_dates)) %in% c(9, 10, 11) ~ "Fall",
              TRUE                                       ~ "Winter"
            ),
            Q_peak       = max(event_flows),       # max flow during event
            duration     = length(event_flows),    # duration in days
            volume_excess = sum(excess),      # volume above threshold
            excess_peak  = max(excess)             # Q_peak - threshold
          )
          
          # reset everything for the next event
          in_event    <- FALSE
          dry_streak  <- 0
          event_flows <- c()
          event_dates <- c()
        }
      }
    }
  }
  
  # --- edge case: event still open at end of record ---
  if(in_event && length(event_flows) > 0) {
    
    excess <- event_flows - threshold
    
    events[[length(events) + 1]] <- tibble(
      event_id    = length(events) + 1,
      start_date  = min(event_dates),
      end_date    = max(event_dates),
      year        = year(min(event_dates)),
      month       = month(min(event_dates)),
      season      = case_when(
        month(min(event_dates)) %in% c(3, 4, 5)  ~ "Spring",
        month(min(event_dates)) %in% c(6, 7, 8)  ~ "Summer",
        month(min(event_dates)) %in% c(9, 10, 11) ~ "Fall",
        TRUE                                       ~ "Winter"
      ),
      Q_peak      = max(event_flows),
      D           = length(event_flows),
      V           = sum(excess),
      excess_peak = max(excess)
    )
  }
  
  # --- combine all events into one dataframe ---
  flood_events <- bind_rows(events)
  
  # --- print summary ---
  cat("==========================================\n")
  cat("Declustering Complete\n")
  cat("==========================================\n")
  cat(sprintf("Threshold:          %.1f m3/s\n", threshold))
  cat(sprintf("Min separation:     %d days\n", min_days_independent))
  cat(sprintf("Independent events: %d\n", nrow(flood_events)))
  cat(sprintf("Years of record:    %d\n", n_distinct(flood_events$year)))
  cat(sprintf("Mean events/year:   %.2f\n",
              nrow(flood_events) / n_distinct(flow_data$year)))
  cat("==========================================\n")
  
  return(flood_events)
}

# --- Run Function ---
flood_events <- decluster_events(
  flow_data            = flow_data,
  threshold            = u_physical,
  min_days_independent = min_days_independent
)

# --- Save Output ---
write_csv(flood_events,
          here::here("data", "clean", "flood_events.csv"))

# --- Preview ---
glimpse(flood_events)
head(flood_events)
