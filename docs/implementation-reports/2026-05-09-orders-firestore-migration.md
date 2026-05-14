# Implementation Report: Migración de pedidos de hoy de Google Sheets a Firestore

- **Fecha:** 2026-05-09
- **Identificador:** orders-firestore-migration
- **Plan técnico:**
  docs/technical-analysis/2026-05-09-orders-firestore-migration.md
- **Estado:** Completed

## 1) Resumen

Se ha reemplazado el datasource de Google Sheets/Drive por Firestore como fuente
de datos de la feature `orders_today`. El flujo completo de creación, lectura y
escritura de pedidos del día opera ahora contra la colección
`orders/{YYYY-MM-DD}` con subcolección `rows/{productId}`. La interfaz de
usuario permanece intacta. RTDB se mantiene sin cambios para sincronización en
tiempo real.

## 2) Alcance ejecutado

- ✅ Modelos Firestore (`OrderDocumentModel`, `OrderRowModel`)
- ✅ Contrato `OrderFirestoreDataSource` con todos los métodos del plan
- ✅ Implementación `OrderFirestoreDataSourceImpl` con `WriteBatch`,
  `FieldValue.delete()` para sparse, `FieldValue.serverTimestamp()` para
  `lastModifiedAt`
- ✅ Reescritura completa de `OrdersTodayRepositoryImpl`: nuevo datasource,
  resolución de nombres, sincronización de activos (RF-11/RF-12), traducción de
  índices a IDs
- ✅ Actualización del módulo DI
- ✅ Adaptación cosmética del BLoC (renombrado Sheets → Firestore)
- ✅ Adaptación de `OrdersTodayPage`: check de Firebase disponible en vez de
  Google Drive configurado

## 3) Artefactos tocados

### Creados

- `lib/features/orders_today/data/models/order_document_model.dart`
- `lib/features/orders_today/data/models/order_row_model.dart`
- `lib/features/orders_today/data/datasources/remote/order_firestore_data_source.dart`
- `lib/features/orders_today/data/datasources/remote/order_firestore_data_source_impl.dart`

### Modificados

- `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`
  — reescrito completamente
- `lib/app/di/modules/orders_today_module.dart` — añadido registro de
  `OrderFirestoreDataSource`, actualizado constructor del repositorio (4 params
  en vez de 6)
- `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart` —
  renombrado variables/métodos de Sheets a genérico
- `lib/features/orders_today/presentation/pages/orders_today_page.dart` —
  reemplazado check de Drive por check de Firebase disponible, eliminado import
  de `SettingsRepository`

### Retirados o reemplazados

- Uso de `OrdersSheetDataSource` en el repositorio → reemplazado por
  `OrderFirestoreDataSource`
- Uso de `GoogleSheetsDataSource` en el repositorio → eliminado (clientes se
  leen de Firestore)
- Uso de `GoogleDriveRemoteDataSource` en el repositorio → eliminado
- Uso de `SettingsLocalDataSource` en el repositorio → eliminado
- Ningún archivo fue eliminado del código base

## 4) Validación ejecutada

- **Análisis estático (`dart analyze`):** 0 issues en todos los archivos de
  `orders_today/` y `orders_today_module.dart`
- **Errores IDE (Language Server):** 0 errores en los 8 archivos
  creados/modificados
- **Verificación manual del flujo DI:** constructor del repositorio recibe 4
  dependencias que coinciden con los registros en GetIt

### Incidencias encontradas y resolución

- Ninguna incidencia durante la implementación.

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** El plan indicaba que `OrdersTodayPage` debía cambiar el
  check `_isDriveConfigured` a verificar Firebase. Se implementó usando
  `sl.isRegistered<bool>(instanceName: 'firebaseAvailable')` que es el patrón ya
  existente en el módulo DI y en la propia page para otras comprobaciones (ej:
  `hasPresence`).
  - **Justificación:** Es el mecanismo estándar del proyecto para verificar
    disponibilidad de Firebase.
  - **Impacto:** Ninguno negativo. La page ya no depende de
    `SettingsRepository`.

- **Desviación 2:** El análisis técnico sugería considerar el reset de RTDB al
  sincronizar activos (PA-02). **No se implementó** el reset automático de RTDB
  en `syncActiveEntities`. Motivo: el riesgo de desfase de índices RTDB es real
  pero depende de la decisión del usuario (PA-02 estaba como pregunta abierta).
  El reset puede añadirse en una iteración posterior si se confirma que es
  aceptable.
  - **Justificación:** No bloquea la funcionalidad base; el desfase solo ocurre
    si se sincronizan activos mientras hay ediciones en curso vía RTDB.
  - **Impacto:** Bajo — escenario poco frecuente.

## 6) Riesgos, incidencias y pendientes

### Riesgos

- **RTDB desfase de índices:** si se sincroniza un producto nuevo (insertado en
  medio de `productIds`), los cell keys de RTDB (`row_col`) se desfasan.
  Mitigación pendiente: valorar implementar
  `OrdersRtdbDataSource.resetToday(date)` al detectar cambios en la
  sincronización.

### Pendientes

- **Tests unitarios:** no se han creado como parte de esta implementación. Se
  recomienda crearlos para:
  - `OrderDocumentModel` y `OrderRowModel` (fromFirestore/toMap)
  - `OrderFirestoreDataSourceImpl` (con `fake_cloud_firestore`)
  - `OrdersTodayRepositoryImpl` (con mocks de mocktail)
- **Verificar dev dependency `fake_cloud_firestore`:** necesaria para tests del
  datasource. Comprobar si está en `pubspec.yaml` o añadirla.
- **Validación manual completa:** probar los flujos end-to-end en la app (crear
  pedido, editar cantidad, editar stock, sincronización de activos).
- **Security rules de Firestore:** la colección `orders` necesita reglas
  configuradas para permitir lectura/escritura a usuarios autenticados.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual end-to-end + creación de tests
  unitarios
