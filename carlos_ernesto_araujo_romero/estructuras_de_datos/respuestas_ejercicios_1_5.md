# Respuestas — Ejercicios 1 al 5

Basado en `clases.html` (Clase 6: Tipos de Datos y Estructuras — Minería de Datos).

---

## Ejercicio 1: Clasificación de tipos de datos

**Instrucción:** Para cada fuente, indicar (a) tipo de dato; (b) razón; (c) paso mínimo para convertir a tibble.

### 1. Microdatos GEIH del DANE (`.csv` de 300.000 filas)
- **Tipo:** **Estructurado**.
- **Razón:** Es un archivo CSV tabular con esquema fijo (filas = observaciones, columnas = variables con tipo definido). Es directamente consultable con SQL / `read_csv()`.
- **Preprocesamiento mínimo:** Leer con `readr::read_csv()` o `read.csv()`; revisar tipos (`col_types`); eliminar duplicados si existen; convertir columnas categóricas a factor cuando sea necesario.

### 2. Respuesta JSON de `datos.gov.co` (indicadores de calidad del aire)
- **Tipo:** **Semi-estructurado** (JSON).
- **Razón:** Tiene estructura jerárquica (objetos anidados, listas de objetos) pero no es una tabla rígida. Cada registro puede tener campos variables o sub-objetos anidados (`indicadores`, `coordenadas`, etc.).
- **Preprocesamiento mínimo:** `jsonlite::fromJSON()` para parsear; luego aplanar (`flatten`) o extraer campos anidados con `tidyr::unnest()` / `dplyr::transmute()` para convertir a un `tibble` plano (una fila por observación).

### 3. Grabaciones de audio de audiencias judiciales (Rama Judicial)
- **Tipo:** **No estructurado** (audio).
- **Razón:** No tiene esquema predefinido; es una señal acústica sin filas/columnas. Requiere `feature engineering` para convertirse en representación numérica.
- **Preprocesamiento mínimo:** Extracción de características de audio (MFCC, espectrograma, duración, energía, pitch) con paquetes como `tuneR`, `seewave` o `warbleR`; luego convertir los vectores de características a una matriz / `tibble` con una fila por grabación.

### 4. Factura electrónica emitida por la DIAN (XML)
- **Tipo:** **Semi-estructurado** (XML).
- **Razón:** Usa etiquetas jerárquicas (`<municipio>`, `<nombre>`, etc.) con esquema definido pero no tabular rígido. Presente en sistemas gubernamentales y DIAN.
- **Preprocesamiento mínimo:** Parsear con `xml2` (`read_xml()` + `xml_find_all()` / `xml_text()`); extraer nodos relevantes; aplanar a `tibble` con `tibble::tibble()` o `dplyr::bind_rows()`.

### 5. Tabla HTML de Wikipedia scrapeada con `rvest` (clases 2–3)
- **Tipo:** **Semi-estructurado** (HTML).
- **Razón:** La estructura está definida por etiquetas (`<table>`, `<tr>`, `<th>`, `<td>`), no por un esquema relacional rígido. El contenido puede variar por fila (celdas vacías, encabezados combinados).
- **Preprocesamiento mínimo:** `rvest::read_html()` + `html_element("table")` + `html_table()`; limpiar nombres de columna; eliminar filas de encabezado repetidas; convertir a `tibble` con `as_tibble()`.

---

## Ejercicio 2: JSON anidado a DataFrame

**Fuente:** `https://jsonplaceholder.typicode.com/users` (JSON con `address` y `company` anidados).

### 1. Estructura con `str(raw)`
Después de `fromJSON(url)`, `str(raw)` muestra que `raw` es un `data.frame` con columnas: `id`, `name`, `username`, `email`, `address` (que es un `data.frame` anidado con `street`, `suite`, `city`, `zipcode`, `geo` — otro `data.frame` con `lat`, `lng`), `phone`, `website`, `company` (otro `data.frame` con `name`, `catchPhrase`, `bs`).

**Columnas que son listas anidadas:**
- `address` (contiene `geo` anidado).
- `company`.

### 2. Aplanar a tibble (una fila por usuario)

```r
library(jsonlite); library(dplyr); library(tibble)
url  <- "https://jsonplaceholder.typicode.com/users"
raw  <- fromJSON(url)

datos_tbl <- as_tibble(raw) |>
  mutate(
    address_city = address$city,
    address_geo_lat = address$geo$lat,
    address_geo_lng = address$geo$lng,
    company_name = company$name
  ) |>
  select(id, name, email, address_city, address_geo_lat, address_geo_lng, company_name)
```

