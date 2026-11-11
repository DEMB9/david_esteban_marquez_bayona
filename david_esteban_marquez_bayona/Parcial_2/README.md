# Taller 2 · Comparador de precios de cuidado bucal (aplicación Shiny)

Minería de Datos (2016325) · Universidad Nacional de Colombia · **David Esteban Márquez Bayona**

- **Aplicación publicada:** `PENDIENTE — pegar aquí el enlace de shinyapps.io o Posit Connect Cloud`
- **Categoría:** cuidado bucal. **Comercios:** Éxito, Olímpica y Locatel (los mismos del Taller 1).
- **Lenguaje:** R ≥ 4.2 para todo el proceso (scraping, acceso a datos, aplicación y pruebas).

> **Cambio de lenguaje.** El Taller 1 se entregó en Python. Como la aplicación es Shiny, el enunciado
> exige reescribir la extracción en R: `scraper.R` y `limpieza.R` son la versión en R de `scraper.py` y
> `limpieza.py`, con el mismo método, las mismas reglas y el mismo formato de `raw/`. La equivalencia se
> comprobó reconstruyendo la base desde las copias crudas con el código en R: las 19.067 observaciones,
> los 2.384 anuncios y los 1.990 productos resultaron idénticos a los de la base entregada en el Taller 1.

## 1. Ejecutar la aplicación localmente

```r
# desde la carpeta taller_2/, en una sesión de R recién iniciada
source("configurar.R")        # una sola vez: instala las versiones fijadas en renv.lock y las verifica
# reiniciar R (Ctrl + Shift + F10)
shiny::runApp()               # abre la aplicación
```

La carpeta ya incluye la base (`comparador_precios.sqlite`) y las copias crudas (`raw/`). Si se parte de
la entrega del Taller 1, `Rscript migrar_taller1.R ../Parcial_1/taller1_cuidado_bucal` copia la base y
`raw/` y les agrega la estructura del Taller 2 (no modifica ninguna observación).

Nueva recolección desde la consola (equivale al botón de la aplicación):

```bash
Rscript scraper.R                  # en línea: consulta los tres comercios y agrega una ejecución
Rscript scraper.R --sin-conexion   # reprocesa raw/ sin consultar ningún sitio (no duplica nada)
```

## 2. Pruebas

```bash
Rscript -e 'testthat::test_dir("tests")'
```

Son 16 pruebas (84 comprobaciones) que usan una base temporal y copias crudas de juguete; no tocan la base
de la entrega ni consultan los sitios. Cubren: conversión de precios en texto a número, normalización de
unidades, dígito de control del EAN, reglas de validación, inserción repetida sin duplicados, detección de
cambios de precio / productos nuevos / no observados, tolerancia a la falla de un comercio, ahorro con
empates, canasta completa y canasta con un producto faltante, y filtros con texto malicioso.

## 3. Estructura de archivos

| Archivo | Contenido |
|---|---|
| `app.R` | Interfaz (`bslib`) y servidor. No contiene SQL ni scraping. |
| `db.R` | Capa de acceso a datos: todas las consultas SQL, con los filtros como argumentos. |
| `scraper.R` | Extracción (una función por comercio), copias crudas, inserción por transacción y `ejecutar_recoleccion()`. |
| `validacion.R` | Reglas de validación con `pointblank`, comparables de referencia y correcciones manuales. |
| `limpieza.R` | Reglas R1–R9 de normalización y correspondencia de productos; correcciones C1 y C2. |
| `graficos.R` | Tema visual (colores, tipografía), formato (COP, %) y los cuatro gráficos de `highcharter`. |
| `www/logos/` | Logos de los comercios. Pertenecen a sus dueños y se usan solo para identificar cada comercio en este trabajo académico. |
| `esquema.sql`, `vistas.sql` | Estructura de la base (tablas e índices) y vistas SQL. |
| `migrar_taller1.R` | Adapta la base del Taller 1 a la estructura del Taller 2. |
| `comparador_precios.sqlite` | Base de datos (Taller 1 + ejecuciones nuevas). |
| `diccionario_datos.md` | Tablas, vistas y columnas: significado, tipo, unidad y valores posibles. |
| `raw/<comercio>/<fecha>/<ejecución>/` | Respuestas JSON originales (gzip) y `manifest.json` de cada ejecución. |
| `tests/` | Pruebas automáticas (`testthat`). |
| `renv.lock` | Dependencias con versiones fijas. |

