# Implementation Report: Selector de origen de Pedidos de hoy

- **Fecha:** 2026-05-09
- **Identificador:** orders-today-source-selector
- **Plan técnico:**
  docs/technical-analysis/2026-05-09-orders-today-source-selector.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado un diálogo de selección de origen que aparece al pulsar
"Pedidos de hoy" en el menú lateral. El usuario puede elegir entre abrir los
pedidos desde la aplicación (flujo Firestore existente) o seleccionar una hoja
de cálculo de Google Drive. El flujo existente permanece inalterado al elegir la
primera opción. El selector de spreadsheets reutiliza la infraestructura
existente de Google Drive.

## 2) Alcance ejecutado

- ✅ Diálogo de selección de origen con dos opciones (aplicación / hoja de
  cálculo)
- ✅ Interceptación del índice 1 en `SideMenuShell.onItemSelected`
- ✅ Integración correcta con `NavigationGuard` (cambios no guardados se
  resuelven antes del diálogo de origen)
- ✅ Selector de spreadsheets (`SpreadsheetPickerDialog`) con estados
  loading/loaded/empty/error
- ✅ Detección de Google Drive no configurado con mensaje informativo
- ✅ Confirmación visual (SnackBar) al seleccionar una hoja de cálculo
- ✅ Internacionalización completa (11 nuevas claves i18n)
- ✅ Reutilización de `GoogleDriveRemoteDataSource.listSpreadsheets()` y
  `SettingsLocalDataSource`

## 3) Artefactos tocados

### Creados

- `lib/features/home/presentation/widgets/spreadsheet_picker_dialog.dart` —
  Widget `StatefulWidget` que lista spreadsheets de una carpeta de Google Drive,
  gestiona estados loading/loaded/empty/error y permite seleccionar uno.

### Modificados

- `lib/features/home/presentation/pages/side_menu_shell.dart` — Interceptación
  del índice 1 en `onItemSelected`, nuevo método `_showOrdersSourceDialog()`,
  nuevo método `_handleSpreadsheetOption()`, ajuste del `_showUnsavedDialog()`
  para respetar la interceptación del índice 1 tras descartar cambios.
- `lib/app/localization/l10n/app_es.arb` — 11 nuevas claves i18n para el diálogo
  de selección de origen y el selector de spreadsheets.
- `lib/app/localization/l10n/app_localizations.dart` — Regenerado por
  `flutter gen-l10n`.
- `lib/app/localization/l10n/app_localizations_es.dart` — Regenerado por
  `flutter gen-l10n`.

### Retirados o reemplazados

- Ninguno.

## 4) Validación ejecutada

| Validación                          | Resultado              |
| ----------------------------------- | ---------------------- |
| `flutter gen-l10n`                  | ✅ Correcto            |
| `dart analyze` (archivos afectados) | ✅ 0 issues            |
| `flutter test`                      | ✅ 58 passed, 0 failed |

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** Se usa `l10n.settingsCancel` en lugar de crear una nueva
  clave `commonCancel` para el botón Cancelar del diálogo.
  - **Justificación:** Ya existía la clave `settingsCancel` con el texto
    "Cancelar". Crear una duplicada no aportaría valor.
  - **Impacto:** Ninguno funcional.

- **Desviación 2:** Se ajustó `_showUnsavedDialog` para que, cuando el
  `targetIndex` es 1, muestre el diálogo de selección de origen tras descartar
  cambios en lugar de navegar directamente.
  - **Justificación:** Sin este ajuste, el flujo `NavigationGuard` → descartar →
    navegar al índice 1 saltaría el diálogo de selección de origen, lo cual
    contradiría el RF-01.
  - **Impacto:** Ninguno; corrige un caso edge implícito en el plan.

## 6) Riesgos, incidencias y pendientes

- **Pendiente:** En esta iteración, tras seleccionar una hoja de cálculo, solo
  se muestra un `SnackBar` de confirmación. El procesamiento posterior
  (validación de plantilla, visualización de datos) queda para la siguiente
  iteración según lo definido en el análisis funcional.
- **Pendiente:** No se han creado tests unitarios ni widget tests para los
  nuevos widgets. La lógica es de presentación pura y se validó con análisis
  estático y tests existentes.
- **Riesgo:** El diálogo añade un paso extra antes de acceder a "Pedidos de
  hoy". Si el usuario siempre elige la misma opción, podría resultar redundante.
  Se puede mitigar en iteraciones futuras con una preferencia "recordar
  elección".

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual end-to-end con cuenta Google
  Drive real + definición de la siguiente iteración (validación de estructura de
  la hoja seleccionada)
