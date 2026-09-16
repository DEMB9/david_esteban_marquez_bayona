# La limitación de rvest no nos deja leer el html de la pagina
# Se resuelve usando httr2
# Scraping temperaturas diarias Bogotá 2025 - AccuWeather


library(httr2)
library(rvest)
library(purrr)
library(dplyr)
library(tibble)
library(stringr)
library(lubridate)
library(readr)


# 1. URLs de los 12 meses


anio <- 2025

meses_ing <- c(
  "january", "february", "march",     "april",
  "may",     "june",     "july",      "august",
  "september","october", "november",  "december"
)

urls_temps <- paste0(
  "https://www.accuweather.com/es/co/bogota/107487/",
  meses_ing,
  "-weather/107487?year=", anio
)


# 2. Extracción de los días de un mes (tu función, depurada)
#    - localiza el primer "1" del calendario
#    - corta en el primer descenso del contador pasado el día 15
#    - devuelve solo: dia, max, min


extraer_mes <- function(html) {
  
  paneles <- html %>% html_elements("a.monthly-daypanel")
  
  dias <- tibble(
    orden = seq_along(paneles),
    dia   = paneles %>% html_element(".date") %>% html_text2() %>%
      str_trim() %>% as.integer(),
    max   = paneles %>% html_element(".high") %>% html_text2() %>%
      str_remove("°") %>% as.numeric(),
    min   = paneles %>% html_element(".low")  %>% html_text2() %>%
      str_remove("°") %>% as.numeric()
  )
  
  # inicio del mes: primer "1"
  inicio <- which(dias$dia == 1)[1]
  if (is.na(inicio)) return(NULL)
  
  from_inicio <- dias[inicio:nrow(dias), ]
  
  # corte: primer descenso del contador con día < 15
  # (evita cortar el salto normal 30 → 31 de un mes de 31 días)
  corte_rel <- which(diff(from_inicio$dia) < 0 & from_inicio$dia[-1] < 15)[1]
  n_dias    <- if (is.na(corte_rel)) nrow(from_inicio) else corte_rel
  
  from_inicio[seq_len(n_dias), ] %>% select(dia, max, min)
}


# 3. Scraping de un mes completo
#    - pausa entre peticiones
#    - obtiene mes_num desde la URL
#    - agrega fecha (Date) y url_origen


scrapear_mes <- function(u, anio = 2025) {
  
  Sys.sleep(runif(1, 1.5, 3))   # pausa 1.5–3 s
  
  # metadatos desde la URL: nombre del mes en inglés y número
  mes_ing <- str_match(u, "/([a-z]+)-weather/")[, 2]
  mes_num <- match(mes_ing, meses_ing)
  
  html <- tryCatch(
    request(u) %>%
      req_user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36") %>%
      req_headers(
        Accept            = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        `Accept-Language` = "es-CO,es;q=0.9,en;q=0.8"
      ) %>%
      req_retry(max_tries = 3, backoff = ~ 3) %>%
      req_perform() %>%
      resp_body_html(),
    error = function(e) {
      message("  Falló: ", u, " → ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(html)) return(NULL)
  
  dias <- extraer_mes(html)
  if (is.null(dias) || nrow(dias) == 0) return(NULL)
  
  dias %>%
    mutate(
      fecha       = make_date(year = anio, month = mes_num, day = dia),
      url_origen  = u,
      .before     = dia
    ) %>%
    select(fecha, high = max, low = min, url_origen)
}


# 4. Bucle por los 12 meses


datos_clima <- map_dfr(urls_temps, scrapear_mes, anio = anio)


# 5. Verificaciones de calidad


cat("\n--- Resumen del scraping ---\n")
cat("Filas totales:   ", nrow(datos_clima), "\n")
cat("Rango de fechas: ", format(min(datos_clima$fecha)),
    "→", format(max(datos_clima$fecha)), "\n\n")

# 5.1 duplicados
dups <- datos_clima %>% count(fecha) %>% filter(n > 1)
if (nrow(dups) == 0) cat("✔ Sin fechas duplicadas\n") else {
  cat("⚠️  Fechas duplicadas:\n"); print(dups)
}

# 5.2 valores faltantes
cat("\nNA por columna:\n"); print(colSums(is.na(datos_clima)))

# 5.3 cobertura del año
esperado <- seq.Date(
  as.Date(paste0(anio, "-01-01")),
  as.Date(paste0(anio, "-12-31")),
  by = "day"
)
faltan <- setdiff(esperado, datos_clima$fecha)
if (length(faltan) == 0) {
  cat("\n✔ Cobertura completa: 365 días de", anio, "presentes\n")
} else {
  cat("\n  Faltan", length(faltan), "días:\n"); print(faltan)
}

# 5.4 resumen térmico
cat("\nResumen de temperaturas (°C):\n")
print(summary(datos_clima %>% select(high, low)))


# 6. Guardar CSV


dir.create("salidas", showWarnings = FALSE)
write_csv(
  datos_clima,
  file = file.path("salidas", paste0("bogota_temperaturas_", anio, ".csv"))
)
cat("\n✔ Guardado en salidas/bogota_temperaturas_", anio, ".csv\n", sep = "")

print(head(datos_clima, 10))