## 4. Datos

**Origen.** Todos los precios provienen del scraper. Cada observación guarda su ejecución
(`ejecucion_id`), su fecha y hora, la URL consultada (`url_fuente`) y la carpeta de su copia cruda
(`ejecuciones.carpeta_raw`). La columna «Coinciden con la base» del resumen del modo sin conexión cuenta
cuántas filas leídas de `raw/` coinciden en SKU, precio y disponibilidad con lo guardado.

**Historial.** `PENDIENTE — la base del Taller 1 tiene 8 ejecuciones completas, todas del 2026-10-09. Falta
agregar al menos una ejecución en otra fecha con «Actualizar precios» (o `Rscript scraper.R`) y describirla aquí.`

**Correcciones a la base del Taller 1** (tabla `correcciones`; no se borró ni se modificó ninguna observación):

| Regla | Qué corrige | Registros |
|---|---|---|
| C1 | Contenido homologado por EAN: anuncios del mismo código de barras que declaraban contenidos distintos (por ejemplo, Locatel tomaba el peso de la ficha técnica de un cepillo, «47 g», en vez de «2 unidades»; Éxito publica 75 mL donde los otros dos publican 100 g). Se usa el contenido de la mayoría estricta; si no hay mayoría la presentación queda **sin precio unitario**. | 53 anuncios |
| C2 | Subcategoría homologada por EAN con la misma regla (por ejemplo, nombres abreviados de Olímpica que quedaban en «Otros cuidado bucal»). | 10 anuncios |

Con esto, 78 de las 84 presentaciones comparables tienen contenido verificado y, por tanto, precio unitario comparable; antes de las correcciones eran menos de la mitad.
`PENDIENTE — agregar las correcciones que pida la retroalimentación del Taller 1 con registrar_correccion()
o descartar_observacion() (validacion.R) y describirlas aquí.`

**Validación** (`validacion.R`): precio numérico (V1) y mayor que cero (V2); producto disponible con precio
(V3); comercio, URL, SKU y fecha presentes (V4); fecha en ISO 8601 (V5); sin duplicados en la ejecución (V6);
los ocho comparables de referencia presentes en cada comercio (V7, deja la ejecución como «parcial»). Las
filas que fallan no se insertan y quedan en `observaciones_rechazadas` con su motivo. Un producto **agotado**
puede no tener precio publicado: ese precio queda `NULL`, no se reemplaza.

**Disponibilidad.** `observaciones.disponibilidad` distingue `disponible` y `agotado` (lo dice el sitio);
«no observado» se deriva en `v_disponibilidad` y `v_ultimo_precio` cuando el anuncio no apareció en la
ejecución, y no se interpreta como agotado ni como retirado.

**Los ocho productos comparables de referencia** (tabla `comparables_referencia`): presentaciones emparejadas
por EAN, sin alertas ni correcciones, con contenido verificado y precio en los tres comercios en todas las
ejecuciones completas. La aplicación trabaja además con las 84 presentaciones comparables del Taller 1.

### Vistas SQL que usa la aplicación

| Vista | Descripción |
|---|---|
| `v_catalogo` | Una fila por observación vigente, con campos estandarizados, presentación y precio por unidad de contenido. |
| `v_ultimo_precio` | Observación más reciente de cada anuncio y su estado actual (disponible, agotado, no observado). |
| `v_cambios_precio` | Observaciones cuyo precio cambió frente a la observación anterior del mismo anuncio (COP y %). |
| `v_comparables` | Un precio por presentación comparable, comercio y ejecución; precio unitario solo con contenido verificado. |
| `v_disponibilidad` | Estado de cada anuncio en cada ejecución de su comercio. |
| `v_observaciones` | Vista del Taller 1 (se conserva). |

