url_chinook <- "https://raw.githubusercontent.com/lerocha/chinook-database/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite"
ruta_db     <- "chinook.db"

if (!file.exists(ruta_db)) {
  download.file(url_chinook, destfile = ruta_db, mode = "wb")
  cat("Base de datos descargada en:", ruta_db, "\n")
} else {
  cat("La base de datos ya existe:", ruta_db, "\n")
}

# Instalamos los paquetes necesarios
paquetes  <- c("DBI", "RSQLite", "dplyr", "knitr")
instalados <- rownames(installed.packages())
pendientes <- setdiff(paquetes, instalados)
if (length(pendientes) > 0) install.packages(pendientes)

library(DBI)
library(RSQLite)
library(dplyr)

# Abrimos la conexión
con <- dbConnect(RSQLite::SQLite(), "chinook.db")
cat("Conexión establecida.\n")

dbListTables(con)
