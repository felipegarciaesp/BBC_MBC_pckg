# BBC_MBC_pckg
Código en donde se implementa el paquete MBC de Canon para realizar corrección de sesgo en series de cambio climático (bias correction).

Para revisar la documentación, visitar la siguiente página: https://cran.r-project.org/web/packages/MBC/index.html

En la primera versión del código se implementa el método QDM, en donde se identifica lo siguiente:
- ratio = TRUE es apropiado para precipitación ya que usa cocientes en lugar de diferencias
- trace = 0.05 define el umbral mínimo de precipitación (valores bajo este se tratan como cero)
