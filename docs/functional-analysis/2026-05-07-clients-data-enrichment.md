# Functional Analysis: Enriquecimiento de datos de Clientes con Google Sheets

- **Fecha:** 2026-05-07
- **Identificador:** clients-data-enrichment
- **Estado:** Ready for technical analysis

## 1) Resumen

Modificar la lógica de carga de la pantalla de Clientes para que combine dos
fuentes de datos:

1. **Contactos de Factura Directa** (fuente primaria, ya existente).
2. **Google Sheets** — pestaña `clientes` del spreadsheet `configuracion`
   ubicado en la carpeta `internal/` del Google Drive configurado (fuente de
   enriquecimiento).

El resultado es una lista unificada que muestre las columnas: **NIF/CIF, Nombre,
Activo, Categoría, Mostrar en nuevos pedidos, Orden en nuevos pedidos**.

## 2) Contexto y objetivo

### Qué se solicita

Actualmente la pantalla de Clientes carga contactos exclusivamente desde la API
de Factura Directa y muestra: Nombre, NIF/CIF, Teléfono y Ciudad. Se solicita:

- Mantener Factura Directa como fuente primaria de contactos.
- Leer datos adicionales desde el spreadsheet `configuracion` (pestaña
  `clientes`) en Google Drive (`internal/`).
- Cruzar ambas fuentes por un campo clave (UUID del contacto en Factura Directa
  ↔ columna UUID del sheet).
- Reemplazar las columnas de la tabla actual por: **NIF/CIF, Nombre, Activo,
  Categoría, Mostrar en nuevos pedidos, Orden en nuevos pedidos**.

### Qué problema resuelve

Los datos de Factura Directa no contienen información de gestión interna del
negocio (si el cliente está activo, su categoría, si debe mostrarse en nuevos
pedidos, ni su orden de prioridad). Esa información se mantiene en un
spreadsheet de Google Drive y actualmente se consulta manualmente.

### Resultado funcional esperado

La pantalla de Clientes muestra una tabla con datos enriquecidos procedentes de
ambas fuentes, eliminando la necesidad de consultar el sheet manualmente.

## 3) Alcance

### En alcance

- Lectura de la pestaña `clientes` del spreadsheet `configuracion` desde la
  carpeta `internal/` de Google Drive.
- Merge/cruce de datos de Factura Directa con los datos del sheet, usando el
  UUID como clave de relación.
- Modificación de las columnas visibles en la tabla de Clientes: NIF/CIF,
  Nombre, Activo, Categoría, Mostrar en nuevos pedidos, Orden en nuevos pedidos.
- Manejo de estados: loading, error (parcial y total), vacío.
- Mantenimiento del buscador existente adaptado a las nuevas columnas.

### Fuera de alcance

- Escritura o edición del spreadsheet de Google Drive desde la app.
- CRUD de clientes en Factura Directa.
- Creación automática del spreadsheet `configuracion` si no existe.
- Detalle/perfil de cliente individual.
- Modificación de la pestaña `categorias_clientes` ni la pestaña `productos` del
  mismo sheet.

## 4) Actores implicados

| Actor                 | Rol                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------ |
| Usuario de la app     | Consulta la lista de clientes con información enriquecida                            |
| API Factura Directa   | Proveedor de datos base de contactos (nombre, NIF/CIF, etc.)                         |
| Google Sheets (Drive) | Proveedor de datos de enriquecimiento (activo, categoría, mostrar en pedidos, orden) |

## 5) Requisitos funcionales

- **RF-01:** El sistema debe obtener la lista de contactos desde la API de
  Factura Directa (comportamiento existente).
- **RF-02:** El sistema debe localizar el spreadsheet `configuracion` en la
  carpeta `internal/` del Google Drive configurado.
- **RF-03:** El sistema debe leer los datos de la pestaña `clientes` del
  spreadsheet `configuracion`.
- **RF-04:** El sistema debe cruzar los contactos de Factura Directa con las
  filas del sheet usando el UUID como clave de relación (columna A/B del sheet =
  UUID del contacto en Factura Directa).
- **RF-05:** Para cada cliente resultante, se deben presentar los siguientes
  campos:
  - **NIF/CIF**: procedente de Factura Directa (`fiscalId`).
  - **Nombre**: procedente de Factura Directa (`title`).
  - **Activo**: procedente del sheet (columna D — "Sí" / "No").
  - **Categoría**: procedente del sheet (columna E — `Categoría cliente`, valor
    numérico). Se debe resolver a nombre legible consultando la pestaña
    `categorias_clientes` (ID → Nombre). Ej: 1 → "Decathlon", 2 → "Tiendas
    pequeñas".
  - **Mostrar en nuevos pedidos**: procedente del sheet (columna F — "Sí" /
    "No").
  - **Orden en nuevos pedidos**: procedente del sheet (columna G — valor
    numérico).
