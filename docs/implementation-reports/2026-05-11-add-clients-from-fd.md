# Implementation Report: Añadir clientes desde Factura Directa con selección

- **Fecha:** 2026-05-11
- **Identificador:** add-clients-from-fd
- **Plan técnico:** docs/technical-analysis/2026-05-11-add-clients-from-fd.md
- **Estado:** Completed

## 1) Resumen

Se reemplazó el botón "Sincronizar desde Factura Directa" por "Añadir desde
Factura Directa" con un flujo interactivo: descarga de contactos FD → filtrado
de nuevos → dialog de selección múltiple → persistencia de los seleccionados en
Firestore. El flujo de sync completo se mantiene intacto en Settings.

## 2) Alcance ejecutado

- Todas las partes del plan técnico se implementaron completamente (pasos 1-8).
- El paso 9 (tests) no se ejecutó — se recomienda como siguiente paso.

## 3) Artefactos tocados

### Creados

- `lib/features/clients/domain/entities/fd_new_contact.dart` — Entidad de
  dominio para contacto FD candidato a importar
- `lib/features/clients/domain/usecases/fetch_new_fd_contacts.dart` — Use case:
  descarga contactos FD, filtra por UUID vs existentes en Firestore
- `lib/features/clients/domain/usecases/add_selected_fd_contacts.dart` — Use
  case: mapea FdNewContact → ClientModel y ejecuta batchAdd
- `lib/features/clients/presentation/widgets/select_fd_contacts_dialog.dart` —
  Dialog de selección múltiple con select-all, contador y botón de confirmación

### Modificados

- `lib/features/clients/presentation/bloc/clients_cubit.dart` — Reemplazada
  dependencia `SyncClientsFromFd` por `FetchNewFdContacts` +
  `AddSelectedFdContacts`. Nuevos métodos `fetchNewContacts()` y
  `addSelectedContacts()`. Eliminado `syncClients()`.
- `lib/features/clients/presentation/pages/clients_page.dart` — Reemplazado
  `_syncFromFd()` por `_addFromFd()`. Nuevo método `_showFeedback()`. Cambio de
  icono/texto del botón. Integración del dialog de selección.
- `lib/app/di/modules/clients_module.dart` — Registrados `FetchNewFdContacts` y
  `AddSelectedFdContacts`. Actualizado factory de `ClientsCubit` (7 parámetros).
- `lib/app/localization/l10n/app_es.arb` — Añadidas 13 claves i18n nuevas para
  el flujo de añadir clientes (mantenidas las claves de sync para Settings).
- `lib/app/localization/l10n/app_localizations.dart` — Regenerado
  automáticamente.
- `lib/app/localization/l10n/app_localizations_es.dart` — Regenerado
  automáticamente.

### Retirados o reemplazados

- Ningún archivo eliminado. `SyncClientsFromFd` se mantiene para uso en
  `FacturaDirectaCubit` (Settings).

## 4) Validación ejecutada

- **Análisis estático (`dart analyze`):** 0 issues en todos los archivos de
  `lib/features/clients/` y `clients_module.dart`.
- **Errores del IDE:** 0 errores en los 7 archivos principales.
- **Verificación de no-breaking en Settings:** Confirmado que
  `FacturaDirectaCubit` sigue usando `SyncClientsFromFd` correctamente sin
  cambios.
- **Regeneración i18n:** `flutter gen-l10n` ejecutado sin errores.

## 5) Desviaciones respecto al análisis técnico

- El análisis técnico proponía eliminar `SyncClientsFromFd` del constructor de
  `ClientsCubit` y añadir los dos nuevos use cases (pasando de 6 a 7
  parámetros). Implementado exactamente así: se eliminó `_syncClientsFromFd` y
  se añadieron `_fetchNewFdContacts` + `_addSelectedFdContacts`.
- No hay desviaciones materiales.

## 6) Riesgos, incidencias y pendientes

- **Tests unitarios pendientes:** No existen tests para `ClientsCubit`,
  `FetchNewFdContacts`, `AddSelectedFdContacts` ni `SelectFdContactsDialog`. Se
  recomienda crearlos.
- **Validación manual pendiente:** Probar el flujo completo en la app (botón →
  loading → dialog → selección → añadir → verificar en Firestore).
- **Campo fiscalId en API FD:** Se usa `main['fiscalId']` (camelCase),
  consistente con `GetFdFiscalIds`.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en la app + creación de tests
  unitarios
