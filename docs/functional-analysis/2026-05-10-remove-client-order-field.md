# Functional Analysis: Eliminar campo order de clientes

- **Fecha:** 2026-05-10
- **Identificador:** remove-client-order-field
- **Estado:** Ready for technical analysis

## 1) Resumen

Eliminar el campo `order` (posición/orden) de la entidad `Client` y toda la
funcionalidad asociada: columna en la tabla de clientes, controladores de texto,
lógica de persistencia, ordenación por `order` y parámetro `orderChanges` del
batch save. Además, eliminar el campo `order` de todos los documentos existentes
en la colección `clients` de Firestore.

## 2) Contexto y objetivo

- **Qué se solicita:** Eliminar completamente el campo `order` del modelo de
  datos de cliente, de la interfaz de usuario y de toda la lógica de negocio que
  lo utilice.
- **Qué problema resuelve:** El campo `order` ya no es necesario para la gestión
  de clientes. Su presencia añade complejidad innecesaria a la UI (columna
  editable), al modelo de datos y a la lógica de persistencia.
- **Resultado funcional esperado:** La pantalla de clientes deja de mostrar la
  columna "Orden". Los clientes se ordenan exclusivamente de forma alfabética
  por nombre. El campo desaparece de entidad, modelo, repositorio, caso de uso,
  cubit y de los documentos de Firestore.

## 3) Alcance

### En alcance

- Entidad `Client` (`domain/entities/client.dart`): eliminar campo `order`,
  actualizar `copyWith`, `props`
- Modelo `ClientModel` (`data/models/client_model.dart`): eliminar campo
  `order`, actualizar `fromFirestore`, `toMap`, `toEntity`
- Repositorio abstracto `ClientsRepository`: eliminar parámetro `orderChanges`
  de `saveClientsBatch`
- Repositorio concreto `ClientsRepositoryImpl`: eliminar parámetro
  `orderChanges`, eliminar lógica de ordenación por `order` (dejar solo orden
  alfabético por nombre)
- Caso de uso `SaveClientsBatch` y `SaveClientsBatchParams`: eliminar
  `orderChanges`
- Cubit `ClientsCubit.saveBatchChanges`: eliminar parámetro `orderChanges`
- Página `ClientsPage`:
  - Eliminar el map `_orderControllers` y su ciclo de vida (dispose, init)
  - Eliminar la columna "Orden" de la cabecera de la tabla
  - Eliminar el widget `TextField` de orden en cada fila
  - Eliminar parámetros `order` y `clearOrder` de `_saveField`
  - Eliminar la recolección de `orderChanges` en `_savePendingChanges`
- Cadena de i18n: la clave `clientsColumnOrderPosition` queda sin uso (puede
  eliminarse del `.arb`)
- **Limpieza Firestore:** Ejecutar una operación batch que elimine el campo
  `order` de todos los documentos de la colección `clients` usando
  `FieldValue.delete()`

### Fuera de alcance

- **Campo `order` de productos:** El feature `products` tiene su propio campo
  `order` con lógica independiente; no se modifica.
- **Reordenación manual futura:** Si en el futuro se necesita reordenar clientes
  de otra forma, será un requisito nuevo.
- **Tests:** Si existen tests que referencien `order` en clientes, deben
  actualizarse, pero la creación de tests nuevos no está en alcance de este
  análisis.

## 4) Actores implicados

- **Usuario final (operador/administrador):** Deja de ver y editar la columna
  "Orden" en la pantalla de gestión de clientes.

## 5) Requisitos funcionales

- **RF-01:** La entidad `Client` no debe contener el campo `order`.
- **RF-02:** El modelo de datos `ClientModel` no debe leer ni escribir el campo
  `order` de/a Firestore.
- **RF-03:** La pantalla de clientes no debe mostrar la columna "Orden" ni
  ningún control para editar la posición de un cliente.
- **RF-04:** La lógica de guardado batch (`saveClientsBatch`) no debe aceptar ni
  procesar `orderChanges` para clientes.
- **RF-05:** El listado de clientes debe ordenarse exclusivamente de forma
  alfabética (case-insensitive) por nombre.
- **RF-06:** El guardado individual de campos (`_saveField`) no debe aceptar
  parámetros `order` ni `clearOrder`.
- **RF-07:** El campo `order` debe eliminarse de todos los documentos existentes
  en la colección `clients` de Firestore mediante una operación de limpieza
  (batch con `FieldValue.delete()`).

## 6) Criterios de aceptación

- **CA-01:** La pantalla de clientes no muestra la columna "Orden" en la
  cabecera ni en las filas.
- **CA-02:** Los clientes se muestran ordenados alfabéticamente por nombre en
  todos los flujos (carga inicial y stream en tiempo real).
- **CA-03:** Al guardar cambios en un cliente (nombre, activo, categoría), no se
  envía ningún campo `order` a Firestore.
- **CA-04:** El código compila sin errores ni warnings relacionados con el campo
  `order` en el feature de clientes.
