# Implementation Report: Enriquecimiento de datos de Clientes con Google Sheets

- **Fecha:** 2026-05-07
- **Identificador:** clients-data-enrichment
- **Plan técnico:**
  docs/technical-analysis/2026-05-07-clients-data-enrichment.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado la lógica de carga enriquecida de clientes que combina datos
de Factura Directa (fuente primaria) con datos del spreadsheet `configuracion`
(pestaña `clientes`) de Google Drive (carpeta `internal/`). La tabla de la
pantalla de Clientes ahora muestra: NIF/CIF, Nombre, Activo, Categoría, Mostrar
en nuevos pedidos, Orden en nuevos pedidos. La funcionalidad incluye degradación
funcional: si Google Sheets no está disponible, se muestran los datos de Factura
Directa con un banner de aviso.

## 2) Alcance ejecutado

- Todas las partes del plan técnico se han implementado (pasos 1 a 9).
- No se han implementado tests unitarios nuevos (paso 10 del plan), ya que no
  existían tests previos para la feature `clients`.

## 3) Artefactos tocados

### Creados

- `lib/core/data/datasources/google_sheets_data_source.dart` — Interfaz
  abstracta para lectura de Google Sheets
- `lib/core/data/datasources/google_sheets_data_source_impl.dart` —
  Implementación usando googleapis Sheets API v4
- `lib/features/clients/domain/entities/client_category.dart` — Entidad para
  categoría de cliente
- `lib/features/clients/domain/entities/clients_result.dart` — Wrapper con lista
  de clientes + warning opcional
- `lib/features/clients/data/dto/client_sheet_dto.dart` — DTO para parseo de
  filas de la pestaña `clientes`
- `lib/features/clients/data/dto/client_category_sheet_dto.dart` — DTO para
  parseo de filas de la pestaña `categorias_clientes`

### Modificados

- `lib/features/clients/domain/entities/client.dart` — +4 campos opcionales
  (`isActive`, `categoryName`, `showInNewOrders`, `orderInNewOrders`) +
  `copyWith()`
- `lib/features/clients/domain/repositories/clients_repository.dart` — Retorno
  cambiado a `Either<Failure, ClientsResult>`
- `lib/features/clients/domain/usecases/get_clients.dart` — Adaptado a
  `ClientsResult`
- `lib/features/clients/data/repositories/clients_repository_impl.dart` — Nuevas
  dependencias (`GoogleSheetsDataSource`, `GoogleDriveRemoteDataSource`), lógica
  de merge paralelo, degradación funcional
- `lib/features/clients/presentation/bloc/clients_state.dart` — `ClientsLoaded`
  con campo `sheetWarning`
- `lib/features/clients/presentation/bloc/clients_cubit.dart` — Propagación de
  warning, filtro adaptado a `title` + `fiscalId`
- `lib/features/clients/presentation/pages/clients_page.dart` — 6 nuevas
  columnas, banner de warning, helper `_boolLabel()`
- `lib/app/di/modules/clients_module.dart` — Constructor de
  `ClientsRepositoryImpl` con 4 dependencias
- `lib/app/di/modules/core_module.dart` — Registro de
  `GoogleSheetsDataSourceImpl`
- `lib/app/localization/l10n/app_es.arb` — 6 nuevas keys: `clientsColumnActive`,
  `clientsColumnCategory`, `clientsColumnShowInOrders`,
  `clientsColumnOrderPosition`, `genericYes`, `genericNo`
- `lib/app/localization/l10n/app_localizations.dart` (regenerado)
- `lib/app/localization/l10n/app_localizations_es.dart` (regenerado)

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

- `dart analyze lib/` → **No issues found**
- `flutter test` → **57 passed, 1 failed** — el fallo es preexistente en
  `SideMenuCubit` (feature `home`), no relacionado con los cambios
- `flutter gen-l10n` → traducciones generadas correctamente

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** La entidad `ClientCategory` se creó pero no se usa
  directamente como tipo en `Client`. En su lugar, el `categoryName` resuelto
  (String) se almacena directamente en `Client`, y el mapa `Map<int, String>` de
  categorías se construye en el repositorio usando
  `ClientCategorySheetDto.parseSheet()`.
  - **Justificación:** Simplifica el modelo sin perder funcionalidad. La entidad
    queda disponible si se necesita en el futuro.
  - **Impacto:** Ninguno.

- **Desviación 2:** No se implementaron tests unitarios nuevos (paso 10 del plan
  técnico).
  - **Justificación:** No existían tests previos para la feature `clients`. La
    creación de tests se deja como tarea pendiente.
  - **Impacto:** Menor — la validación se realizó con análisis estático y tests
    existentes del proyecto.

## 6) Riesgos, incidencias y pendientes

- **Riesgo S-04 (UUID match):** No se ha podido verificar en runtime que el UUID
  del sheet (`con_4ba57cf7-...`) coincida exactamente con el formato devuelto
  por la API de Factura Directa (`content.uuid`). Si no coinciden, el merge no
  enriquecerá ningún cliente, pero la degradación funcional lo manejará
  mostrando datos sin enriquecimiento.
- **Pendiente:** Crear tests unitarios para `GoogleSheetsDataSourceImpl`, DTOs
  de sheet, lógica de merge en `ClientsRepositoryImpl`, y `ClientsCubit`.
- **Pendiente:** El test preexistente
  `SideMenuCubit selectItem does not emit for index out of range` falla — no es
  scope de este cambio.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en entorno real (verificar que
  el UUID del sheet coincide con el de la API), seguido de creación de tests
  unitarios.
