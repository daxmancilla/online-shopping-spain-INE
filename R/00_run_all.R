# =============================================================================
# Online shopping in Spain: who buys on the internet? (INE TIC-H 2024)
# 00_run_all.R: runs the whole pipeline
# -----------------------------------------------------------------------------
# Author: Dax Mancilla
# Data:   INE, Survey on Equipment and Use of ICT in Households (TIC-H), 2024
# =============================================================================

# Packages: install once with
# install.packages(c("here", "dplyr", "ggplot2", "survey", "scales", "tidyr"))

here::i_am("R/00_run_all.R")

source(here::here("R", "utils.R"))
source(here::here("R", "01_prepare_data.R"))
source(here::here("R", "02_descriptive.R"))
source(here::here("R", "03_model.R"))
