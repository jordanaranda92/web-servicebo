# Implementation Report: Mejoras Pedidos de Hoy

- **Fecha:** 2026-05-13
- **Identificador:** orders-today-improvements
- **Plan técnico:**
  docs/technical-analysis/2026-05-13-orders-today-improvements.md
- **Estado:** Completed

## 1) Resumen

Se han implementado las tres mejoras solicitadas para la pantalla "Pedidos de
hoy":

1. El badge de presencia muestra el `userName` del usuario en lugar del email.
2. En pantallas móviles se muestra un placeholder informativo en lugar de la
   tabla.
3. La serie de factura se persiste en Firestore
   (`factura_directa_configuration/default`) en lugar de SharedPreferences.

La ejecución se completó sin bloqueos. Todos los tests pasan y `flutter analyze`
no reporta issues.

## 2) Alcance ejecutado

- ✅ PA-01: Serie de factura migrada a Firestore (remote datasource, repositorio
  async, DI, use case, widget)
- ✅ PA-02: Placeholder móvil con i18n
- ✅ PA-03: Badge con userName resuelto desde AuthRepository

## 3) Artefactos tocados

### Creados

- `lib/features/settings/data/datasources/remote/settings_remote_data_source.dart`
- `lib/features/settings/data/datasources/remote/settings_remote_data_source_impl.dart`

### Modificados

- `lib/features/settings/domain/repositories/settings_repository.dart` — firma
  async con Either
- `lib/features/settings/data/repositories/settings_repository_impl.dart` —
  inyección remote DS
- `lib/features/settings/data/datasources/local/settings_local_data_source.dart`
  — eliminados métodos invoice series
- `lib/features/settings/data/datasources/local/settings_local_data_source_impl.dart`
  — eliminados métodos invoice series
- `lib/app/di/modules/settings_module.dart` — registro remote DS
- `lib/app/di/modules/orders_today_module.dart` — eliminado factory de
  OrdersPresenceCubit (ya no utilizado)
- `lib/features/invoices/domain/usecases/create_provisional_invoice.dart` —
  await + validación serie
- `lib/features/settings/presentation/widgets/invoice_series_section.dart` —
  carga async
- `lib/features/orders_today/presentation/pages/orders_today_page.dart` —
  placeholder móvil + userName
- `lib/app/localization/l10n/app_es.arb` — claves `ordersTodayMobileTitle` y
  `ordersTodayMobileDescription`
- `test/features/settings/data/repositories/settings_repository_impl_test.dart`
  — mock remote DS

### Retirados o reemplazados

- Ningún archivo eliminado; se retiraron métodos de invoice series del local
  datasource

## 4) Validación ejecutada

| Validación                | Resultado             |
| ------------------------- | --------------------- |
| `flutter analyze`         | ✅ No issues found    |
| `flutter test` (25 tests) | ✅ All tests passed   |
| `flutter gen-l10n`        | ✅ Generación exitosa |

Incidencias encontradas durante validación:

1. Import no usado de `invoice_failures.dart` en `CreateProvisionalInvoice` →
   eliminado
2. Test de `SettingsRepositoryImpl` requería segundo argumento positional →
   añadido mock remote DS

Ambas resueltas sin cambiar alcance.

## 5) Desviaciones respecto al análisis técnico

| Desviación                                                                            | Justificación                                                                                                                                                                                              | Impacto                 |
| ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| Eliminación del factory `OrdersPresenceCubit` del DI module                           | El análisis técnico indicaba crear el cubit directamente en la page, pero no mencionaba eliminar el factory viejo del DI module. Se eliminó porque ya no tenía consumidores y dejarlo generaría confusión. | Nulo — sin consumidores |
| Limpieza de imports asociados (`FirebaseAuth`, `OrdersPresenceCubit`) en el DI module | Consecuencia directa de la eliminación del factory                                                                                                                                                         | Nulo                    |

## 6) Riesgos, incidencias y pendientes

- **Firestore rules**: La colección `factura_directa_configuration` necesita
  reglas de seguridad configuradas en Firebase Console. Actualmente no están
  definidas en `firebase.json` / `firestore.rules`.
- **Migración de datos**: Si algún usuario ya tenía serie guardada en
  SharedPreferences, ese valor se pierde. Debe comunicarse que hay que
  re-introducir el valor.
- **Tests de integración**: No existen tests para el remote datasource de
  Firestore ni para el flujo completo de presencia con userName. Se recomienda
  añadirlos.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: configurar Firestore rules para
  `factura_directa_configuration` y validación manual en dispositivo
