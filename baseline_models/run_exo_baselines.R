print(paste0("Running Creating baselines at ", Sys.time()))

library(tidyverse)
library(lubridate)
library(aws.s3)
library(imputeTS)
library(tsibble)
library(fable)


#' set the random number for reproducible MCMC runs
set.seed(329)

config <- yaml::read_yaml("challenge_configuration.yaml")

#'Team name code
team_name <- "climatology"


targets <- readr::read_csv(paste0("https://", config$endpoint, "/", config$targets_bucket, "/project_id=vera4cast/duration=P1D/daily-insitu-targets.csv.gz"), guess_max = 10000)


sites <- read_csv(config$site_table, show_col_types = FALSE)

site_names <- sites$site_id

target_clim <- targets %>%
  filter(variable %in% c("Chla_ugL_mean","Temp_C_mean")) %>%
  mutate(doy = yday(datetime)) %>%
  group_by(doy, site_id, variable) %>%
  summarise(clim_mean = mean(observation, na.rm = TRUE),
            clim_sd = sd(observation, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(clim_mean = ifelse(is.nan(clim_mean), NA, clim_mean))

#curr_month <- month(Sys.Date())
curr_month <- month(Sys.Date())
if(curr_month < 10){
  curr_month <- paste0("0", curr_month)
}

curr_year <- year(Sys.Date())
start_date <- Sys.Date() + days(1)

forecast_dates <- seq(start_date, as_date(start_date + days(35)), "1 day")
forecast_doy <- yday(forecast_dates)

forecast_dates_df <- tibble(datetime = forecast_dates,
                            doy = forecast_doy)

forecast <- target_clim %>%
  mutate(doy = as.integer(doy)) %>%
  filter(doy %in% forecast_doy) %>%
  full_join(forecast_dates_df, by = 'doy') %>%
  arrange(site_id, datetime)

subseted_site_names <- unique(forecast$site_id)
site_vector <- NULL
for(i in 1:length(subseted_site_names)){
  site_vector <- c(site_vector, rep(subseted_site_names[i], length(forecast_dates)))
}

forecast_tibble1 <- tibble(datetime = rep(forecast_dates, length(subseted_site_names)),
                           site_id = site_vector,
                           variable = "Chla_ugL_mean")

forecast_tibble2 <- tibble(datetime = rep(forecast_dates, length(subseted_site_names)),
                           site_id = site_vector,
                           variable = "Temp_C_mean")

forecast_tibble <- bind_rows(forecast_tibble1, forecast_tibble2)

foreast <- right_join(forecast, forecast_tibble, by = join_by("site_id", "variable", "datetime"))

site_count <- forecast %>%
  select(datetime, site_id, variable, clim_mean, clim_sd) %>%
  filter(!is.na(clim_mean)) |>
  group_by(site_id, variable) %>%
  summarize(count = n(), .groups = "drop") |>
  filter(count > 2) |>
  distinct() |>
  pull(site_id)

combined <- forecast %>%
  filter(site_id %in% site_count) |>
  select(datetime, site_id, variable, clim_mean, clim_sd) %>%
  rename(mean = clim_mean,
         sd = clim_sd) %>%
  group_by(site_id, variable) %>%
  mutate(mu = imputeTS::na_interpolation(x = mean),
         sigma = median(sd, na.rm = TRUE))

combined <- combined %>%
  pivot_longer(c("mu", "sigma"),names_to = "parameter", values_to = "prediction") |>
  mutate(family = "normal") |>
  mutate(reference_datetime = min(combined$datetime) - lubridate::days(1),
         model_id = "climatology") |>
  select(model_id, datetime, reference_datetime, site_id, variable, family, parameter, prediction)

combined %>%
  filter(variable == "Chla_ugL_mean") |>
  pivot_wider(names_from = parameter, values_from = prediction) %>%
  ggplot(aes(x = datetime)) +
  geom_ribbon(aes(ymin=mu - sigma*1.96, ymax=mu + sigma*1.96), alpha = 0.1) +
  geom_point(aes(y = mu)) +
  facet_wrap(~site_id)

combined_insitu <- combined |>
  mutate(depth_m = ifelse(site_id == "fcre", 1.6, 1.5),
         project_id = "vera4cast",
         duration = "P1D")

file_date <- combined$reference_datetime[1]

print(paste0("Running Creating baselines at ", Sys.time()))

#' set the random number for reproducible MCMC runs
set.seed(329)

forecast_horizon <- 35

config <- yaml::read_yaml("challenge_configuration.yaml")

#'Team name code
team_name <- "climatology"


targets <- readr::read_csv(paste0("https://", config$endpoint, "/", config$targets_bucket, "/project_id=vera4cast/duration=P1D/daily-met-targets.csv.gz"), guess_max = 10000, show_col_types = FALSE)

sites <- read_csv(config$site_table, show_col_types = FALSE)

site_names <- sites$site_id

target_clim <- targets %>%
  filter(variable %in% c("AirTemp_C_mean")) %>%
  mutate(doy = yday(datetime)) %>%
  group_by(doy, site_id, variable) %>%
  summarise(clim_mean = mean(observation, na.rm = TRUE),
            clim_sd = sd(observation, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(clim_mean = ifelse(is.nan(clim_mean), NA, clim_mean))

#curr_month <- month(Sys.Date())
curr_month <- month(Sys.Date())
if(curr_month < 10){
  curr_month <- paste0("0", curr_month)
}

curr_year <- year(Sys.Date())
start_date <- Sys.Date() + days(1)

forecast_dates <- seq(start_date, as_date(start_date + days(forecast_horizon)), "1 day")
forecast_doy <- yday(forecast_dates)

forecast_dates_df <- tibble(datetime = forecast_dates,
                            doy = forecast_doy)

forecast <- target_clim %>%
  mutate(doy = as.integer(doy)) %>%
  filter(doy %in% forecast_doy) %>%
  full_join(forecast_dates_df, by = 'doy') %>%
  arrange(site_id, datetime)

subseted_site_names <- unique(forecast$site_id)
site_vector <- NULL
for(i in 1:length(subseted_site_names)){
  site_vector <- c(site_vector, rep(subseted_site_names[i], length(forecast_dates)))
}

forecast_tibble1 <- tibble(datetime = rep(forecast_dates, length(subseted_site_names)),
                           site_id = site_vector,
                           variable = "AirTemp_C_mean")

forecast_tibble2 <- NULL


forecast_tibble <- bind_rows(forecast_tibble1, forecast_tibble2)

foreast <- right_join(forecast, forecast_tibble, by = join_by("site_id", "variable", "datetime"))

site_count <- forecast %>%
  select(datetime, site_id, variable, clim_mean, clim_sd) %>%
  filter(!is.na(clim_mean)) |>
  group_by(site_id, variable) %>%
  summarize(count = n(), .groups = "drop") |>
  filter(count > 2) |>
  distinct() |>
  pull(site_id)

combined <- forecast %>%
  filter(site_id %in% site_count) |>
  select(datetime, site_id, variable, clim_mean, clim_sd) %>%
  rename(mean = clim_mean,
         sd = clim_sd) %>%
  group_by(site_id, variable) %>%
  mutate(mu = imputeTS::na_interpolation(x = mean),
         sigma = median(sd, na.rm = TRUE))

combined <- combined %>%
  pivot_longer(c("mu", "sigma"),names_to = "parameter", values_to = "prediction") |>
  mutate(family = "normal") |>
  mutate(reference_datetime = min(combined$datetime) - lubridate::days(1),
         model_id = "climatology") |>
  select(model_id, datetime, reference_datetime, site_id, variable, family, parameter, prediction)

#combined %>%
#  filter(variable == "AirTemp_C_mean") |>
#  pivot_wider(names_from = parameter, values_from = prediction) %>%
#  ggplot(aes(x = datetime)) +
#  geom_ribbon(aes(ymin=mu - sigma*1.96, ymax=mu + sigma*1.96), alpha = 0.1) +
#  geom_point(aes(y = mu)) +
#  facet_wrap(~site_id)

combined_met <- combined |>
  mutate(depth_m = NA,
         site_id = "fcre",
         project_id = "vera4cast",
         duration = "P1D")


####

targets <- readr::read_csv(paste0("https://", config$endpoint, "/", config$targets_bucket, "/project_id=vera4cast/duration=P1D/daily-inflow-targets.csv.gz"), guess_max = 10000, show_col_types = FALSE)

site_names <- "tubr"

target_clim <- targets %>%
  filter(variable %in% c("Flow_cms_mean","Temp_C_mean")) %>%
  mutate(doy = yday(datetime)) %>%
  group_by(doy, site_id, variable) %>%
  summarise(clim_mean = mean(observation, na.rm = TRUE),
            clim_sd = sd(observation, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(clim_mean = ifelse(is.nan(clim_mean), NA, clim_mean))

#curr_month <- month(Sys.Date())
curr_month <- month(Sys.Date())
if(curr_month < 10){
  curr_month <- paste0("0", curr_month)
}

curr_year <- year(Sys.Date())
start_date <- Sys.Date() + days(1)

forecast_dates <- seq(start_date, as_date(start_date + days(forecast_horizon)), "1 day")
forecast_doy <- yday(forecast_dates)

forecast_dates_df <- tibble(datetime = forecast_dates,
                            doy = forecast_doy)

forecast <- target_clim %>%
  mutate(doy = as.integer(doy)) %>%
  filter(doy %in% forecast_doy) %>%
  full_join(forecast_dates_df, by = 'doy') %>%
  arrange(site_id, datetime)

subseted_site_names <- unique(forecast$site_id)
site_vector <- NULL
for(i in 1:length(subseted_site_names)){
  site_vector <- c(site_vector, rep(subseted_site_names[i], length(forecast_dates)))
}

forecast_tibble1 <- tibble(datetime = rep(forecast_dates, length(subseted_site_names)),
                           site_id = site_vector,
                           variable = "Flow_cms_mean")

forecast_tibble2 <- tibble(datetime = rep(forecast_dates, length(subseted_site_names)),
                           site_id = site_vector,
                           variable = "Temp_C_mean")


forecast_tibble <- bind_rows(forecast_tibble1, forecast_tibble2)

foreast <- right_join(forecast, forecast_tibble, by = join_by("site_id", "variable", "datetime"))

site_count <- forecast %>%
  select(datetime, site_id, variable, clim_mean, clim_sd) %>%
  filter(!is.na(clim_mean)) |>
  group_by(site_id, variable) %>%
  summarize(count = n(), .groups = "drop") |>
  filter(count > 2) |>
  distinct() |>
  pull(site_id)

combined <- forecast %>%
  filter(site_id %in% site_count) |>
  select(datetime, site_id, variable, clim_mean, clim_sd) %>%
  rename(mean = clim_mean,
         sd = clim_sd) %>%
  group_by(site_id, variable) %>%
  mutate(mu = imputeTS::na_interpolation(x = mean),
         sigma = median(sd, na.rm = TRUE))

combined <- combined %>%
  pivot_longer(c("mu", "sigma"),names_to = "parameter", values_to = "prediction") |>
  mutate(family = "normal") |>
  mutate(reference_datetime = min(combined$datetime) - lubridate::days(1),
         model_id = "climatology") |>
  select(model_id, datetime, reference_datetime, site_id, variable, family, parameter, prediction)

combined %>%
  pivot_wider(names_from = parameter, values_from = prediction) %>%
  ggplot(aes(x = datetime)) +
  geom_ribbon(aes(ymin=mu - sigma*1.96, ymax=mu + sigma*1.96), alpha = 0.1) +
  geom_point(aes(y = mu)) +
  facet_wrap(~variable, scale = "free")

combined_inflow <- combined |>
  mutate(depth_m = NA,
         site_id = "tubr",
         project_id = "vera4cast",
         duration = "P1D")


combined <- bind_rows(combined_met,combined_inflow, combined_insitu)

combined %>%
  pivot_wider(names_from = parameter, values_from = prediction) %>%
  ggplot(aes(x = datetime)) +
  geom_ribbon(aes(ymin=mu - sigma*1.96, ymax=mu + sigma*1.96), alpha = 0.1) +
  geom_point(aes(y = mu)) +
  facet_grid(variable~site_id, scales = "free")

file_date <- combined$reference_datetime[1]

forecast_file <- paste("daily", file_date, "climatology.csv.gz", sep = "-")

write_csv(combined, forecast_file)

vera4castHelpers::forecast_output_validator(forecast_file)

vera4castHelpers::submit(forecast_file = forecast_file,
                         ask = FALSE,
                         first_submission = FALSE)

unlink(forecast_file)

source('R/fablePersistenceModelFunction.R')

targets <- readr::read_csv(paste0("https://", config$endpoint, "/", config$targets_bucket, "/project_id=vera4cast/duration=P1D/daily-insitu-targets.csv.gz"), guess_max = 10000)


targets <- targets |> mutate(datetime = lubridate::as_date(datetime)) |>
  filter(variable %in% c("Chla_ugL_mean","Temp_C_mean"),
         ((depth_m == 1.6 & site_id == "fcre") | (depth_m == 1.5 & site_id == "bvre")))


# 2. Make the targets into a tsibble with explicit gaps
targets_ts <- targets %>%
  as_tsibble(key = c('variable', 'site_id', 'depth_m', 'duration', 'project_id'), index = 'datetime') %>%
  # add NA values up to today (index)
  fill_gaps(.end = Sys.Date())

# 3. Run through each via map
site_var_combinations <- expand.grid(site = unique(targets$site_id),
                                     var = unique(targets_ts$variable)) %>%
  # assign the transformation depending on the variable. le is logged
  mutate(transformation = 'none') %>%
  mutate(boot_number = 200,
         h = 37,
         bootstrap = T,
         verbose = T)

# Runs the RW forecast for each combination of variable and site_id
RW_forecasts <- purrr::pmap_dfr(site_var_combinations, RW_daily_forecast)

# convert the output into EFI standard
RW_forecasts_EFI <- as_tibble(RW_forecasts) %>%
  rename(parameter = .rep,
         prediction = .sim) %>%
  # For the EFI challenge we only want the forecast for future
  filter(datetime > Sys.Date()) %>%
  mutate(datetime = lubridate::as_datetime(datetime)) |>
  group_by(site_id, variable) %>%
  mutate(reference_datetime = min(datetime) - lubridate::days(1),
         family = "ensemble",
         model_id = "persistenceRW") %>%
  select(model_id, datetime, reference_datetime, site_id, family, parameter, variable, prediction)

RW_forecasts_EFI <- RW_forecasts_EFI |>
  mutate(depth_m = ifelse(site_id == "fcre", 1.6, 1.5),
         project_id = "vera4cast",
         duration = "P1D")

# 4. Write forecast file
file_date <- RW_forecasts_EFI$reference_datetime[1]

forecast_file <- paste("daily", file_date, "persistenceRW.csv.gz", sep = "-")

write_csv(RW_forecasts_EFI, forecast_file)

RW_forecasts_EFI %>%
  ggplot(aes(x = datetime, y = prediction, group = parameter)) +
  geom_line() +
  facet_grid(variable~site_id)

vera4castHelpers::submit(forecast_file = forecast_file,
                         ask = FALSE,
                         first_submission = FALSE)

unlink(forecast_file)