## 5. La aplicación

- **Filtros** (panel lateral, combinables): comercio, subcategoría, marca, rango de precio, ejecución o rango
  de fechas, solo promociones, solo comparables y búsqueda por palabras en el nombre o el texto del anuncio.
- **Resumen:** siete indicadores calculados con SQL (productos y observaciones, última ejecución y su estado,
  % en promoción, precio mediano, ahorro máximo entre comercios, cambios de precio y % de agotados), cada uno
  con su unidad y la ejecución o periodo; distribución de precios por comercio; conteos por comercio y precio
  mediano por subcategoría.
- **Comercios:** una ficha por comercio con su logo (cuántas veces es el más barato, anuncios, marcas, precio
  mediano, % en promoción y % agotado); un gráfico de **waffle** (de cada 100 productos comparables, en cuántos es
  más barato cada comercio), **columnas porcentuales** con la composición del catálogo por subcategoría y un
  **packed bubble** con las marcas que más anuncios tienen en cada comercio, y un **sunburst** que recorre el catálogo
  del comercio a la subcategoría y a la marca (clic en un sector para acercarse).
- **Productos:** tabla ordenable y con búsqueda; descarga de los datos filtrados en CSV.
- **Comparar precios:** evolución del precio de un comparable, precio por unidad de contenido (una sola
  unidad de medida a la vez) y ahorro por producto.
- **Cambios de precio:** dos ejecuciones a elección (por defecto las dos más recientes), umbral ajustable,
  productos nuevos y productos que dejaron de observarse.
- **Canasta:** productos comparables y cantidades; costo por comercio solo si tiene todos los productos, costo
  mínimo combinando comercios y ahorro frente al mejor comercio único.
- **Actualizar datos:** botón que ejecuta el scraper en segundo plano (`ExtendedTask`), modo sin conexión,
  resumen por comercio y tablas de ejecuciones, disponibilidad, correcciones y observaciones rechazadas.

**Gráfico de libre elección — «¿En qué productos vale más la pena comparar antes de comprar?»** Muestra, para
cada presentación comparable, cuánto se ahorra comprándola en el comercio más barato en vez del más caro (COP
y %), y con el color indica cuál es ese comercio. Responde una pregunta práctica del consumidor: en la mayoría
de productos la diferencia es pequeña, pero en unos pocos es grande, y esos son los que justifican cambiar de
tienda. Es distinto de la canasta porque no exige elegir productos: ordena todo el catálogo comparable.

**Caché y conexión.** Las consultas repetidas se guardan con `bindCache()`; la clave incluye un contador que
aumenta al terminar una actualización, así que la caché se invalida sin reiniciar. La aplicación abre una
sola conexión de lectura (`PRAGMA query_only`) y la cierra con `onStop()`; el scraper abre y cierra la suya.

## 6. Seguridad

- No se usan tokens ni claves. El despliegue se configura con `rsconnect::setAccountInfo()` **en la consola**,
  nunca en un archivo del proyecto; `.Renviron` y `rsconnect/` están en `.gitignore`.
- Los valores del usuario van como parámetros (`?`) o se interpolan con `glue::glue_sql()`; ninguna consulta
  se arma concatenando texto. La búsqueda se valida antes (máximo 60 caracteres; letras, números, espacios y
  `. , % + -`), y `%` y `_` se buscan como texto.
- Scraping: pausa de 1 s entre peticiones, reintentos con espera exponencial, agente de usuario identificable
  (`TallerMineriaDatosUNAL/2.0`), máximo 80 peticiones por comercio y copia de `robots.txt` en cada ejecución.

## 7. Hallazgos para el consumidor