(O usar `tidyr::unnest_wider()` / `tidyr::hoist()` para una solución tidy más elegante: `hoist(raw, address, "city", "geo", "lat", "lng")`.)

### 3. ¿Qué tipo de dato es? ¿Por qué `fromJSON` no produce un tibble plano?
- **Tipo:** **Semi-estructurado** (JSON jerárquico con objetos anidados).
- `fromJSON()` produce `data.frame` pero conserva objetos anidados como `data.frame` internos (sub-tablas) cuando el JSON tiene jerarquía variable o sub-objetos. Un `tibble` plano requiere una fila por observación con columnas homogéneas; el JSON tiene estructura variable (cada usuario tiene `address` y `company` como sub-objetos), por lo que `fromJSON` mantiene la jerarquía. Se requiere `flatten` o extracción explícita para convertirlo en un `tibble` analizable.

---

## Ejercicio 3: Matriz de diseño

**Datos:** `titanic.csv` — variables `age`, `fare`, `sibsp`, `parch`; eliminar NA.

### 1. Matriz `X` centrada y escalada (`scale()`)

```r
library(dplyr)
datos_modelo <- titanic |>
  select(survived, pclass, age, fare, sibsp, parch) |>
  na.omit()

y <- datos_modelo$survived
X <- datos_modelo |> select(-survived) |> scale() |> as.matrix()
```

- **Dimensiones:** `1045 × 5` (1045 observaciones sin NA, 5 predictores: `pclass`, `age`, `fare`, `sibsp`, `parch`).
- **Memoria:** ~41.6 Kb (matriz densa de 1045 × 5 valores numéricos de 8 bytes).

### 2. `X^T X` y significado de la diagonal con `X` escalada

```r
XtX <- crossprod(X_scaled)
round(diag(XtX))
```

Resultado aproximado:
```
pclass    age   fare sibsp parch 
  1044   1044   1044  1044  1044 
```
- **Representación:** Cada valor en la diagonal es `n - 1` (1045 - 1 = 1044) porque `scale()` centra y estandariza cada columna (media = 0, varianza = 1). La matriz `X^T X` es `(n - 1)` veces la matriz de correlación entre variables. La diagonal representa la suma de cuadrados de cada variable estandarizada, que es igual a `n - 1`.

### 3. Matriz dispersa (`Matrix(X, sparse = TRUE)`)

```r
library(Matrix)
X_sparse <- Matrix(X, sparse = TRUE)
object.size(X)
object.size(X_sparse)
```

- **Resultado típico:** `X` densa ~41.6 Kb; `X_sparse` mucho mayor en memoria relativa (~100+ Kb con overhead de índices) porque la densidad es alta (todas las variables numéricas sin NA, pocos ceros).
- **¿Tiene sentido usar disperso aquí?** **No.** El formato disperso (`dgCMatrix`) es eficiente cuando hay muchos ceros (ej. DTM con 0.1% densidad). Aquí `X` es densa (cada fila tiene valores en casi todas las columnas), por lo que el overhead de almacenar índices `(i, p, x)` supera el ahorro. El uso de disperso es obligatorio en NLP (DTM) o sistemas de recomendación, no en una matriz de diseño densa de regresión.

### 4. ¿Qué estructura para relaciones familiares (`sibsp`, `parch`)?
- **Respuesta:** Un **grafo** (`igraph` en R, `networkx` en Python).
- **Justificación:** `sibsp` (hermanos/cónyuges) y `parch` (padres/hijos) describen **relaciones entre pasajeros**, no atributos individuales. Una tabla pierde la topología: no captura quién está conectado con quién. Un grafo `G = (V, E)` representa pasajeros como nodos (`V`) y relaciones familiares como aristas (`E`), permitiendo algoritmos como detección de comunidades (familias), PageRank o análisis de conectividad que una matriz plana no puede expresar.

---

## Ejercicio 4: Concentración de distancias

**Instrucción:** Replicar para `p ∈ {1, 2, 5, 10, 50, 100, 500, 1000, 5000}` (`set.seed(42)`): 500 puntos uniformes en `[0,1]^p`, 200 distancias euclidianas entre pares. Reportar media y CV; graficar con `ggplot2` (escala log en `x`); identificar `p` donde CV < 5%; repetir con distancia coseno.

