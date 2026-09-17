# Respuestas — Ejercicios 1 al 5

---

## Ejercicio 1: Clasificación de tipos de datos

**Instrucción:** Para cada fuente, indicar (a) tipo de dato; (b) razón; (c) paso mínimo para convertir a tibble.

### 1. Microdatos GEIH del DANE (`.csv` de 300.000 filas)
- **Tipo:** **Estructurado**.
- **Razón:** Pues es el clásico archivo CSV que ya viene ordenadito en filas y columnas, cada columna tiene su tipo claro y no hay que inventarle nada. Se lee de una con SQL o `read_csv`.
- **Preprocesamiento mínimo:** Leerlo con `readr::read_csv()` (o `read.csv` si toca), echarle un ojo a los tipos de columna por si acaso, volar duplicados si los hay y pasar las variables de texto a factor si se van a usar así.

### 2. Respuesta JSON de `datos.gov.co` (indicadores de calidad del aire)
- **Tipo:** **Semi-estructurado** (JSON).
- **Razón:** Tiene una estructura en árbol o jerarquía (con listas adentro y objetos anidados), pero no es la típica tablita cuadrada de Excel. Los registros pueden cambiar un poco o traer sub-objetos (`coordenadas`, etc.).
- **Preprocesamiento mínimo:** Usar `jsonlite::fromJSON()` para que baje a R, y luego aplicarle un `flatten()` o desanidar las listas con `tidyr::unnest()` para que quede una sola fila por cada lectura.

### 3. Grabaciones de audio de audiencias judiciales (Rama Judicial)
- **Tipo:** **No estructurado** (audio).
- **Razón:** Ahí no hay filas ni columnas por ningún lado, es pura onda de sonido (`.mp3` o lo que sea). Para poder meterlo a un modelo o tabla toca sacarle características numéricas a mano (*feature engineering*).
- **Preprocesamiento mínimo:** Extraer las propiedades del audio (como MFCC, energía, espectrogramas o el pitch) usando paquetes tipo `tuneR` o `seewave`, y armar una tablita donde cada fila sea una grabación y las columnas sean esos numeritos extraídos.

### 4. Factura electrónica emitida por la DIAN (XML)
- **Tipo:** **Semi-estructurado** (XML).
- **Razón:** Se basa en etiquetas tipo `<nombre>` o `<nit>` que se anidan unas dentro de otras. Está organizado, sí, pero no en formato tabular clásico.
- **Preprocesamiento mínimo:** Usar la librería `xml2` con `read_xml()` y buscar los nodos clave con `xml_find_all()`. De ahí extraer el texto y armar el `tibble` con `dplyr::bind_rows()` o similar.

### 5. Tabla HTML de Wikipedia scrapeada con `rvest` (clases 2–3)
- **Tipo:** **Semi-estructurado** (HTML).
- **Razón:** Viene directo de etiquetas de una página web (`<table>`, `<tr>`, etc.). Aunque se vea como tabla en la página, por dentro es HTML y a veces trae celdas combinadas o vacías que molestan.
- **Preprocesamiento mínimo:** Usar `rvest::read_html()`, coger la tabla con `html_table()`, limpiar un poco los nombres de las columnas que suelen venir feos, quitar filas de más y pasarlo a `as_tibble()`.

---

## Ejercicio 2: JSON anidado a DataFrame

**Fuente:** `https://jsonplaceholder.typicode.com/users` (JSON con `address` y `company` anidados).

### 1. Estructura con `str(raw)`
Si corremos `fromJSON(url)`, el `str(raw)` nos enseña que es un data frame normal con columnas como `id`, `name`, `email`, pero mete otras que son tablas enteras adentro, por ejemplo `address` (que a su vez trae `geo` con `lat` y `lng`) y la columna `company`.

**Columnas que son listas anidadas:**
- `address` (y dentro tiene a `geo`).
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

*(También se puede tirar un `tidyr::unnest_wider()` o un `hoist` para que quede más limpio, pero así manual funciona bien).*

