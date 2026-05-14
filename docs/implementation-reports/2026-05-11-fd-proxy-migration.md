# Implementation Report: Migración API FD a Cloud Function Proxy

- **Fecha:** 2026-05-11
- **Identificador:** fd-proxy-migration
- **Fuente:** docs/technical-analysis/2026-05-11-fd-proxy-migration.md
- **Estado:** Completed

## 1) Resumen

Se ha migrado toda la comunicación con la API de Factura Directa para que pase
exclusivamente a través de la Cloud Function `fdProxy`. Se han eliminado las
credenciales expuestas (API token y company ID) del código Flutter. El proxy
inyecta automáticamente el company ID en las rutas.

## 2) Alcance ejecutado

- Todas las partes del plan técnico (pasos 1–9) se han implementado
  completamente
- Se detectaron y corrigieron 2 artefactos adicionales no contemplados en el
  análisis técnico: `FdCountersCubit` y `settings_page.dart`

## 3) Artefactos tocados

### Creados

- Ninguno (solo modificaciones)

### Modificados

- `functions/src/index.ts` — CF inyecta company ID automáticamente
- `lib/core/data/datasources/factura_directa_api_data_source.dart` — Eliminado
  `companyId` de todos los métodos
- `lib/core/data/datasources/factura_directa_api_data_source_impl.dart` —
  Reescrito: usa `_callProxy()` vía Cloud Functions
- `lib/app/config/app_config.dart` — Eliminados getters FD
- `lib/app/config/environments/local_config.dart` — Eliminadas implementaciones
  FD
- `lib/app/config/environments/pro_config.dart` — Eliminadas credenciales
  expuestas
- `lib/app/di/modules/core_module.dart` — Eliminados Dio y FlutterSecureStorage;
  DataSource con 1 param
- `lib/app/di/modules/settings_module.dart` — Eliminado FD remote DS;
  simplificado repository y cubit
- `lib/app/di/modules/clients_module.dart` — Reducidos params en 4 use cases
- `lib/app/di/modules/products_module.dart` — GetFdProducts con 1 param
- `lib/app/di/modules/invoices_module.dart` — Reducidos params en repository y 3
  use cases
- `lib/app/di/modules/home_module.dart` — FdCountersCubit sin SettingsRepository
- `lib/features/settings/data/datasources/local/settings_local_data_source.dart`
  — Eliminados métodos FD
- `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart`
  — Eliminado FlutterSecureStorage
- `lib/features/settings/domain/repositories/settings_repository.dart` —
  Eliminados métodos FD
- `lib/features/settings/data/repositories/settings_repository_impl.dart` —
  Reducido a 2 deps
- `lib/features/settings/presentation/bloc/factura_directa_cubit.dart` — Solo
  `syncClients()`, sin SettingsRepository
- `lib/features/settings/presentation/bloc/factura_directa_state.dart` —
  Eliminados estados de verify/saved/config
- `lib/features/settings/presentation/widgets/factura_directa_section.dart` —
  Solo botón sync
- `lib/features/settings/presentation/pages/settings_page.dart` — Eliminado
  `loadSaved()`
- `lib/features/home/presentation/bloc/fd_counters_cubit.dart` — Eliminada
  dependencia SettingsRepository
- `lib/features/clients/domain/usecases/sync_clients_from_fd.dart` — Sin
  SettingsRepository
- `lib/features/clients/domain/usecases/get_fd_fiscal_ids.dart` — Sin
  SettingsRepository
- `lib/features/clients/domain/usecases/get_client_fd_data.dart` — Sin
  SettingsRepository
- `lib/features/clients/domain/usecases/fetch_new_fd_contacts.dart` — Sin
  SettingsRepository
- `lib/features/products/domain/usecases/get_fd_products.dart` — Sin
  SettingsRepository
- `lib/features/invoices/domain/usecases/create_provisional_invoice.dart` — Sin
  SettingsRepository
- `lib/features/invoices/domain/usecases/check_duplicate_invoice.dart` — Sin
  SettingsRepository
- `lib/features/invoices/domain/usecases/prepare_invoice_preview.dart` — Sin
  SettingsRepository
- `lib/features/invoices/data/repositories/invoices_repository_impl.dart` — Sin
  SettingsRepository
- `test/features/settings/presentation/bloc/factura_directa_cubit_test.dart` —
  Reescrito
- `test/features/settings/data/repositories/settings_repository_impl_test.dart`
  — Reescrito

### Retirados o reemplazados

- `lib/features/settings/domain/entities/factura_directa_config.dart` —
  Eliminado
- `lib/features/settings/data/datasources/remote/factura_directa_remote_data_source.dart`
  — Eliminado
- `lib/features/settings/data/datasources/remote/factura_directa_remote_data_source_impl.dart`
  — Eliminado

## 4) Validación ejecutada

- `dart analyze lib/` — 0 errores (1 warning preexistente `_logger` unused, 2
  info de null-aware)
- `dart analyze test/` — 0 errores, 0 warnings
- `grep` de credenciales (`facturaDirectaApiToken`, `facturaDirectaCompanyId`,
  `setApiToken`, `_apiToken`, `DdaxdT`) en `lib/` — 0 resultados
- `flutter test test/features/settings/` — 6/6 tests pasando

## 5) Desviaciones respecto al análisis técnico

- **FdCountersCubit**: No contemplado en el análisis técnico. Dependía de
  `SettingsRepository.getFacturaDirectaConfig()` para verificar si FD estaba
  configurado. Se eliminó esa comprobación ya que el proxy siempre está
  disponible.
- **settings_page.dart**: Llamaba a `loadSaved()` que ya no existe en el cubit.
  Se eliminó la llamada.
- **Dio y FlutterSecureStorage**: Se eliminaron del `core_module.dart` al
  confirmar que ya no se usan en ningún lugar de `lib/`.

## 6) Riesgos, incidencias y pendientes

- **Paquetes no usados**: `dio` y `flutter_secure_storage` pueden eliminarse del
  `pubspec.yaml` si no se usan en otros contextos (verificar antes)
- **`FdCountersNotConfigured` state**: Sigue existiendo en
  `fd_counters_state.dart` y se referencia en `home_page.dart`, pero ya nunca se
  emitirá. Se podría limpiar en un PR de seguimiento.
- **Tests de integración**: No se ejecutaron tests E2E. Se recomienda validar
  manualmente el flujo de sincronización de clientes y la carga de facturas.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual del flujo completo + limpieza de
  dependencias no usadas en pubspec.yaml
