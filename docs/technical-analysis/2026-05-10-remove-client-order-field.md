# Technical Analysis: Eliminar campo order de clientes

- **Fecha:** 2026-05-10
- **Identificador:** remove-client-order-field
- **Fuente:** docs/functional-analysis/2026-05-10-remove-client-order-field.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Eliminación completa del campo `order` (`int?`) de la entidad `Client`, su
  modelo de datos, contratos de repositorio, implementación, caso de uso, cubit
  y UI.
- Simplificación de la lógica de ordenación en el repositorio: de orden por
  `order` + nombre a solo orden alfabético por nombre.
- Eliminación del campo `order` de Firestore mediante un nuevo método en el
  datasource que ejecute `FieldValue.delete()` en batch.
- Limpieza de la UI: columna "Orden", controladores de texto y parámetros
  asociados.
- **Áreas impactadas:** Feature `clients` (todas las capas), i18n
  (`app_es.arb`).
- **Riesgo general:** Bajo — cambio sustractivo acotado a un solo feature, sin
  dependencias externas.

## 2) Contexto técnico observado

- **Arquitectura:** Clean Architecture feature-first con capas `domain/`,
  `data/`, `presentation/`.
- **Estado:** Gestionado con Cubit (`ClientsCubit`) + estados inmutables
  (`ClientsState`).
- **DI:** GetIt, registrado en `lib/app/di/modules/clients_module.dart`.
- **Persistencia:** Firestore (`cloud_firestore`), colección `clients`, accedida
  mediante `ClientFirestoreDataSourceImpl`.
- **Patrón de escritura batch:**
  `batchUpdate(Map<String, Map<String, dynamic>>)` ya existe en el datasource y
  usa `WriteBatch`.
- **i18n:** ARB con clave `clientsColumnOrderPosition` usada solo en la cabecera
  de la tabla de clientes.
- **Sincronización FD:** `SyncClientsFromFd` crea nuevos clientes con
  `order: null` — se eliminarán las referencias.
- **El campo `order` de productos** (`features/products/`) es completamente
  independiente y no se toca.

### Módulos / capas relevantes

| Capa         | Artefacto                                          | Rol                                                                               |
| ------------ | -------------------------------------------------- | --------------------------------------------------------------------------------- |
| Domain       | `client.dart` (entity)                             | Define `order` como campo                                                         |
| Domain       | `clients_repository.dart` (contrato)               | Recibe `orderChanges` en `saveClientsBatch`                                       |
| Domain       | `save_clients_batch.dart` (use case + params)      | Pasa `orderChanges` al repositorio                                                |
| Data         | `client_model.dart`                                | Lee/escribe `order` de/a Firestore                                                |
| Data         | `client_firestore_data_source.dart` / `_impl.dart` | Datasource abstracto e implementación Firestore                                   |
| Data         | `clients_repository_impl.dart`                     | Lógica de ordenación por `order`, param `orderChanges` en `saveClientsBatch`      |
| Presentation | `clients_cubit.dart`                               | Param `orderChanges` en `saveBatchChanges`                                        |
| Presentation | `clients_page.dart`                                | `_orderControllers`, columna "Orden", params `order`/`clearOrder` en `_saveField` |
| i18n         | `app_es.arb`                                       | Clave `clientsColumnOrderPosition`                                                |

### Restricciones

- Los batches de Firestore tienen un límite de **500 operaciones** por
  `WriteBatch`.
- El campo `order` de productos no debe verse afectado.
- No se introducen nuevas dependencias.

## 3) Objetivo técnico

- **Qué debe cambiar:** Eliminar todas las referencias al campo `order` en el
  feature `clients` (código + datos Firestore).
- **Resultado:** Código sin campo `order` en clientes, datos Firestore
  limpiados, UI simplificada.
- **Limitaciones:** El borrado del campo en Firestore es irreversible (no se
  puede restaurar el campo sin un backup previo).

## 4) Diseño técnico de la solución

### Enfoque propuesto

Cambio sustractivo en 3 fases:

1. **Capa domain:** Eliminar `order` de entity, contrato de repositorio y use
   case.
2. **Capa data:** Eliminar `order` de model, repositorio impl. Añadir método
   `removeFieldFromAll` al datasource para limpieza Firestore. Simplificar
   ordenación.