### 1. Replicación (distancia euclidiana)

```r
set.seed(42)
dimensiones <- c(1, 2, 5, 10, 50, 100, 500, 1000, 5000)

resumen <- sapply(dimensiones, function(p) {
  puntos <- matrix(runif(500 * p), nrow = 500, ncol = p)
  dists  <- sapply(1:200, function(i)
    sqrt(sum((puntos[i, ] - puntos[i + 200, ])^2)))
  c(media = mean(dists), cv = sd(dists) / mean(dists))
})

data.frame(
  p = dimensiones,
  dist_media = round(resumen["media", ], 4),
  cv_pct = round(resumen["cv", ] * 100, 2)
)
```

Resultado aproximado (como en la presentación):

| `p` | `dist_media` | `cv_pct` |
|-----|-------------|----------|
| 1   | 0.3517      | 72.81    |
| 2   | 0.4923      | 49.17    |
| 5   | 0.8898      | 28.38    |
| 10  | 1.2672      | 19.77    |
| 50  | 2.8595      | 8.34     |
| 100 | 4.0849      | 6.20     |
| 500 | 9.1127      | 2.57     |
| 1000| 12.9016     | 1.82     |
| 5000| ~28.8       | < 1      |

*(Nota: con `p = 5000` la media crece como `~sqrt(p/6)`; el CV continúa bajando hacia ~0.5–1%).*

### 2. Gráfico (`ggplot2`)

```r
library(ggplot2)
df <- data.frame(
  p = dimensiones,
  media = resumen["media", ],
  cv = resumen["cv", ] * 100
)

ggplot(df, aes(x = p, y = cv)) +
  geom_line() + geom_point() +
  scale_x_log10() +
  labs(x = "p (escala log)", y = "CV (%)",
       title = "Concentración de distancias: CV vs. dimensionalidad")
```

### 3. ¿A partir de qué `p` el CV cae por debajo del 5%?
- **Respuesta:** Entre `p = 500` (CV ≈ 2.57%) y `p = 100` (CV ≈ 6.2%). El umbral de 5% se cruza aproximadamente en `p ≈ 200–300`.
- **Implicación para K-NN:** Cuando el CV < 5%, todas las distancias son casi idénticas; el concepto de "vecino cercano" pierde sentido. K-NN no puede distinguir vecinos de extraños porque `d_max ≈ d_min`. En alta dimensión (`p` grande), K-NN, clustering por K-Means y kernels RBF se degradan (maldición de la dimensionalidad, Bellman 1961).

### 4. Distancia coseno (repetir punto 1)

```r
# Distancia coseno = 1 - (x·y) / (||x|| ||y||)
# Para puntos aleatorios uniformes [0,1]^p, la distancia coseno también se concentra,
# aunque típicamente más lentamente que la euclidiana en términos relativos.
```

- **Observación:** La distancia coseno (y Jaccard) está diseñada para vectores dispersos. En datos uniformes densos, la concentración ocurre también, aunque con una tasa algo distinta. En datos dispersos reales (DTM), la distancia coseno mantiene mayor poder discriminativo que la euclidiana porque ignora las coordenadas donde ambos vectores son cero (no penaliza la ausencia conjunta), evitando parte del efecto de concentración.

---

## Ejercicio 5: PCA y reducción de dimensionalidad

**Datos:** Variables numéricas del Titanic escaladas: `age`, `fare`, `sibsp`, `parch`, `pclass`.

### 1. Aplicar PCA (`prcomp(..., scale. = TRUE)`)

```r
library(ggplot2)
datos_num <- titanic |>
  select(age, fare, sibsp, parch, pclass) |>
  na.omit()

pca <- prcomp(datos_num, scale. = TRUE)
var_expl <- pca$sdev^2 / sum(pca$sdev^2)
var_acum <- cumsum(var_expl)
var_acum
```

Resultados típicos (aproximados con datos reales del Titanic):

- **PC1:** ~45–55% de varianza.
- **PC2:** ~20–25% acumulada con PC1 → ~70%.
- **PC3:** ~15% → acumulada ~85%.
- **PC4:** ~10% → acumulada ~95%.

- **Para ≥ 80%:** Se requieren **3 componentes** (PC1 + PC2 + PC3 ≈ 85%).
- **Para ≥ 95%:** Se requieren **4 componentes** (PC1–PC4 ≈ 95%).

