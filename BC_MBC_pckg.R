# =====================================================================
# Codigo para realizar correcion de sesgo de series de cambio climatico
# con el paquete MBC de Cannon / Felipe Garcia
# =====================================================================

## Limpiar ambiente
#-------------------
rm(list=ls())
graphics.off()
cat("\014")

## Carga de paquetes
#-------------------
library(pacman)
p_load(openxlsx, tidyverse, hydroTSM, lubridate, lmomco, reshape2, MBC, trend)

## Directorio de trabajo
#-------------------
setwd("C:/Codigos/BC_MBC_pckg")
dir_inputs  <- file.path(getwd(), "Inputs")
dir_outputs <- file.path(getwd(), "Outputs")

if (!dir.exists(dir_outputs)) dir.create(dir_outputs)

## Definicion del periodo historico a analizar
#-------------------
yr_hist_start <- 1979
yr_hist_end   <- 2013

## Parametros de QDM modificables por el usuario
#-------------------
trace_pr_ann   <- 1      # umbral mínimo precipitacion - data anual   [mm/año]
trace_pr_mon   <- 0.1    # umbral mínimo precipitacion - data mensual [mm/mes]
trace_pr_daily <- 0.05   # umbral mínimo precipitacion - data diaria  [mm/dia]

# =====================================================================
# FUNCIONES AUXILIARES
# =====================================================================

get_ratio <- function(variable) {
  variable %in% c("pr")
}

get_trace <- function(variable, temporal) {
  if (variable == "pr") {
    switch(temporal,
      "ann"   = trace_pr_ann,
      "mon"   = trace_pr_mon,
      "daily" = trace_pr_daily
    )
  } else {
    0
  }
}

convert_first_col <- function(df, temporal) {
  if (temporal == "ann") {
    df[,1] <- as.integer(df[,1])
  } else {
    col <- df[,1]
    if (is.numeric(col)) {
      df[,1] <- openxlsx::convertToDate(col)
    } else {
      df[,1] <- as.Date(col, format = "%Y-%m-%d")
    }
  }
  df
}

# Parsea el nombre de un archivo Excel (sin extension) y extrae sus componentes
# Estructura esperada: N_Estacion_variable_temporal_escenario_raw_analysis.xlsx
known_escenarios <- c("obs", "historical", "ssp245", "ssp585")
known_temporales <- c("daily", "mon", "ann")

parse_file_name <- function(file_name) {
  base  <- gsub("\\.xlsx$", "", file_name)
  base  <- gsub("_raw_analysis$", "", base)
  parts <- strsplit(base, "_")[[1]]
  
  idx_temporal  <- which(parts %in% known_temporales)
  idx_escenario <- which(parts %in% known_escenarios)
  
  N         <- parts[1]
  temporal  <- parts[idx_temporal]
  escenario <- parts[idx_escenario]
  variable  <- parts[idx_temporal - 1]
  estacion  <- paste(parts[2:(idx_temporal - 2)], collapse = "_")
  
  list(N = N, estacion = estacion, variable = variable,
       temporal = temporal, escenario = escenario, file = file_name)
}

read_file_data <- function(file_path, temporal) {
  df <- openxlsx::read.xlsx(file_path, sheet = "Data", colNames = TRUE)
  df <- convert_first_col(df, temporal)
  df
}

# =====================================================================
# DETECCION AUTOMATICA DE ARCHIVOS Y AGRUPACION
# =====================================================================

all_files <- list.files(dir_inputs, pattern = "_raw_analysis\\.xlsx$")

file_info <- lapply(all_files, parse_file_name)

# Agrupar por (N, estacion, variable, temporal)
groups <- list()
for (info in file_info) {
  key <- paste(info$N, info$estacion, info$variable, info$temporal, sep = "_")
  if (is.null(groups[[key]])) groups[[key]] <- list(info = info, scenarios = list())
  groups[[key]]$scenarios[[info$escenario]] <- file.path(dir_inputs, info$file)
}

# =====================================================================
# PROCESAMIENTO POR GRUPO: estacion + variable + resolucion temporal
# =====================================================================