3. **Capa presentation + i18n:** Eliminar columna "Orden", controladores,
   parámetros y clave ARB.

### Componentes / módulos / servicios afectados

Todos dentro de `lib/features/clients/` +
`lib/app/localization/l10n/app_es.arb`.

### Contratos e interfaces

**`ClientFirestoreDataSource` (abstract)** — Añadir:

```dart
Future<void> removeFieldFromAll(String fieldName);
```

Este método recorre todos los documentos de la colección y elimina el campo
indicado usando `FieldValue.delete()`, respetando el límite de 500 ops/batch.

**`ClientsRepository` (abstract)** — Modificar `saveClientsBatch`:

```dart
Future<Either<Failure, Unit>> saveClientsBatch({
  Map<String, String> nameChanges,
  Map<String, bool> activeToggles,
  Map<String, String?> categoryChanges,
  // ELIMINAR: Map<String, int?> orderChanges,
});
```

### Flujo de datos o de control

**Flujo normal (sin cambios funcionales):** `ClientsPage` →
`ClientsCubit.saveBatchChanges()` → `SaveClientsBatch` (use case) →
`ClientsRepository.saveClientsBatch()` →
`ClientFirestoreDataSource.batchUpdate()`.

Se elimina `orderChanges` de toda esta cadena.

**Flujo de limpieza Firestore (nuevo, puntual):** Script o invocación manual →
`ClientFirestoreDataSource.removeFieldFromAll('order')` → lee todos los docs →
batch `FieldValue.delete()` en chunks de 500 → commit.

**Flujo de ordenación (simplificado):** `ClientsRepositoryImpl.getClients()` /
`watchClients()` →
`clients.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()))`.

### Gestión de errores y validaciones

- `removeFieldFromAll` captura `FirebaseException` y lanza `ServerException`,
  igual que los otros métodos del datasource.
- Si un batch falla, la operación lanza excepción; los documentos no procesados
  en batches posteriores quedan sin modificar (se puede reintentar).
- El campo `order` en `fromFirestore` se elimina: si un documento aún contiene
  `order` (ej: la limpieza no se ejecutó o falló parcialmente), simplemente se
  ignora — el modelo no lo lee.

### Consideraciones de compatibilidad o migración

- **Backwards compatible:** Aunque la limpieza Firestore no se ejecute
  inmediatamente, el código funcionará porque `fromFirestore` ya no lee `order`.
  Los datos legacy son inofensivos.
- **Sin rollback automático:** Una vez eliminado el campo de Firestore, no se
  puede restaurar sin backup. Se recomienda ejecutar la limpieza solo tras
  verificar que el código desplegado ya no usa `order`.
- La operación de limpieza se puede integrar como un método invocable desde la
  UI de settings, un botón de admin, o un script de consola de Firebase.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                     | Propósito                                                                                             |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Método `removeFieldFromAll(String)` en `ClientFirestoreDataSource` (abstract) | Contrato para limpieza de campos                                                                      |
| Método `removeFieldFromAll(String)` en `ClientFirestoreDataSourceImpl`        | Implementación: leer docs, batch `FieldValue.delete()` en chunks de 500                               |
| UseCase `RemoveClientOrderField` en `domain/usecases/`                        | Orquesta la llamada a `removeFieldFromAll` a través del repositorio, devuelve `Either<Failure, Unit>` |
| Método `removeOrderField()` en `ClientsRepository` (abstract)                 | Contrato del repositorio para la operación de limpieza                                                |
| Método `removeOrderField()` en `ClientsRepositoryImpl`                        | Implementación que delega al datasource                                                               |

### Artefactos a modificar