### 3. ¿Qué tipo de dato es? ¿Por qué `fromJSON` no produce un tibble plano?
- **Tipo:** **Semi-estructurado** (JSON con jerarquías y objetos adentro).
- `fromJSON()` te arma un data frame pero respeta las sub-tablas si el JSON venía así de armado. Para que un `tibble` sea plano necesita que todas las celdas tengan valores simples y que la tabla sea uniforme; como aquí cada usuario tiene sus datos de compañía y dirección metidos en otra cajita, la función prefiere mantenerlos anidados. Por eso toca aplanarlo a la fuerza para poder analizarlo plano.

---

## Ejercicio 3: Matriz de diseño

**Datos:** `titanic.csv` — variables `age`, `fare`, `sibsp`, `parch`; quitar los NA.

### 1. Matriz `X` centrada y escalada (`scale()`)

```r
library(dplyr)
datos_modelo <- titanic |>
  select(survived, pclass, age, fare, sibsp, parch) |>
  na.omit()

y <- datos_modelo$survived
X <- datos_modelo |> select(-survived) |> scale() |> as.matrix()
```

- **Dimensiones:** `1045 × 5` (quedaron 1045 filas limpiecitas sin NA, y 5 columnas que son los predictores: `pclass`, `age`, `fare`, `sibsp`, `parch`).
- **Memoria:** Ocupa como 41.6 Kb (es una matriz densa chiquita de números de doble precisión).

### 2. `X^T X` y significado de la diagonal con `X` escalada

```r
XtX <- crossprod(X) # Ojo, usando X escalada
round(diag(XtX))
```

Da algo como:
```
pclass    age   fare sibsp parch 
  1044   1044   1044  1044  1044 
```
- **Qué significa:** Como usamos `scale()`, cada columna quedó con media 0 y varianza 1. Cuando haces `X^T X` con datos estandarizados, lo que te da en la diagonal es exactamente `n - 1` (o sea, 1045 - 1 = 1044). Representa la suma de los cuadrados de cada variable ya estandarizada.

### 3. Matriz dispersa (`Matrix(X, sparse = TRUE)`)

```r
library(Matrix)
X_sparse <- Matrix(X, sparse = TRUE)
object.size(X)
object.size(X_sparse)
```

- **Resultado:** La matriz densa pesa sus 41.6 Kb, pero la versión `sparse` termina pesando **más** (como 100 Kb o más por el peso extra de guardar los índices).
- **¿Vale la pena usar sparse aquí?** **Ni por error.** El formato disperso solo sirve cuando hay un gentío de ceros (como en texto con matrices DTM). Aquí casi todas las celdas tienen números distintos de cero, así que guardar los índices de dónde están los ceros sale más caro que guardar la matriz normal. Eso se usa en NLP o sistemas de recomendaciones, aquí no pega.

### 4. ¿Qué estructura para relaciones familiares (`sibsp`, `parch`)?
- **Respuesta:** Un **grafo** (usando `igraph` en R o `networkx` en Python).
- **Por qué:** Es que `sibsp` (hermanos/esposos) y `parch` (padres/hijos) lo que te dicen en realidad es cómo se relacionan las personas entre sí, no son solo características aisladas de cada pasajero. Una tabla plana te borra la película: ahí no se ve quién iba con quién. Con un grafo pones a los pasajeros de nodos (`V`) y las familias como líneas o aristas (`E`), y ahí sí puedes sacar comunidades, ver quiénes viajaban juntos y armar análisis de redes que en una tabla normal jamás se verían.

---

## Ejercicio 4: Concentración de distancias

**Instrucción:** Probar con `p ∈ {1, 2, 5, 10, 50, 100, 500, 1000, 5000}` (`set.seed(42)`): 500 puntos al azar en `[0,1]^p`, mirar 200 distancias euclidianas. Sacar media y el coeficiente de variación (CV), graficar con `log` en `x`, ver en qué `p` el CV baja del 5% y repetir con coseno.

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

Tabla aproximada:

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
       title = "Concentración de distancias: CV vs dimensiones")
