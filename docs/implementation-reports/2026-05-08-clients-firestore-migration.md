# Implementation Report: Migración de clientes a Firestore

- **Fecha:** 2026-05-08
- **Identificador:** clients-firestore-migration
- **Plan técnico:**
  docs/technical-analysis/2026-05-08-clients-firestore-migration.md
- **Estado:** Completed

## 1) Resumen

Se ha migrado la carga y persistencia de datos complementarios de clientes desde
Google Sheets a Firebase Firestore. La vista de clientes ahora lee de la
colección `clients` en Firestore. Se añadió un botón manual "Sincronizar
clientes" en Ajustes > FacturaDirecta para importar/actualizar contactos desde
la API de FacturaDirecta hacia Firestore. Se eliminó toda dependencia de Google
Sheets en el feature de clientes.

## 2) Alcance ejecutado

- ✅ Capa de datos: nuevo `ClientModel` y `ClientFirestoreDataSource`
  (abstracto + impl)
- ✅ Capa de dominio: entidad `Client` simplificada, repositorio reducido a 2
  métodos, use case `SyncClientsFromFd`
- ✅ Capa de presentación: `ClientsCubit`/`ClientsState` simplificados,
  `ClientsPage` actualizada
- ✅ Feature Settings: `FacturaDirectaCubit` extendido con `syncClients()`,
  botón de sincronización en UI
- ✅ DI: módulos actualizados para nuevas dependencias
- ✅ i18n: claves añadidas y generadas
- ✅ Limpieza: 7 archivos obsoletos eliminados

## 3) Artefactos tocados

### Creados

- `lib/features/clients/data/models/client_model.dart`
- `lib/features/clients/data/datasources/client_firestore_data_source.dart`
- `lib/features/clients/data/datasources/client_firestore_data_source_impl.dart`
- `lib/features/clients/domain/entities/sync_clients_result.dart`
- `lib/features/clients/domain/usecases/sync_clients_from_fd.dart`

### Modificados

- `lib/features/clients/domain/entities/client.dart`
- `lib/features/clients/domain/repositories/clients_repository.dart`
- `lib/features/clients/domain/usecases/get_clients.dart`
- `lib/features/clients/data/repositories/clients_repository_impl.dart`
- `lib/features/clients/presentation/bloc/clients_cubit.dart`
- `lib/features/clients/presentation/bloc/clients_state.dart`
- `lib/features/clients/presentation/pages/clients_page.dart`
- `lib/features/settings/presentation/bloc/factura_directa_cubit.dart`
- `lib/features/settings/presentation/bloc/factura_directa_state.dart`
- `lib/features/settings/presentation/widgets/factura_directa_section.dart`
- `lib/app/di/modules/clients_module.dart`
- `lib/app/di/modules/settings_module.dart`
- `lib/app/localization/l10n/app_es.arb`

### Retirados

- `lib/features/clients/data/dto/client_dto.dart`
- `lib/features/clients/data/dto/client_sheet_dto.dart`
- `lib/features/clients/data/dto/client_category_sheet_dto.dart`
- `lib/features/clients/domain/usecases/toggle_client_field.dart`
- `lib/features/clients/domain/usecases/update_client_category.dart`
- `lib/features/clients/domain/usecases/update_client_order.dart`
- `lib/features/clients/domain/entities/clients_result.dart`

## 4) Validación ejecutada

- `dart analyze lib/` → **No issues found**
- `flutter gen-l10n` → generación correcta
- No se ejecutaron tests unitarios (los tests existentes requieren actualización
  por los cambios en entidades y repositorio)

## 5) Desviaciones respecto al análisis técnico

- **Columna fiscalId eliminada de la UI**: el análisis técnico no mencionaba
  explícitamente la eliminación de la columna `fiscalId` de la tabla, pero al
  eliminar el campo de la entidad `Client`, la columna dejó de tener sentido. Se
  eliminó del header y del row.
- **`_buildConfigMissing` y `_buildWarningBanner` eliminados**: métodos que
  dependían de estados de Google Sheets que ya no existen.
- **`configNotFound` eliminado del enum `ClientsErrorType`**: ya no aplica al no
  depender de configuración de Google Sheets para cargar clientes.

## 6) Riesgos, incidencias y pendientes

- **Tests unitarios**: los tests existentes en `test/features/clients/`
  necesitan actualización para reflejar la nueva estructura de entidades,
  repositorio y cubit. No se actualizaron en esta implementación.
- **Migración de datos**: se necesita ejecutar la sincronización inicial desde
  Ajustes > FacturaDirecta > "Sincronizar clientes" para poblar la colección
  `clients` en Firestore.
- **Campos complementarios (isActive, clientCategoryId, order)**: los clientes
  nuevos sincronizados desde FD se crean con `isActive: true`,
  `clientCategoryId: null`, `order: null`. Estos valores deben configurarse
  manualmente desde la vista de clientes.
- **Claves i18n huérfanas**: las claves `clientsConfigMissing*`,
  `clientsGoToSettings`, `clientsColumnFiscalId` pueden quedar sin uso en el
  `.arb`. No se eliminaron para evitar romper otros posibles consumidores.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: actualizar tests unitarios y realizar prueba
  manual de sincronización con Firestore