| Artefacto                                                                      | Cambio esperado                                                                                                                                                                                              |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `lib/features/clients/domain/entities/client.dart`                             | Eliminar campo `order`, actualizar constructor, `copyWith`, `props`                                                                                                                                          |
| `lib/features/clients/data/models/client_model.dart`                           | Eliminar campo `order`, actualizar constructor, `fromFirestore`, `toMap`, `toEntity`                                                                                                                         |
| `lib/features/clients/domain/repositories/clients_repository.dart`             | Eliminar param `orderChanges` de `saveClientsBatch`; añadir `removeOrderField()`                                                                                                                             |
| `lib/features/clients/data/repositories/clients_repository_impl.dart`          | Eliminar param `orderChanges` de `saveClientsBatch`, simplificar sort en `getClients` y `watchClients`; implementar `removeOrderField()`                                                                     |
| `lib/features/clients/domain/usecases/save_clients_batch.dart`                 | Eliminar `orderChanges` de `SaveClientsBatchParams` y de la llamada al repositorio                                                                                                                           |
| `lib/features/clients/presentation/bloc/clients_cubit.dart`                    | Eliminar param `orderChanges` de `saveBatchChanges`                                                                                                                                                          |
| `lib/features/clients/presentation/pages/clients_page.dart`                    | Eliminar `_orderControllers`, su dispose, columna "Orden" en header, widget TextField de orden en filas, params `order`/`clearOrder` de `_saveField`, recolección de `orderChanges` en `_savePendingChanges` |
| `lib/features/clients/data/datasources/client_firestore_data_source.dart`      | Añadir `removeFieldFromAll(String)`                                                                                                                                                                          |
| `lib/features/clients/data/datasources/client_firestore_data_source_impl.dart` | Implementar `removeFieldFromAll(String)`                                                                                                                                                                     |
| `lib/features/clients/domain/usecases/sync_clients_from_fd.dart`               | Eliminar `order: null` del constructor de `ClientModel` al crear nuevos clientes                                                                                                                             |
| `lib/app/localization/l10n/app_es.arb`                                         | Eliminar claves `clientsColumnOrderPosition` y `@clientsColumnOrderPosition`                                                                                                                                 |
| `lib/app/di/modules/clients_module.dart`                                       | Registrar `RemoveClientOrderField` use case                                                                                                                                                                  |

### Artefactos a retirar o reemplazar

| Artefacto                                       | Motivo                                                     |
| ----------------------------------------------- | ---------------------------------------------------------- |
| Ninguno (no se elimina ningún archivo completo) | Solo se eliminan campos, parámetros y fragmentos de código |

## 6) Estrategia de implementación

### Paso 1: Domain — Entity `Client`

- Eliminar campo `final int? order`.
- Eliminar del constructor, `copyWith` y `props`.

### Paso 2: Domain — Contrato `ClientsRepository`

- Eliminar parámetro `orderChanges` de `saveClientsBatch`.
- Añadir método `Future<Either<Failure, Unit>> removeOrderField()`.

### Paso 3: Domain — UseCase `SaveClientsBatch`

- Eliminar `orderChanges` de `SaveClientsBatchParams` (campo, constructor,
  `props`).
- Eliminar `orderChanges` de la llamada a `_repository.saveClientsBatch`.

### Paso 4: Domain — UseCase `RemoveClientOrderField` (nuevo)

- Crear use case que invoque `_repository.removeOrderField()`.

### Paso 5: Data — Model `ClientModel`

- Eliminar campo `final int? order`.
- Eliminar del constructor, `fromFirestore`, `toMap`, `toEntity`.

### Paso 6: Data — Datasource abstract `ClientFirestoreDataSource`

- Añadir `Future<void> removeFieldFromAll(String fieldName)`.

### Paso 7: Data — Datasource impl `ClientFirestoreDataSourceImpl`

- Implementar `removeFieldFromAll`:
  ```dart
  @override
  Future<void> removeFieldFromAll(String fieldName) async {
    try {
      final snapshot = await _collection.get();
      final docs = snapshot.docs;
      // Process in chunks of 500 (Firestore batch limit)
      for (var i = 0; i < docs.length; i += 500) {
        final chunk = docs.skip(i).take(500);
        final batch = _firestore.batch();
        for (final doc in chunk) {
          if (doc.data().containsKey(fieldName)) {
            batch.update(doc.reference, {fieldName: FieldValue.delete()});
          }
        }
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error removing field "$fieldName": $e');
    }
  }
  ```

### Paso 8: Data — Repository impl `ClientsRepositoryImpl`

- Eliminar `orderChanges` de `saveClientsBatch` (parámetro, log, clave en
  `allIds`, bloque `if` en el loop).
