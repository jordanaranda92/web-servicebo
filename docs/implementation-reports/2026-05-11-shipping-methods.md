# Implementation Report: Métodos de envío

- **Fecha:** 2026-05-11
- **Identificador:** shipping-methods
- **Plan técnico:** docs/technical-analysis/2026-05-11-shipping-methods.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado la feature completa de "Métodos de envío" con CRUD en
Firestore, gestión desde menú lateral, y asignación por día de la semana en la
tabla de clientes. Se renombró la columna "Nombre FD" a "Nombre Factura
Directa". La compilación pasa sin errores.

## 2) Alcance ejecutado

- Feature shipping_methods completa (domain, data, presentation) con Clean
  Architecture
- Integración en menú lateral y navegación
- Extensión de Client entity/model con campo `shippingMethodsByDay`
- Diálogo de asignación de métodos por día (Lunes–Domingo) en tabla de clientes
- Nueva columna "Métodos de envío" en tabla de clientes
- Renombrado columna "Nombre FD" → "Nombre Factura Directa"
- Limpieza automática de referencias al eliminar un método de envío
- 30 nuevas claves i18n

## 3) Artefactos tocados

### Creados

- `lib/features/shipping_methods/domain/entities/shipping_method.dart`
- `lib/features/shipping_methods/domain/repositories/shipping_methods_repository.dart`
- `lib/features/shipping_methods/domain/usecases/watch_shipping_methods.dart`
- `lib/features/shipping_methods/domain/usecases/get_shipping_methods.dart`
- `lib/features/shipping_methods/domain/usecases/add_shipping_method.dart`
- `lib/features/shipping_methods/domain/usecases/update_shipping_method.dart`
- `lib/features/shipping_methods/domain/usecases/update_shipping_method_phone.dart`
- `lib/features/shipping_methods/domain/usecases/delete_shipping_method.dart`
- `lib/features/shipping_methods/data/datasources/shipping_method_firestore_data_source.dart`
- `lib/features/shipping_methods/data/datasources/shipping_method_firestore_data_source_impl.dart`
- `lib/features/shipping_methods/data/repositories/shipping_methods_repository_impl.dart`
- `lib/features/shipping_methods/presentation/bloc/shipping_methods_state.dart`
- `lib/features/shipping_methods/presentation/bloc/shipping_methods_cubit.dart`
- `lib/features/shipping_methods/presentation/pages/shipping_methods_page.dart`
- `lib/app/di/modules/shipping_methods_module.dart`
- `lib/features/clients/presentation/widgets/shipping_methods_by_day_dialog.dart`

### Modificados

- `lib/app/di/injection.dart`
- `lib/features/home/presentation/widgets/side_menu.dart`
- `lib/features/home/presentation/pages/side_menu_shell.dart`
- `lib/features/home/presentation/bloc/side_menu_cubit.dart`
- `lib/features/clients/domain/entities/client.dart`
- `lib/features/clients/data/models/client_model.dart`
- `lib/features/clients/domain/repositories/clients_repository.dart`
- `lib/features/clients/domain/usecases/save_clients_batch.dart`
- `lib/features/clients/data/repositories/clients_repository_impl.dart`
- `lib/features/clients/presentation/bloc/clients_cubit.dart`
- `lib/app/di/modules/clients_module.dart`
- `lib/features/clients/presentation/pages/clients_page.dart`
- `lib/app/localization/l10n/app_es.arb`

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

- `flutter analyze`: 0 issues found
- Corrección de deprecación: `value` → `initialValue` en
  `DropdownButtonFormField`

## 5) Desviaciones respecto al análisis técnico

- Ninguna desviación material. Ajuste menor: uso de `initialValue` en lugar de
  `value` para `DropdownButtonFormField` por deprecación en Flutter actual.

## 6) Riesgos, incidencias y pendientes

- **Pendiente:** Tests unitarios para la nueva feature (cubit, repository, use
  cases)
- **Pendiente:** Tests del diálogo de asignación por día
- **Riesgo bajo:** La limpieza de referencias al eliminar método lee todos los
  clientes; viable para <500 clientes pero podría requerir optimización si el
  volumen crece

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual de la UI + escritura de tests
  unitarios