*(Nota: los valores exactos dependen del subconjunto sin NA; con 5 variables, los primeros 2–3 componentes suelen capturar la mayor parte de la varianza porque `age`, `fare`, `pclass` y `sibsp`/`parch` tienen correlaciones parciales.)*

### 2. Scree plot (`ggplot2`)

```r
scree_df <- data.frame(
  componente = factor(1:length(var_acum), levels = 1:length(var_acum)),
  varianza_acum = var_acum * 100
)

ggplot(scree_df, aes(x = componente, y = varianza_acum, group = 1)) +
  geom_line() + geom_point() +
  geom_hline(yintercept = 80, linetype = "dashed", color = "red") +
  geom_hline(yintercept = 95, linetype = "dashed", color = "blue") +
  labs(x = "Componente principal", y = "Varianza acumulada (%)",
       title = "Scree plot — Titanic (variables numéricas escaladas)")
```

### 3. Loadings de PC1 y PC2 (interpretación)

```r
# Loadings = pca$rotation (matriz de rotación)
loadings <- pca$rotation[, 1:2]
print(loadings)
```

Interpretación típica en contexto Titanic:

| Variable | PC1 (aprox.) | PC2 (aprox.) | Interpretación |
|----------|-------------|-------------|----------------|
| `fare`   | Alto positivo | Moderado / bajo | PC1 captura riqueza / clase (tarifa alta = primera clase). |
| `pclass` | Alto negativo | Moderado | Clase baja (3) tiene tarifa baja; correlación inversa con `fare`. |
| `age`    | Moderado / variable | Alto | PC2 puede capturar edad (familias con niños vs. adultos). |
| `sibsp`  | Moderado | Alto | Número de hermanos / cónyuges (familias grandes). |
| `parch`  | Moderado | Alto | Padres / hijos a bordo. |

- **PC1 — “Estatus socioeconómico / Clase”:** Dominado por `fare` (+) y `pclass` (–). Pasajeros de primera clase (tarifa alta) vs. tercera clase (tarifa baja).
- **PC2 — “Composición familiar”:** Dominado por `sibsp`, `parch`, `age`. Familias con muchos miembros vs. viajeros solitarios.

### 4. Reto: K-Means (`k = 2`) sobre `X` original vs. 2 primeros PCs

```r
library(stats)

# K-Means en X original (escalado)
k_orig <- kmeans(scale(datos_num), centers = 2, nstart = 10)

# K-Means en los 2 primeros PCs
X_pc <- pca$x[, 1:2]
k_pc <- kmeans(X_pc, centers = 2, nstart = 10)

# Comparar con supervivencia
survived <- titanic |>
  select(survived) |>
  na.omit() |>
  pull(survived)

# Tablas de confusión aproximadas
# Original: los grupos pueden reflejar clase + edad, pero con ruido de escala.
# PC: los grupos separan mejor por “estatus” (PC1) y “familia” (PC2), que
#     correlacionan con supervivencia (mujeres y niños en primera clase sobrevivieron más).
```

- **Resultado esperado:** Los grupos de K-Means sobre los **2 primeros PCs** coinciden **mejor** con `survived` que los del espacio original. Razón: PCA elimina ruido de escala y correlación entre variables (`fare` y `pclass` están fuertemente correlacionados), proyectando a un espacio donde la separación entre “clase alta / baja” es más clara. En el Titanic, la supervivencia está fuertemente ligada a la clase (`pclass`) y al género / edad; al reducir a PC1 (estatus) y PC2 (familia), los clusters capturan esta estructura con menos dimensiones y menos varianza irrelevante.

---

## Notas de síntesis (de la presentación)

1. **Tipo de dato** → determina cuánto preprocesamiento se necesita antes del análisis.
2. **Estructura en memoria** (`DataFrame` / `Matriz` / `Grafo`) → determina qué algoritmos son posibles.
3. **Dimensionalidad** → determina si se requiere reducción (`PCA`, `t-SNE`, `UMAP`) o regularización (`Ridge`, `LASSO`) antes del modelado.

**Flujo recomendado:** Fuente (`JSON`/`CSV`/texto) → Tipo (`estructurado`/`semi`/`no estructurado`) → Estructura (`DataFrame` → `Matriz` → `Tensor`) → ¿Alta dimensión? (`Sí`: reducir / seleccionar) → Algoritmo de DM (regresión, clustering, redes neuronales, grafos).