- Simplificar `sort` en `getClients` y `watchClients`:
  ```dart
  clients.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  ```
- Implementar `removeOrderField()`:
  ```dart
  @override
  Future<Either<Failure, Unit>> removeOrderField() async {
    try {
      await _clientDataSource.removeFieldFromAll('order');
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure());
    } catch (e) {
      return Left(InternalFailure());
    }
  }
  ```

### Paso 9: Data — `SyncClientsFromFd`

- Eliminar `order: null` de la creación de `ClientModel` (línea ~86).

### Paso 10: Presentation — `ClientsCubit`

- Eliminar parámetro `orderChanges` de `saveBatchChanges`.
- Eliminar `orderChanges` de la construcción de `SaveClientsBatchParams`.

### Paso 11: Presentation — `ClientsPage`

- Eliminar declaración de `_orderControllers`.
- Eliminar dispose de `_orderControllers` en `dispose()`.
- Eliminar recolección de `orderChanges` en `_savePendingChanges()`.
- Eliminar params `order` y `clearOrder` de `_saveField`.
- Eliminar `orderChanges` de la llamada a `saveBatchChanges` en `_saveField`.
- Eliminar columna "Orden" del header (el `SizedBox(width: 80, ...)` con
  `clientsColumnOrderPosition`).
- Eliminar el `SizedBox(width: 80, ...)` con el `TextField` de orden en
  `_buildRow`.
- Eliminar el `SizedBox(width: AppSpacing.xl)` separador antes de la columna
  orden.

### Paso 12: i18n — `app_es.arb`

- Eliminar las líneas con `"clientsColumnOrderPosition"` y
  `"@clientsColumnOrderPosition"`.

### Paso 13: DI — `clients_module.dart`

- Registrar `RemoveClientOrderField` use case.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13

(Domain primero, luego Data, luego Presentation, finalmente i18n y DI.)

### Dependencias entre pasos

- Los pasos 1-4 (domain) son prerrequisito de 5-9 (data).
- Los pasos 5-9 (data) son prerrequisito de 10-11 (presentation).
- El paso 12 (i18n) depende de que el paso 11 ya no referencie la clave.
- El paso 13 (DI) depende del paso 4 (nuevo use case).

### Puntos delicados

- **`_savePendingChanges` en `dispose()`**: Se ejecuta al cerrar la página. Si
  se elimina `orderChanges` pero se deja alguna referencia residual a
  `_orderControllers`, habrá error en runtime. Revisar que se elimine
  completamente.
- **`_saveField` con `clearOrder`**: Este parámetro controla el envío de
  `{clientId: null}` como `orderChanges`. Eliminar ambos parámetros y la lógica
  de `orderChanges` en el cuerpo.
- **`sync_clients_from_fd.dart`**: Tiene `order: null` como parámetro named de
  `ClientModel`. Tras eliminar el campo del model, este parámetro dejará de
  compilar. Hay que quitarlo.
- **Ejecución de `removeFieldFromAll`**: Es una operación puntual. Se puede
  exponer desde el cubit y llamar una sola vez, o ejecutar como script admin. No
  debe ejecutarse automáticamente en cada inicio.

## 7) Estrategia de validación

### Verificación automática

- **Compilación:** `flutter analyze` sin errores ni warnings. Confirmar que no
  queda ninguna referencia a `order` en `lib/features/clients/`.
- **Grep de seguridad:** `grep -rn '\.order' lib/features/clients/` debe
  devolver 0 resultados.
- **Grep de orderChanges:** `grep -rn 'orderChanges' lib/features/clients/` debe
  devolver 0 resultados.
- **Tests existentes:** Ejecutar `flutter test test/features/clients/` — si
  existen tests, deben pasar. Si referencian `order`, actualizarlos.

### Validación manual

- Abrir la pantalla de clientes → confirmar que no aparece columna "Orden".
- Verificar que los clientes están ordenados alfabéticamente.
- Editar nombre, toggle activo, asignar/desasignar categoría → guardar →
  confirmar que se persiste sin errores.
- Ejecutar la limpieza Firestore → verificar en consola de Firebase que los
  documentos de `clients` ya no contienen el campo `order`.

### Escenarios a cubrir

