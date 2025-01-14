library(tidyverse)

## set destination s3 paths
s3 <- arrow::s3_bucket("bio230121-bucket01", endpoint_override = "renc.osn.xsede.org")
s3$CreateDir("vera4cast/targets/duration=P1D")
s3$CreateDir("vera4cast/targets/duration=PT1H")

s3_daily <- arrow::s3_bucket("bio230121-bucket01/vera4cast/targets/project_id=vera4cast/duration=P1D", endpoint_override = "renc.osn.xsede.org")
s3_hourly <- arrow::s3_bucket("bio230121-bucket01/vera4cast/targets/project_id=vera4cast/duration=PT1H", endpoint_override = "renc.osn.xsede.org")

column_names <- c("project_id", "site_id","datetime","duration", "depth_m","variable","observation")

## EXO
source('targets/target_functions/target_generation_exo_daily.R')
fcr_files <- c("https://pasta.lternet.edu/package/data/eml/edi/271/7/71e6b946b751aa1b966ab5653b01077f",
               "https://raw.githubusercontent.com/FLARE-forecast/FCRE-data/fcre-catwalk-data-qaqc/fcre-waterquality_L1.csv")

bvr_files <- c("https://raw.githubusercontent.com/FLARE-forecast/BVRE-data/bvre-platform-data-qaqc/bvre-waterquality_L1.csv",
               "https://pasta.lternet.edu/package/data/eml/edi/725/3/a9a7ff6fe8dc20f7a8f89447d4dc2038")

exo_daily <- target_generation_exo_daily(fcr_files, bvr_files)

exo_daily$duration <- 'P1D'
exo_daily$project_id <- 'vera4cast'


### NOTE : RDO DO DATA IS INCLUDED IN THE EXO TARGET GENERATION SCRIPT


## FLUOROPROBE
source('targets/target_functions/target_generation_FluoroProbe.R')
historic_data <- "https://portal.edirepository.org/nis/dataviewer?packageid=edi.272.7&entityid=001cb516ad3e8cbabe1fdcf6826a0a45"
current_data <- "https://raw.githubusercontent.com/CareyLabVT/Reservoirs/master/Data/DataNotYetUploadedToEDI/Raw_fluoroprobe/fluoroprobe_L1.csv"

fluoro_daily <- target_generation_FluoroProbe(current_file = current_data, historic_file = historic_data)
fluoro_daily$duration <- 'P1D'
fluoro_daily$project_id <- 'vera4cast'


### TEMP STRING
source('targets/target_functions/target_generation_ThermistorTemp_C_daily.R')

# FCR
fcr_latest <- "https://raw.githubusercontent.com/FLARE-forecast/FCRE-data/fcre-catwalk-data-qaqc/fcre-waterquality_L1.csv"
fcr_edi <- "https://pasta.lternet.edu/package/data/eml/edi/271/7/71e6b946b751aa1b966ab5653b01077f"

fcr_thermistor_temp_daily <- target_generation_ThermistorTemp_C_daily(current_file = fcr_latest, historic_file = fcr_edi)
fcr_thermistor_temp_daily$duration <- 'P1D'
fcr_thermistor_temp_daily$project_id <- 'vera4cast'

# BVR
bvr_latest <- "https://raw.githubusercontent.com/FLARE-forecast/BVRE-data/bvre-platform-data-qaqc/bvre-waterquality_L1.csv"
bvr_edi <- "https://pasta.lternet.edu/package/data/eml/edi/725/3/a9a7ff6fe8dc20f7a8f89447d4dc2038"

bvr_thermistor_temp_daily <- target_generation_ThermistorTemp_C_daily(current_file = bvr_latest, historic_file = bvr_edi)
bvr_thermistor_temp_daily$duration <- 'P1D'
bvr_thermistor_temp_daily$project_id <- 'vera4cast'


