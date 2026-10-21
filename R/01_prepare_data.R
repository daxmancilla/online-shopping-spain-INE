# =============================================================================
# 01_prepare_data.R: builds the analysis data set from the TIC-H 2024 microdata
# Input:  data/TICHCuestionario_2024.RData (INE, objects Microdatos and Metadatos)
# Output: data/tich_2024_clean.rds
# =============================================================================

load(here::here("data", "TICHCuestionario_2024.RData"))   # creates Microdatos

tich <- Microdatos %>%
  transmute(
    id     = SERIAL,
    age    = as.numeric(EDAD),
    weight = as.numeric(FACTOR_P),                 # person weight

    # Outcome: bought online in the last 3 months (INE headline indicator).
    # People who did not use the internet in the last year (ULT_COM missing)
    # are counted as non-buyers.
    online_purchase = as.integer(ULT_COM %in% "1"),

    sex = factor(if_else(SEXO == "1", "Man", "Woman"), levels = c("Man", "Woman")),

    age_group = cut(as.numeric(EDAD), breaks = c(15, 24, 34, 44, 54, 64, 74),
                    labels = c("16-24", "25-34", "35-44", "45-54", "55-64", "65-74")),

    # Highest level completed (CNED-2014 codes in NIVELEST)
    education = factor(case_when(
      NIVELEST %in% c("0", "1", "2")      ~ "Up to lower secondary",
      NIVELEST %in% c("3", "4")           ~ "Upper secondary",
      NIVELEST %in% c("5", "6", "7", "8") ~ "Tertiary"),
      levels = c("Up to lower secondary", "Upper secondary", "Tertiary")),

    employment = factor(case_when(
      SIT_LAB == "1"                 ~ "Employee",
      SIT_LAB %in% c("2", "3", "4") ~ "Self-employed",
      SIT_LAB == "5"                 ~ "Unemployed",
      TRUE                           ~ "Inactive"),
      levels = c("Employee", "Self-employed", "Unemployed", "Inactive")),

    # Only asked to employees
    contract = factor(case_when(TIP_CONTR == "1" ~ "Permanent",
                                TIP_CONTR == "2" ~ "Temporary"),
                      levels = c("Temporary", "Permanent")),

    ict_worker = factor(case_when(OCUPACION2 == "1" ~ "ICT",
                                  OCUPACION2 == "6" ~ "Non-ICT"),
                        levels = c("Non-ICT", "ICT")),

    # Net monthly household income (euros)
    income = factor(case_when(
      ING_HOG %in% c("1", "2") ~ "Under 1,600",
      ING_HOG %in% c("3", "4") ~ "1,600 to 2,999",
      ING_HOG == "5"            ~ "3,000 or more",
      ING_HOG == "6"            ~ "Not reported"),
      levels = c("Under 1,600", "1,600 to 2,999", "3,000 or more", "Not reported")),

    household_size = as.numeric(TOT_MH),
    children_10_15 = as.numeric(TOT10_15)
  ) %>%
  filter(between(age, 16, 74))

saveRDS(tich, here::here("data", "tich_2024_clean.rds"))
message("Analysis sample (16-74 years): ", nrow(tich), " people")