| Escenario                | Verificación                               |
| ------------------------ | ------------------------------------------ |
| Carga de clientes        | Orden alfabético, sin columna Orden        |
| Stream reactivo          | Nuevos clientes se ordenan alfabéticamente |
| Guardado batch de nombre | No envía campo `order`                     |
| Guardado de categoría    | No envía campo `order`                     |
| Sync desde FD            | Crea clientes sin campo `order`            |
| Limpieza Firestore       | Campo `order` eliminado de todos los docs  |
| Colección con >500 docs  | Limpieza funciona en múltiples batches     |

### Tipo de pruebas recomendables

- Unit tests para `ClientsRepositoryImpl` (sort simplificado, `saveClientsBatch`
  sin `orderChanges`).
- Unit test para `removeFieldFromAll` del datasource (mockeando
  `FirebaseFirestore`).
- Widget test para `ClientsPage` confirmando ausencia de columna "Orden".

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                         | Probabilidad | Severidad                                                 |
| -------------------------------------------------------------- | ------------ | --------------------------------------------------------- |
| Referencia residual a `order` causa error de compilación       | Baja         | Baja (se detecta en compile time)                         |
| La limpieza Firestore falla parcialmente                       | Baja         | Baja (reintentar la operación; código ya ignora el campo) |
| Otro sistema externo consume `order` de la colección `clients` | Muy baja     | Media                                                     |

### Impacto potencial

- **En código:** Sustractivo; reduce complejidad. Sin impacto en otros features.
- **En datos Firestore:** Se elimina campo `order` de todos los documentos de
  `clients`. Irreversible sin backup.
- **En UX:** Se elimina una columna editable de la tabla de clientes. Interfaz
  más limpia.

### Mitigación

- Ejecutar la limpieza Firestore **después** de desplegar el código que ya no
  usa `order`, asegurando compatibilidad.
- Verificar con `flutter analyze` y grep que no quedan referencias.
- Si hay duda sobre consumidores externos, revisar las reglas de seguridad de
  Firestore y otros clientes de la colección.

### Plan de rollback

- **Código:** Revertir el commit con `git revert`. El campo `order` vuelve a
  leerse y mostrarse.
- **Datos Firestore:** Si la limpieza ya se ejecutó, los valores de `order` se
  habrán perdido. Para restaurar, se necesitaría un backup previo de Firestore o
  recalcular los valores de orden.
- **Recomendación:** No ejecutar la limpieza Firestore hasta confirmar que el
  cambio de código es estable en producción.

## 9) Suposiciones

- El campo `order` no es consumido por ningún otro sistema, Cloud Function, o
  cliente que acceda a la colección `clients` de Firestore.
- La colección `clients` tiene un número manejable de documentos (< miles), por
  lo que la operación de limpieza batch es viable sin paginación de queries.
- El método `removeFieldFromAll` será usado puntualmente (una sola vez) y no
  necesita un mecanismo de "ya ejecutado" persistente; el implementador puede
  decidir si ejecutarlo manualmente.

## 10) Preguntas abiertas

- **¿Cómo se expondrá la operación de limpieza Firestore al operador?**
  Opciones: (a) botón en settings/admin, (b) llamada manual desde consola, (c)
  script de Firebase Admin SDK. Esto queda a decisión del implementador.

## 11) Notas para implementación

- **Restricción:** No modificar nada en `lib/features/products/` — ese feature
  tiene su propio `order` completamente independiente.
- **Secuencia sugerida:** Implementar domain → data → presentation → i18n → DI.
  Compilar y testear tras cada capa para detectar errores incrementalmente.
- **Import de `FieldValue`:** Solo necesario en
  `client_firestore_data_source_impl.dart`, que ya importa
  `package:cloud_firestore/cloud_firestore.dart`.
- **`SyncClientsFromFd`:** No olvidar eliminar `order: null` de la creación de
  `ClientModel`. Aunque es un named parameter opcional, tras eliminar el campo
  del modelo, dejará de compilar.
- **Archivos generados de i18n:** Tras eliminar la clave del `.arb`, ejecutar
  `flutter gen-l10n` (o el build runner configurado) para regenerar
  `app_localizations.dart` y `app_localizations_es.dart`.
- **Estado: Listo para implementación**
