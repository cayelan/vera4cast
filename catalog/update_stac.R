library(jsonlite)
library(arrow)
library(dplyr)
library(lubridate)

#reticulate::miniconda_path() |>
#  reticulate::use_miniconda()

#Generate EFI model metadata
source('catalog/model_metadata.R')

# catalog
source('catalog/catalog.R')

# forecasts
source('catalog/forecasts/forecast_models.R')

rm(list = ls()) # remove all environmental vars between forecast and scores

# scores
source('catalog/scores/scores_models.R')