```

### 3. ¿A partir de qué `p` el CV cae por debajo del 5%?
- **Respuesta:** Más o menos entre `p = 100` (6.2%) y `p = 500` (2.57%). Es decir, el 5% se rompe por ahí en los **200 o 300 dimensiones**.
- **Qué significa para los algoritmos:** Cuando ese CV se pone tan bajito, resulta que todas las distancias entre puntos se vuelven casi idénticas. Ya no hay un vecino "cercano" y otro "lejano", todo queda a la misma distancia relativa. Por eso los algoritmos como K-NN, el clustering de K-Means o los kernels sufren tanto (es la famosa maldición de la dimensionalidad de Bellman).

### 4. Distancia coseno (repetir punto 1)

```r
# La idea es la misma pero usando la fórmula de la distancia coseno:
# 1 - (producto punto / producto de normas)
```

- **Observación:** Con coseno pasa algo parecido, las distancias también se concentran si los datos son uniformes y densos. Sin embargo, la distancia coseno aguanta un poquito mejor en datos que son dispersos (tipo texto) porque al no pararle bolas a los ceros compartidos evita parte de este problema.

---

## Ejercicio 5: PCA y reducción de dimensionalidad

**Datos:** Las variables numéricas del Titanic ya escaladas: `age`, `fare`, `sibsp`, `parch`, `pclass`.

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

Cifras que suelen salir con este dataset:
- **PC1:** Coge como el 45–55% de la varianza.
- **PC2:** Ya acumulado con la primera llega al 70-75%.
- **PC3:** Llega al 85% aprox.
- **PC4:** Toca el 95%.

- **Para pasar del 80%:** Se necesitan **3 componentes**.
- **Para pasar del 95%:** Se necesitan **los 4 componentes**.

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
  labs(x = "Componentes principales", y = "Varianza acumulada (%)",
       title = "Scree plot - Titanic numérico")
```

### 3. Loadings de PC1 y PC2 (qué significan)

```r
loadings <- pca$rotation[, 1:2]
print(loadings)
```

Interpretación típica en el contexto del barco:

| Variable | PC1 | PC2 | Qué pinta tiene |
|----------|-----|-----|-----------------|
| `fare`   | Alto positivo | Bajo | Mide plata / clase social (pagar harto pasaje). |
| `pclass` | Alto negativo | Bajo | Va al revés del precio (clase 3 es valor alto de pclass pero tarifa baja). |
| `age`    | Bajo | Alto | Carga más hacia la edad de la persona. |
| `sibsp`  | Bajo | Alto | Hermanos o pareja a bordo (núcleo familiar). |
| `parch`  | Bajo | Alto | Papás o hijos a bordo. |

- **PC1 — “Riqueza / Clase socioeconómica”:** Manda ahí el precio del tiquete (`fare`) y la clase (`pclass`). Separa a los ricos de los pobres del barco.
- **PC2 — “Tamaño de familia y edad”:** Agrupa a los que viajaban con familiares (`sibsp`, `parch`) y la edad.

### 4. Reto: K-Means (`k = 2`) con datos originales vs. con los 2 primeros PCs

```r
# K-Means con las variables originales escaladas
k_orig <- kmeans(scale(datos_num), centers = 2, nstart = 10)

# K-Means usando solo los dos primeros componentes principales
X_pc <- pca$x[, 1:2]
k_pc <- kmeans(X_pc, centers = 2, nstart = 10)

# Al cruzar esto con la variable 'survived' se nota la diferencia...
```

- **Qué pasa al final:** El K-Means hecho sobre los **dos primeros PCs** suele atinarle o alinearse mejor con la supervivencia (`survived`) que hacerlo con las 5 variables originales. ¿Por qué? Porque el PCA le quita el ruido, junta lo que está correlacionado (como tarifa y clase) y nos deja resumido lo importante (clase y familia), que justamente eran los factores clave de si la gente se salvaba o no en el Titanic.

---

## Resumen general (para tener presente)

1. El **tipo de dato** define cuánto sufre uno limpiándolo antes de meterle mano.
2. La **estructura en memoria** (si es tabla, matriz o grafo) te dice qué algoritmos aguanta el equipo.
3. Si hay **mucha dimensión**, hay que aplicar PCA o revisar las distancias antes de estrellarse con la maldición de la dimensionalidad.