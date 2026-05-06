# =====================================================================
# Codigo para realizar correcion de sesgo de series de cambio climatico
# con el paquete MBC de Cannon / Felipe Garcia
# Fuente: https://cran.r-project.org/web/packages/MBC/index.html
# =====================================================================

## Limpiar ambiente
#-------------------
# Clean workspace
rm(list=ls())
graphics.off()
# Clear console
cat("\014")
#-------------------

## Carga de paquetes
#-------------------
library(pacman)
p_load(openxlsx, tidyverse, hydroTSM, lubridate, lmomco, 
       reshape2, MBC, trend)
#-------------------

## Definición del directorio de trabajo
#-------------------
# 1.Se define carpeta donde se encuentra la data de los GCM: 
dir_GCM <- "C:/Codigos/BC_MBC_pckg/Data_GCM"

# 2. Se define carpeta donde se encuentra la data observada:
dir_OBS <- "C:/Codigos/BC_MBC_pckg/Data_OBS"

# Se define como directorio de trabajo la raiz del proyecto
setwd("C:/Codigos/BC_MBC_pckg")


## Definicion nombres archivos GCM
#-------------------
# se definen los nombres de los archivos Excel que tienen la data de los GCM a analizar y de la data historica.
file_GCM_hist <- "GCM_historical_ABRSEP.xlsx"
file_GCM_ssp245 <- "GCM_ssp245_ABRSEP.xlsx"
file_GCM_ssp585 <- "GCM_ssp585_ABRSEP.xlsx"
file_obs <- "OBS_ABRSEP.xlsx"

#-------------------

## Definicion del periodo historico a analizar
#-------------------
yr_hist_start <- 1979
yr_hist_end <- 2014

#-------------------


## Manejo de matrices
#-------------------
# En esta seccion se comienza a trabajar las matrices que contienen la informacion para realizar el escalamiento

## 1. MATRICES CON DATA MODELOS GCM:

## 1.1 DATA GCM HISTORICO:
data_raw_hist <- openxlsx::read.xlsx(file.path(dir_GCM, file_GCM_hist), sheet = "Data", colNames = T)

# Como se va a trabajar con data anual, se deja claro a R que la primera columna son "integer"
data_raw_hist[,1] <- as.integer(data_raw_hist[,1])

# Seleccionar solo datos comprendidos en el periodo historico definido
data_raw_hist <- data_raw_hist %>% filter(yr >= yr_hist_start & yr <= yr_hist_end)

## 1.2 DATA GCM SSP245:
data_raw_ssp245 <- openxlsx::read.xlsx(file.path(dir_GCM, file_GCM_ssp245), sheet = "Data", colNames = T)

# Como se va a trabajar con data anual, se deja claro a R que la primera columna son "integer"
data_raw_ssp245[,1] <- as.integer(data_raw_ssp245[,1])

## 1.3 DATA GCM SSP585:
data_raw_ssp585 <- openxlsx::read.xlsx(file.path(dir_GCM, file_GCM_ssp585), sheet = "Data", colNames = T)

# Como se va a trabajar con data anual, se deja claro a R que la primera columna son "integer"
data_raw_ssp585[,1] <- as.integer(data_raw_ssp585[,1])

## 2. VECTOR CON DATA OBSERVADA:
data_obs <- openxlsx::read.xlsx(file.path(dir_OBS, file_obs), sheet = "Data", colNames = T)

# Como se va a trabajar con data anual, se deja claro a R que la primera columna son "integer"
data_obs[,1] <- as.integer(data_obs[,1])

# Seleccionar solo datos comprendidos en el periodo historico definido
data_obs <- data_obs %>% filter(yr >= yr_hist_start & yr <= yr_hist_end)

# =====================================================================
# IMPLEMENTACION DE PAQUETE MBC PARA BIAS CORRECTION
# =====================================================================

## Corrección de sesgo con QDM (Quantile Delta Mapping)
#-------------------

# Separar columna de años de las matrices de datos
yr_hist   <- data_raw_hist[,1]
yr_ssp245 <- data_raw_ssp245[,1]
yr_ssp585 <- data_raw_ssp585[,1]

# Matrices solo con datos GCM (sin columna de años)
mat_hist   <- as.matrix(data_raw_hist[,-1])
mat_ssp245 <- as.matrix(data_raw_ssp245[,-1])
mat_ssp585 <- as.matrix(data_raw_ssp585[,-1])

# Vector de observaciones (segunda columna de data_obs)
obs <- data_obs[,2]

# Nombres de los modelos GCM
gcm_names <- colnames(mat_hist)
n_models  <- ncol(mat_hist)

# Listas para almacenar resultados QDM
qdm_result_ssp245 <- list()
qdm_result_ssp585 <- list()

# Aplicar QDM modelo por modelo
for(i in 1:n_models){
  
  # QDM para SSP245
  qdm_result_ssp245[[i]] <- MBC::QDM(
    o.c   = obs,           # Observaciones periodo historico
    m.c   = mat_hist[,i],  # GCM periodo historico
    m.p   = mat_ssp245[,i],# GCM periodo futuro SSP245
    ratio = TRUE,          # TRUE para precipitación (usa cocientes)
    trace = 0.05           # Umbral minimo de precipitacion
  )
  
  # QDM para SSP585
  qdm_result_ssp585[[i]] <- MBC::QDM(
    o.c   = obs,
    m.c   = mat_hist[,i],
    m.p   = mat_ssp585[,i],
    ratio = TRUE,
    trace = 0.05
  )
}

names(qdm_result_ssp245) <- gcm_names
names(qdm_result_ssp585) <- gcm_names

# Construir dataframes con resultados corregidos
# Historico corregido (mhat.c)
bc_hist <- data.frame(
  yr = yr_hist,
  sapply(qdm_result_ssp245, function(x) x$mhat.c)
)
colnames(bc_hist)[-1] <- gcm_names

# Futuro corregido SSP245 (mhat.p)
bc_ssp245 <- data.frame(
  yr = yr_ssp245,
  sapply(qdm_result_ssp245, function(x) x$mhat.p)
)
colnames(bc_ssp245)[-1] <- gcm_names

# Futuro corregido SSP585 (mhat.p)
bc_ssp585 <- data.frame(
  yr = yr_ssp585,
  sapply(qdm_result_ssp585, function(x) x$mhat.p)
)
colnames(bc_ssp585)[-1] <- gcm_names

## Exportar resultados a Excel
#-------------------
openxlsx::write.xlsx(bc_hist,   file = file.path(getwd(), "bc_hist.xlsx"),   sheetName = "Data", rowNames = FALSE)
openxlsx::write.xlsx(bc_ssp245, file = file.path(getwd(), "bc_ssp245.xlsx"), sheetName = "Data", rowNames = FALSE)
openxlsx::write.xlsx(bc_ssp585, file = file.path(getwd(), "bc_ssp585.xlsx"), sheetName = "Data", rowNames = FALSE)
