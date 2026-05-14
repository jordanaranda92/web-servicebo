# Implementation Report: Eliminar campo order de clientes

- **Fecha:** 2026-05-10
- **Identificador:** remove-client-order-field
- **Plan técnico:**
  docs/technical-analysis/2026-05-10-remove-client-order-field.md
- **Estado:** Completed

## 1) Resumen

Se ha eliminado completamente el campo `order` del feature `clients` en todas
las capas (domain, data, presentation) y se ha implementado un mecanismo de
limpieza Firestore (`removeFieldFromAll`) para eliminar el campo de los
documentos existentes. La aplicación compila sin errores y los 58 tests pasan.

## 2) Alcance ejecutado

- Todas las partes del plan técnico se han implementado (pasos 1-13).
- Se ha eliminado `order` de: entidad, modelo, contrato de repositorio,
  implementación de repositorio, caso de uso, cubit, página.
- Se ha simplificado la ordenación a solo alfabética por nombre en ambos métodos
  (`getClients`, `watchClients`).
- Se ha creado el use case `RemoveClientOrderField` y el método
  `removeFieldFromAll` en el datasource para limpieza de Firestore.
- Se ha eliminado la clave i18n `clientsColumnOrderPosition` y regenerado los
  archivos de localización.
- Se ha registrado el nuevo use case en el módulo DI.

## 3) Artefactos tocados

### Creados

- `lib/features/clients/domain/usecases/remove_client_order_field.dart`

### Modificados

- `lib/features/clients/domain/entities/client.dart`
- `lib/features/clients/domain/repositories/clients_repository.dart`
- `lib/features/clients/domain/usecases/save_clients_batch.dart`
- `lib/features/clients/domain/usecases/sync_clients_from_fd.dart`
- `lib/features/clients/data/models/client_model.dart`
- `lib/features/clients/data/datasources/client_firestore_data_source.dart`
- `lib/features/clients/data/datasources/client_firestore_data_source_impl.dart`
- `lib/features/clients/data/repositories/clients_repository_impl.dart`
- `lib/features/clients/presentation/bloc/clients_cubit.dart`
- `lib/features/clients/presentation/pages/clients_page.dart`
- `lib/app/localization/l10n/app_es.arb`
- `lib/app/localization/l10n/app_localizations.dart` (regenerado)
- `lib/app/localization/l10n/app_localizations_es.dart` (regenerado)
- `lib/app/di/modules/clients_module.dart`

### Retirados o reemplazados

- Ningún archivo eliminado.

## 4) Validación ejecutada

| Validación                                                                     | Resultado                 |
| ------------------------------------------------------------------------------ | ------------------------- |
| `flutter analyze lib/features/clients/ lib/app/di/modules/clients_module.dart` | ✅ No issues found        |
| `grep -rn '\.order' lib/features/clients/` (excluyendo removeField/FieldValue) | ✅ 0 coincidencias        |
| `grep -rn 'orderChanges' lib/features/clients/`                                | ✅ 0 coincidencias        |
| `flutter test` (58 tests)                                                      | ✅ All tests passed       |
| `flutter gen-l10n`                                                             | ✅ Regenerado sin errores |

### Incidencias encontradas y resolución

- **Incidencia:** El primer reemplazo del bloque `sort` en
  `clients_repository_impl.dart` actuó sobre el de `watchClients()` pero dejó
  intacto el de `getClients()` debido a coincidencia parcial. Se detectó con
  `flutter analyze` y se corrigió aplicando el reemplazo con contexto más
  específico.

## 5) Desviaciones respecto al análisis técnico

- Ninguna desviación material. Todos los pasos se ejecutaron según el plan.

## 6) Riesgos, incidencias y pendientes

- **Pendiente:** La operación de limpieza de Firestore (`RemoveClientOrderField`
  / `removeFieldFromAll('order')`) está implementada como use case pero **no se
  ha ejecutado** contra los datos reales. Debe invocarse de forma puntual
  (manual o desde UI de admin) una vez validado el despliegue.
- **Riesgo:** Si existen consumidores externos del campo `order` en la colección
  `clients` de Firestore, se verán afectados al ejecutar la limpieza. Se
  recomienda verificar antes de ejecutar.
- **Feature `products`:** No se ha tocado. Su campo `order` sigue intacto e
  independiente.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: Validación manual en la pantalla de clientes
  (confirmar que la columna "Orden" no aparece y que el listado se ordena
  alfabéticamente). Ejecutar `RemoveClientOrderField` cuando se confirme la
  estabilidad del despliegue.
