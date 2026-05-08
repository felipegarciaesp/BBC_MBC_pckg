# BC_MBC_pckg — Bias Correction con método QDM

Herramienta para realizar corrección de sesgo de series de cambio climático utilizando el método **Quantile Delta Mapping (QDM)** del paquete `MBC` de R (Cannon).

Para revisar la documentación, visitar la siguiente página: https://cran.r-project.org/web/packages/MBC/index.html

---

## Requisitos previos

- R >= 4.0
- Paquetes: `openxlsx`, `tidyverse`, `hydroTSM`, `lubridate`, `lmomco`, `reshape2`, `MBC`, `trend`, `pacman`

---

## Estructura de carpetas

El script espera la siguiente estructura de directorios dentro de la carpeta raíz del proyecto:

```
BC_MBC_pckg/
├── Inputs/          ← archivos Excel de entrada (preparados por el usuario)
├── Outputs/         ← archivos Excel de salida (generados automáticamente)
└── BC_MBC_pckg.R    ← script principal
```

> La carpeta `Outputs/` es creada automáticamente por el script si no existe. La carpeta `Inputs/` debe ser creada manualmente por el usuario.

---

## Archivos de entrada (Inputs/)

Cada archivo Excel debe ser colocado directamente dentro de la carpeta `Inputs/` y su nombre debe seguir estrictamente la siguiente estructura:

```
N_Estacion_variable_temporal_escenario_raw_analysis.xlsx
```

| Campo        | Descripción                                                                 | Ejemplos                          |
|--------------|-----------------------------------------------------------------------------|-----------------------------------|
| `N`          | Número identificador de la estación (dos dígitos)                          | `01`, `02`, `03`                  |
| `Estacion`   | Nombre de la estación                                                       | `Vicuna`, `SanJose`               |
| `variable`   | Variable climática                                                          | `pr`, `tas`, `tasmin`, `tasmax`   |
| `temporal`   | Resolución temporal de la data                                              | `ann`, `mon`, `daily`             |
| `escenario`  | Escenario al que corresponde la data                                        | `obs`, `historical`, `ssp245`, `ssp585` |

### Escenarios disponibles

| Escenario    | Descripción                        |
|--------------|------------------------------------|
| `obs`        | Data histórica observada           |
| `historical` | Data GCM periodo histórico         |
| `ssp245`     | Data GCM escenario futuro SSP2-4.5 |
| `ssp585`     | Data GCM escenario futuro SSP5-8.5 |

### Resoluciones temporales disponibles

| Código  | Descripción   |
|---------|---------------|
| `ann`   | Anual         |
| `mon`   | Mensual       |
| `daily` | Diaria        |

### Ejemplo de nombres de archivos para una estación

```
Inputs/
├── 01_Vicuna_pr_ann_obs_raw_analysis.xlsx
├── 01_Vicuna_pr_ann_historical_raw_analysis.xlsx
├── 01_Vicuna_pr_ann_ssp245_raw_analysis.xlsx
└── 01_Vicuna_pr_ann_ssp585_raw_analysis.xlsx
```

Para procesar múltiples estaciones y/o variables simultáneamente, simplemente agregar los archivos correspondientes en la misma carpeta `Inputs/`:

```
Inputs/
├── 01_Vicuna_pr_ann_obs_raw_analysis.xlsx
├── 01_Vicuna_pr_ann_historical_raw_analysis.xlsx
├── 01_Vicuna_pr_ann_ssp245_raw_analysis.xlsx
├── 01_Vicuna_pr_ann_ssp585_raw_analysis.xlsx
├── 02_SanJose_tas_daily_obs_raw_analysis.xlsx
├── 02_SanJose_tas_daily_historical_raw_analysis.xlsx
├── 02_SanJose_tas_daily_ssp245_raw_analysis.xlsx
└── 02_SanJose_tas_daily_ssp585_raw_analysis.xlsx
```

---

## Formato interno de los archivos Excel

- Cada archivo Excel debe contener una única pestaña llamada **`Data`**.
- La **primera columna** debe contener la referencia temporal:
  - Para data **anual** (`ann`): años enteros (ej: `1979`, `1980`, ...).
  - Para data **mensual** (`mon`) o **diaria** (`daily`): fechas en formato `YYYY-MM-DD`.
- Las columnas siguientes deben contener los valores de cada modelo GCM (para archivos `historical`, `ssp245`, `ssp585`) o el valor observado (para archivos `obs`).
- En el archivo `obs`, el script utiliza la **segunda columna** como vector de observaciones.

---

## Archivos de salida (Outputs/)

Los archivos de salida son generados automáticamente en la carpeta `Outputs/` con la siguiente estructura de nombres:

```
N_Estacion_variable_temporal_escenario_BC.xlsx
```

Donde `escenario` puede ser `historical`, `ssp245` o `ssp585`, y el sufijo `_BC` indica que la data ha sido corregida por sesgo.

### Ejemplo

```
Outputs/
├── 01_Vicuna_pr_ann_historical_BC.xlsx
├── 01_Vicuna_pr_ann_ssp245_BC.xlsx
├── 01_Vicuna_pr_ann_ssp585_BC.xlsx
├── 02_SanJose_tas_daily_historical_BC.xlsx
├── 02_SanJose_tas_daily_ssp245_BC.xlsx
└── 02_SanJose_tas_daily_ssp585_BC.xlsx
```

---

## Parámetros modificables por el usuario

Los siguientes parámetros pueden ser ajustados directamente en el script `BC_MBC_pckg.R`:

### Periodo histórico de análisis

```r
yr_hist_start <- 1979   # Año de inicio del periodo histórico
yr_hist_end   <- 2013   # Año de término del periodo histórico
```

### Parámetro `trace` para precipitación

El parámetro `trace` define el umbral mínimo de precipitación (valores bajo este umbral se tratan como cero). Solo aplica cuando la variable es `pr`. Sus valores por defecto son:

```r
trace_pr_ann   <- 1      # Data anual   [mm/año]
trace_pr_mon   <- 0.1    # Data mensual [mm/mes]
trace_pr_daily <- 0.05   # Data diaria  [mm/día]
```

### Parámetro `ratio`

El parámetro `ratio` es asignado automáticamente por el script según la variable:

| Variable              | `ratio` | Descripción                                      |
|-----------------------|---------|--------------------------------------------------|
| `pr`                  | `TRUE`  | Precipitación: corrección por cocientes          |
| `tas`, `tasmin`, `tasmax` | `FALSE` | Temperatura: corrección por diferencias     |

### Directorio de trabajo

```r
setwd("C:/Codigos/BC_MBC_pckg")   # Ruta raíz del proyecto
```

---

## Funcionamiento del script

El script procesa automáticamente todos los grupos de archivos disponibles en `Inputs/`, agrupándolos por estación, variable y resolución temporal. Por cada grupo detectado:

1. Lee los cuatro archivos de escenarios (`obs`, `historical`, `ssp245`, `ssp585`).
2. Filtra los datos al periodo histórico definido por el usuario.
3. Aplica QDM modelo por modelo para SSP2-4.5 y SSP5-8.5.
4. Exporta los resultados corregidos en `Outputs/`.