- **RF-09:** El sistema debe leer la pestaña `categorias_clientes` del mismo
  spreadsheet `configuracion` para resolver el ID de categoría a su nombre
  legible. Estructura: Fila 3 = cabeceras (ID, Nombre, Activo), Fila 4+ = datos.
- **RF-06:** Si un contacto de Factura Directa no tiene correspondencia en el
  sheet, sus campos de enriquecimiento deben mostrarse vacíos o con valores por
  defecto.
- **RF-07:** Si una fila del sheet no tiene correspondencia en Factura Directa,
  debe ignorarse (Factura Directa es la fuente autoritativa de la lista de
  clientes).
- **RF-08:** El buscador existente debe adaptarse para buscar por las columnas
  visibles relevantes (al menos Nombre y NIF/CIF).

## 6) Criterios de aceptación

- **CA-01:** Al abrir la pantalla de Clientes, se muestran las columnas:
  NIF/CIF, Nombre, Activo, Categoría, Mostrar en nuevos pedidos, Orden en nuevos
  pedidos.
- **CA-02:** Los datos de NIF/CIF y Nombre provienen de Factura Directa.
- **CA-03:** Los datos de Activo, Categoría, Mostrar en nuevos pedidos y Orden
  en nuevos pedidos provienen del spreadsheet `configuracion` (pestaña
  `clientes`).
- **CA-04:** El cruce se realiza por UUID: la columna UUID del sheet coincide
  con el `id` del contacto de Factura Directa.
- **CA-05:** Si el spreadsheet `configuracion` no existe o no es accesible, los
  clientes se muestran con los datos de Factura Directa y los campos de
  enriquecimiento aparecen vacíos, mostrando un aviso no bloqueante al usuario.
- **CA-06:** Si Factura Directa falla, se muestra el error existente (sin
  cambios en este flujo).
- **CA-07:** Si Google Drive no está configurado, los clientes se muestran solo
  con datos de Factura Directa y campos de enriquecimiento vacíos, mostrando un
  aviso no bloqueante.
- **CA-08:** El buscador filtra correctamente por Nombre y NIF/CIF.
- **CA-09:** Las columnas Teléfono y Ciudad ya no se muestran en la tabla.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario navega a la pantalla de Clientes.
2. El sistema muestra estado de carga (loading).
3. El sistema obtiene la configuración de Factura Directa y de Google Drive.
4. El sistema lanza en paralelo (o secuencialmente): a. Petición a Factura
   Directa para obtener contactos. b. Lectura del spreadsheet `configuracion` →
   pestaña `clientes` desde la carpeta `internal/` de Google Drive.
5. Ambas respuestas se reciben correctamente.
6. El sistema cruza los datos por UUID, enriqueciendo cada contacto con los
   datos del sheet.
7. La tabla se muestra con las 6 columnas definidas, ordenada alfabéticamente
   por `title`.

### Flujos alternativos

- **FA-01 — Google Drive no configurado:** Se omite la lectura del sheet. Se
  muestran los clientes solo con NIF/CIF y Nombre (Activo, Categoría, etc.
  vacíos). Se muestra un aviso informativo.
- **FA-02 — Spreadsheet `configuracion` no encontrado en `internal/`:** Igual
  que FA-01, aviso al usuario indicando que el spreadsheet no fue encontrado.
- **FA-03 — Pestaña `clientes` no encontrada en el spreadsheet:** Igual que
  FA-01, aviso al usuario.
- **FA-04 — Error de red al leer Google Sheets:** Los clientes se muestran con
  datos parciales (solo Factura Directa) y un aviso de error parcial.
- **FA-05 — Error de red al leer Factura Directa:** Se muestra el error completo
  existente (bloqueante, la lista no puede cargarse sin la fuente primaria).

### Estados especiales / excepciones

- **Estado vacío:** No hay contactos en Factura Directa → mensaje "No hay
  clientes" (comportamiento existente).
- **Estado loading/procesando:** Indicador de progreso mientras se cargan ambas
  fuentes.
- **Estado error parcial:** Factura Directa OK pero Google Sheets falla → datos
  parciales + aviso.
- **Estado error total:** Factura Directa falla → error bloqueante con opción de
  reintentar.
- **Sin permisos Google Drive:** El sistema no puede acceder al spreadsheet →
  flujo FA-01.

## 8) Edge cases

- **EC-01:** El sheet tiene filas con UUID vacío → se ignoran esas filas.
- **EC-02:** El sheet tiene UUIDs duplicados → se toma la primera ocurrencia.
- **EC-03:** Un contacto de Factura Directa aparece múltiples veces en el sheet
  → se toma la primera coincidencia.
- **EC-04:** El spreadsheet `configuracion` existe pero está vacío (sin datos en
  pestaña `clientes`) → se muestran clientes sin enriquecimiento, sin error.