for (group_key in names(groups)) {
  
  group     <- groups[[group_key]]
  scenarios <- group$scenarios
  info      <- group$info
  
  temporal  <- info$temporal
  variable  <- info$variable
  ratio     <- get_ratio(variable)
  trace_val <- get_trace(variable, temporal)
  
  ## Lectura de datos
  data_obs    <- read_file_data(scenarios[["obs"]],        temporal)
  data_hist   <- read_file_data(scenarios[["historical"]], temporal)
  data_ssp245 <- read_file_data(scenarios[["ssp245"]],     temporal)
  data_ssp585 <- read_file_data(scenarios[["ssp585"]],     temporal)
  
  ## Filtrar periodo historico
  if (temporal == "ann") {
    data_obs  <- data_obs  %>% filter(.[[1]] >= yr_hist_start & .[[1]] <= yr_hist_end)
    data_hist <- data_hist %>% filter(.[[1]] >= yr_hist_start & .[[1]] <= yr_hist_end)
  } else {
    data_obs  <- data_obs  %>% filter(year(.[[1]]) >= yr_hist_start & year(.[[1]]) <= yr_hist_end)
    data_hist <- data_hist %>% filter(year(.[[1]]) >= yr_hist_start & year(.[[1]]) <= yr_hist_end)
  }
  
  ## Separar columna de tiempo y matrices de datos GCM
  yr_hist   <- data_hist[,1]
  yr_ssp245 <- data_ssp245[,1]
  yr_ssp585 <- data_ssp585[,1]
  
  mat_hist   <- as.matrix(data_hist[,-1])
  mat_ssp245 <- as.matrix(data_ssp245[,-1])
  mat_ssp585 <- as.matrix(data_ssp585[,-1])
  
  obs       <- data_obs[,2]
  gcm_names <- colnames(mat_hist)
  n_models  <- ncol(mat_hist)
  
  ## Aplicar QDM modelo por modelo
  qdm_result_ssp245 <- list()
  qdm_result_ssp585 <- list()
  
  for (i in 1:n_models) {
    qdm_result_ssp245[[i]] <- MBC::QDM(
      o.c   = obs,
      m.c   = mat_hist[,i],
      m.p   = mat_ssp245[,i],
      ratio = ratio,
      trace = trace_val
    )
    qdm_result_ssp585[[i]] <- MBC::QDM(
      o.c   = obs,
      m.c   = mat_hist[,i],
      m.p   = mat_ssp585[,i],
      ratio = ratio,
      trace = trace_val
    )
  }
  
  names(qdm_result_ssp245) <- gcm_names
  names(qdm_result_ssp585) <- gcm_names
  
  ## Construir dataframes con resultados corregidos
  bc_hist <- data.frame(yr = yr_hist,
    sapply(qdm_result_ssp245, function(x) x$mhat.c))
  colnames(bc_hist)[-1] <- gcm_names
  
  bc_ssp245 <- data.frame(yr = yr_ssp245,
    sapply(qdm_result_ssp245, function(x) x$mhat.p))
  colnames(bc_ssp245)[-1] <- gcm_names
  
  bc_ssp585 <- data.frame(yr = yr_ssp585,
    sapply(qdm_result_ssp585, function(x) x$mhat.p))
  colnames(bc_ssp585)[-1] <- gcm_names
  
  ## Exportar resultados directamente en Outputs/
  # Nombre: N_Estacion_variable_temporal_escenario_BC.xlsx
  prefix <- paste(info$N, info$estacion, info$variable, temporal, sep = "_")
  
  openxlsx::write.xlsx(bc_hist,
    file = file.path(dir_outputs, paste0(prefix, "_historical_BC.xlsx")),
    sheetName = "Data", rowNames = FALSE)
  
  openxlsx::write.xlsx(bc_ssp245,
    file = file.path(dir_outputs, paste0(prefix, "_ssp245_BC.xlsx")),
    sheetName = "Data", rowNames = FALSE)
  
  openxlsx::write.xlsx(bc_ssp585,
    file = file.path(dir_outputs, paste0(prefix, "_ssp585_BC.xlsx")),
    sheetName = "Data", rowNames = FALSE)
  
  message("✓ Procesado: ", group_key)
}