#Secchi
source('targets/target_functions/target_generation_daily_secchi_m.R')
current = "https://raw.githubusercontent.com/CareyLabVT/Reservoirs/master/Data/DataNotYetUploadedToEDI/Secchi/secchi_L1.csv"
edi = "https://pasta.lternet.edu/package/data/eml/edi/198/11/81f396b3e910d3359907b7264e689052"

secchi_daily <- target_generation_daily_secchi_m(current = current, edi = edi) |>
  filter(site_id %in% c('fcre', 'bvre'))

secchi_daily$duration <- 'P1D'
secchi_daily$project_id <- 'vera4cast'

## combine the data and perform final adjustments (depth, etc.)

combined_targets <- bind_rows(exo_daily, fluoro_daily, fcr_thermistor_temp_daily, bvr_thermistor_temp_daily, secchi_daily) |>
  select(all_of(column_names))

combined_targets_deduped <- combined_targets |>
  group_by(datetime, site_id, variable, depth_m) |>
  mutate(obs_deduped = mean(observation, na.rm = TRUE)) |>
  ungroup() |>
  distinct(datetime, site_id, variable, depth_m, .keep_all = TRUE) |>
  select(project_id, site_id, datetime, duration, depth_m, variable, observation)

combined_dup_check <- combined_targets_deduped  %>%
  dplyr::group_by(datetime, site_id, variable, depth_m) %>%
  dplyr::summarise(n = dplyr::n(), .groups = "drop") %>%
  dplyr::filter(n > 1)

if (nrow(combined_dup_check) != 0){
  print('target duplicates found...please fix')
  stop()
}

arrow::write_csv_arrow(combined_targets_deduped, sink = s3_daily$path("daily-insitu-targets.csv.gz"))


## INFLOWS
source('targets/target_functions/inflow/target_generation_inflows.R')

current_inflow <- 'https://raw.githubusercontent.com/FLARE-forecast/FCRE-data/fcre-weir-data-qaqc/FCRWeir_L1.csv'

historic_inflow <- "https://pasta.lternet.edu/package/data/eml/edi/202/10/c065ff822e73c747f378efe47f5af12b"

historic_silica <- 'https://pasta.lternet.edu/package/data/eml/edi/542/1/791ec9ca0f1cb9361fa6a03fae8dfc95'

historic_nutrients <- "https://pasta.lternet.edu/package/data/eml/edi/199/11/509f39850b6f95628d10889d66885b76"

historic_ghg <- "https://pasta.lternet.edu/package/data/eml/edi/551/7/38d72673295864956cccd6bbba99a1a3"


inflow_daily <- target_generation_inflows(historic_inflow = historic_inflow,
                                          current_inflow = current_inflow,
                                          historic_nutrients = historic_nutrients,
                                          historic_silica = historic_silica,
                                          historic_ghg = historic_ghg)

inflow_daily <- inflow_daily |> select(column_names)

arrow::write_csv_arrow(inflow_daily, sink = s3_daily$path("daily-inflow-targets.csv.gz"))


# MET TARGETS
current_met <- 'https://raw.githubusercontent.com/FLARE-forecast/FCRE-data/fcre-metstation-data-qaqc/FCRmet_L1.csv'
historic_met <- 'https://pasta.lternet.edu/package/data/eml/edi/389/7/02d36541de9088f2dd99d79dc3a7a853'

source('targets/target_functions/meteorology/target_generation_met.R')

met_daily <- target_generation_met(current_met = current_met, historic_met = historic_met, time_interval = 'daily')

met_daily <- met_daily |>
  select(all_of(column_names))

arrow::write_csv_arrow(met_daily, sink = s3_daily$path("daily-met-targets.csv.gz"))

met_hourly <- target_generation_met(current_met = current_met, historic_met = historic_met, time_interval = 'hourly')

met_hourly <- met_hourly |>
  select(all_of(column_names))

arrow::write_csv_arrow(met_hourly, sink = s3_hourly$path("hourly-met-targets.csv.gz"))