Basados en las 8 ejecuciones del **9 de octubre de 2026** (10:41 a 14:42); las cifras son de la ejecución
`E20261009T144022` y se pueden verificar en la aplicación eligiéndola en «Ejecución».
`PENDIENTE — actualizar con la ejecución nueva de este taller.`

1. **Éxito es el más barato en la mayoría de productos, pero no en todos.** De las 84 presentaciones
   comparables, Éxito tiene el menor precio en 53, Olímpica en 22 y Locatel en 13 (los empates cuentan para
   cada comercio). Se ve en «Comparar precios» (colores del gráfico de ahorro).
2. **La mejor tienda depende de la canasta.** Con los ocho productos de referencia, una unidad de cada uno, la
   canasta cuesta $ 150.625 en Olímpica, $ 151.605 en Éxito y $ 167.775 en Locatel; comprando cada producto
   donde es más barato cuesta $ 140.485: $ 10.140 menos (6,7 %) que en el mejor comercio único. Se ve en «Canasta».
3. **El tamaño grande rinde más.** Listerine Cool Mint cuesta en Éxito $ 59,1 por mL en 180 mL, $ 39,9 en
   500 mL y $ 32,2 en 1.000 mL; el orden se repite en Olímpica y Locatel. Se ve en «Precio por unidad de contenido».
4. **El catálogo más grande no es el más disponible.** Éxito publica 1.733 anuncios, pero el 63,8 % figura
   agotado y sin precio; en Locatel es el 8,2 % y en Olímpica ninguno. De los anuncios con precio, está en
   promoción el 72,6 % en Éxito, el 15,6 % en Locatel y el 6,6 % en Olímpica. Se ve en «Resumen» filtrando por comercio.

Límites: los precios son los del momento de la captura; la canasta no incluye envío, mínimos de compra ni
condiciones de las promociones; 6 de las 84 presentaciones comparables no tienen precio unitario porque los
comercios declaran contenidos distintos y no hay mayoría.

## 8. Despliegue

```r
# En la consola de R (no guardar en ningún archivo):
# rsconnect::setAccountInfo(name = "...", token = "...", secret = "...")
rsconnect::deployApp(appDir = ".", appName = "comparador-cuidado-bucal")
```

- Las plataformas gratuitas no conservan los cambios de la base al reiniciarse: una actualización hecha en la
  versión publicada dura hasta que el servidor se reinicia. La actualización en línea funciona en la ejecución local.
- Si el servidor no puede consultar los comercios (suelen bloquear estas plataformas), la aplicación lo informa,
  no cambia la base y ofrece el **modo sin conexión**, que reprocesa las copias de `raw/`.
- La versión publicada debe desplegarse desde el mismo commit que se entrega.

## 9. Declaración de uso de inteligencia artificial

- **Herramienta:** Claude (Anthropic), en una sesión con ejecución de código.
- **Para qué se usó:** traducción a R del scraper y de las reglas de limpieza del Taller 1; diseño de las tablas
  y vistas nuevas; escritura de `db.R`, `validacion.R`, `graficos.R`, `app.R`, las pruebas, el diccionario de
  datos y un borrador de este README (incluidos los hallazgos, calculados con consultas sobre la base).
- **Cómo se verificó el resultado:** (1) la base reconstruida desde `raw/` con el código en R se comparó tabla
  por tabla con la del Taller 1 y resultó idéntica; (2) tras la migración, las observaciones siguen siendo las
  mismas 19.067 del Taller 1; (3) las pruebas automáticas pasan; (4) la descarga en línea se probó contra un
  servidor local que imita la API de los comercios, porque el entorno del asistente no tenía acceso a los
  sitios; (5) la aplicación se recorrió pestaña por pestaña, incluida una actualización sin conexión.
- `PENDIENTE — describir la revisión propia: ejecución en línea real contra los tres comercios, revisión del
  código, despliegue y comprobación de los hallazgos en la aplicación.`