- **EC-05:** Valores inesperados en columnas del sheet (ej. texto en "Orden en
  nuevos pedidos") → se muestran como vacíos o se ignoran.
- **EC-06:** El campo "Activo" tiene un valor diferente de "Sí"/"No" → se trata
  como vacío.
- **EC-08:** El ID de categoría del cliente no existe en la pestaña
  `categorias_clientes` → se muestra vacío.
- **EC-09:** La pestaña `categorias_clientes` no existe o está vacía → la
  columna Categoría se muestra vacía para todos los clientes (sin error
  bloqueante).
- **EC-07:** La pestaña `clientes` tiene columnas en orden diferente al esperado
  → el sistema debe basarse en la fila de cabecera (fila 3 según la captura)
  para identificar columnas por nombre, no por posición fija.

## 9) Impacto funcional

- **Módulos afectados:**
  - Feature `clients` — Entidad, repositorio, DTO, use case, cubit, page.
  - Dependencia nueva del datasource de Google Drive / Sheets API.
  - Posible dependencia de la configuración de Google Drive desde `settings`.

- **Impacto en usuario:**
  - Información más completa y relevante en la lista de clientes.
  - Se eliminan las columnas Teléfono y Ciudad.
  - La funcionalidad es degradable: si Google Drive falla, el usuario sigue
    viendo los datos de Factura Directa.

- **Impacto en experiencia de usuario:**
  - Tiempo de carga puede aumentar ligeramente por la lectura adicional del
    sheet.
  - Nuevas columnas aportan información de gestión que antes requería consulta
    manual.

## 10) Suposiciones

- **S-01:** El UUID en la columna B del sheet (`con_4ba57cf7-...`) corresponde
  al UUID del contacto en Factura Directa (campo `uuid` en el JSON de la API).
- **S-02:** La estructura del sheet sigue el patrón observado en la captura:
  Fila 2 = título "CLIENTES", Fila 3 = cabeceras (UUID, Nombre, [vacía], Activo,
  Categoría cliente, Mostrar en nuevos pedidos, Orden en nuevos pedidos), Fila
  4+ = datos.
- **S-03:** El spreadsheet `configuracion` es de tipo Google Sheets nativo (no
  Excel importado) y se puede leer con la Sheets API.
- **S-04:** La columna "Nombre" del sheet (columna C) puede ignorarse para la
  visualización, ya que el Nombre mostrado proviene de Factura Directa.
- **S-05:** La columna "Categoría cliente" contiene un valor numérico
  (referencia a la pestaña `categorias_clientes`). Se resuelve a nombre legible
  usando la pestaña `categorias_clientes` del mismo spreadsheet.
- **S-06:** La carpeta `internal/` ya es detectada y su ID almacenado durante la
  configuración de Google Drive (`internoFolderId` en `GoogleDriveConfig`).

## 11) Preguntas abiertas

Todas resueltas.

- ~~**PA-01:**~~ **Resuelto:** Sí, resolver categoría a nombre legible usando la
  pestaña `categorias_clientes` (ID → Nombre). Ej: 1 = "Decathlon", 2 = "Tiendas
  pequeñas".
- ~~**PA-02:**~~ **Resuelto:** Usar `title` del contacto de Factura Directa como
  Nombre.
- ~~**PA-03:**~~ **Resuelto:** Ordenación siempre alfabética por `title`. Sin
  cambio.

## 12) Notas para análisis técnico

- La entidad `Client` actual tiene campos: `id`, `name`, `title`, `email`,
  `phone`, `fiscalId`, `country`, `city`. Será necesario añadir: `isActive`,
  `clientCategory`, `showInNewOrders`, `orderInNewOrders`.
- La app ya tiene integración con Google Sheets API (scope
  `SheetsApi.spreadsheetsScope` solicitado en login). Se necesita un datasource
  para leer valores de celdas del sheet.
- El `internoFolderId` ya se persiste en `GoogleDriveConfig`. Falta lógica para
  localizar el spreadsheet `configuracion` dentro de esa carpeta y leer la
  pestaña `clientes`.
- El repositorio actual (`ClientsRepositoryImpl`) solo depende de
  `FacturaDirectaApiDataSource` y `SettingsRepository`. Necesitará una
  dependencia adicional para leer el sheet de Google Drive.
- Las llamadas a Factura Directa y Google Sheets pueden realizarse en paralelo
  para optimizar el tiempo de carga.
- Considerar un modelo de error parcial en el estado del cubit: datos cargados
  correctamente desde Factura Directa pero con advertencia de Google Sheets no
  disponible.
- La búsqueda actual filtra por `title` y `phone`. Debe adaptarse a las nuevas
  columnas (`title` y `fiscalId` como mínimo).
- Se necesita leer también la pestaña `categorias_clientes` para construir un
  mapa ID→Nombre de categorías.
- **Estado: Listo para análisis técnico**