- **CA-05:** Tras ejecutar la limpieza, ningún documento de la colección
  `clients` en Firestore contiene el campo `order`.
- **CA-06:** La operación de limpieza de Firestore se ejecuta sin errores y
  respeta los límites de batch de Firestore (máximo 500 operaciones por batch).

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario abre la pantalla de clientes.
2. Se carga la lista de clientes desde Firestore.
3. La tabla muestra columnas: Nombre, Nombre FD, Activo, Categoría. **No aparece
   columna Orden.**
4. Los clientes aparecen ordenados alfabéticamente por nombre
   (case-insensitive).
5. El usuario puede editar nombre, toggle activo y categoría como antes.
6. Al perder foco o al cerrar la página, se persisten los cambios pendientes
   (solo nombre, sin `orderChanges`).

### Flujo de limpieza Firestore

1. Se ejecuta una operación (puntual o al iniciar la app una sola vez) que lee
   todos los documentos de la colección `clients`.
2. Para cada documento que contenga el campo `order`, se añade a un batch un
   `update` con `{'order': FieldValue.delete()}`.
3. Se respetan los límites de Firestore: si hay más de 500 documentos, se
   dividen en múltiples batches.
4. Se confirma la eliminación exitosa.

### Flujos alternativos

- **Colección vacía o sin documentos con `order`:** La operación de limpieza
  termina sin ejecutar ningún batch. Sin error.

### Estados especiales / excepciones

- **Estado vacío:** Sin cambios (ya gestionado).
- **Estado loading:** Sin cambios.
- **Estado error:** Sin cambios.

## 8) Edge cases

- **EC-01:** La colección `clients` tiene más de 500 documentos → la limpieza se
  ejecuta en múltiples batches de máximo 500 operaciones.
- **EC-02:** Dos clientes con el mismo nombre → se ordenan de forma estable (el
  orden entre duplicados es determinista pero no especificado).
- **EC-03:** `_savePendingChanges` se llama al dispose sin cambios pendientes →
  no dispara guardado (comportamiento actual, no cambia).

## 9) Impacto funcional

- **Módulos afectados:** Solo el feature `clients` (entidad, modelo,
  repositorio, caso de uso, cubit, página). El feature `products` y
  `orders_today` no se ven afectados.
- **Impacto en usuario:** La columna "Orden" desaparece de la tabla de clientes.
  Los clientes pasan a ordenarse siempre alfabéticamente.
- **Impacto en experiencia de usuario:** Simplificación de la interfaz; se
  reduce un campo editable que ya no aporta valor.
- **Impacto en datos:** Se elimina el campo `order` de todos los documentos de
  la colección `clients` en Firestore. La operación es destructiva para ese
  campo pero no afecta al resto de campos del documento.

## 10) Suposiciones

- El campo `order` de clientes no es consumido por ningún otro sistema externo o
  feature fuera del código de la aplicación Flutter.
- La eliminación del campo `order` en Firestore es segura y no afecta a otros
  sistemas que consuman esa colección.
- El orden alfabético por nombre es suficiente como criterio de ordenación tras
  eliminar `order`.

## 11) Preguntas abiertas

- Ninguna. El alcance es claro y el impacto está acotado al feature de clientes.

## 12) Notas para análisis técnico

- **Archivos a modificar (7 archivos Dart + 1 ARB):**
  - `lib/features/clients/domain/entities/client.dart`
  - `lib/features/clients/data/models/client_model.dart`
  - `lib/features/clients/domain/repositories/clients_repository.dart`
  - `lib/features/clients/data/repositories/clients_repository_impl.dart`
  - `lib/features/clients/domain/usecases/save_clients_batch.dart`
  - `lib/features/clients/presentation/bloc/clients_cubit.dart`
  - `lib/features/clients/presentation/pages/clients_page.dart`
  - `lib/app/localization/l10n/app_es.arb` (eliminar clave
    `clientsColumnOrderPosition`)
- **Limpieza Firestore:** Implementar una operación (script, use case de
  migración, o función puntual) que recorra todos los documentos de `clients` y
  ejecute `FieldValue.delete()` sobre el campo `order`. Respetar el límite de
  500 operaciones por `WriteBatch`.
- El datasource `ClientFirestoreDataSourceImpl` ya dispone de `batchUpdate` que
  utiliza `WriteBatch`; la limpieza puede apoyarse en un patrón similar pasando
  `{'order': FieldValue.delete()}` para cada documento.
- La ordenación en `clients_repository_impl.dart` se usa en dos sitios
  (`getClients` y `watchClients`); ambos deben simplificarse a solo
  `a.name.toLowerCase().compareTo(b.name.toLowerCase())`.
- El `_saveField` de `clients_page.dart` recibe `order` y `clearOrder` que deben
  eliminarse.
- El map `_orderControllers` y su dispose deben eliminarse de la página.
- Verificar que no haya tests en `test/features/clients/` que referencien
  `order` (actualmente no se encontraron).
- **Estado: Listo para análisis técnico**
