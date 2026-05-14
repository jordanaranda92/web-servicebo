# Functional Analysis: Migración de Categorías de Clientes de Google Sheets a Firestore

- **Fecha:** 2026-05-08
- **Identificador:** client-categories-firestore-migration
- **Estado:** Ready for technical analysis

## 1) Resumen

Migrar el almacenamiento de las Categorías de Clientes desde la pestaña
`categorias_clientes` del spreadsheet `configuracion` de Google Sheets a una
colección de Cloud Firestore en Firebase. El ID numérico secuencial actual
(`int`) será reemplazado por el ID auto-generado de Firestore (`String`). Todos
los puntos de la aplicación que referencian categorías de clientes (feature
`client_categories` y feature `clients`) deben adaptarse al nuevo origen de
datos y al nuevo tipo de identificador.

## 2) Contexto y objetivo

### Qué se solicita

Cambiar la fuente de datos de las Categorías de Clientes: dejar de leer/escribir
en Google Sheets y pasar a hacerlo en Cloud Firestore.

### Qué problema resuelve

- Google Sheets no es una base de datos adecuada para operaciones CRUD
  frecuentes: tiene limitaciones de cuota, latencia y concurrencia.
- Firestore ofrece consultas en tiempo real, mejor rendimiento, escalabilidad y
  consistencia para este tipo de datos de configuración.
- Se elimina la dependencia del spreadsheet `configuracion` para esta entidad,
  simplificando la arquitectura de datos.

### Qué resultado funcional se espera

- Las Categorías de Clientes se gestionan (crear, leer, actualizar,
  activar/desactivar, eliminar) contra Firestore con la misma funcionalidad que
  existe actualmente.
- La tabla de Clientes sigue mostrando el nombre de categoría resuelto
  correctamente, pero leyendo las categorías desde Firestore en lugar de Google
  Sheets.
- La experiencia de usuario en la pantalla de Categorías de Clientes y en la
  pantalla de Clientes no cambia funcionalmente (mismos campos, mismas
  acciones).

## 3) Alcance

### En alcance

- Migrar el CRUD completo de Categorías de Clientes (listar, crear, editar
  nombre, activar/desactivar, eliminar) a Firestore.
- Cambiar el tipo del identificador de categoría de `int` a `String` (ID
  auto-generado de Firestore).
- Adaptar la entidad `ClientCategory` al nuevo tipo de ID.
- Adaptar el repositorio `ClientCategoriesRepository` y su implementación para
  usar Firestore como datasource.
- Adaptar la resolución de nombre de categoría en la feature `clients`: donde
  actualmente se lee `categorias_clientes` de Google Sheets para construir el
  mapa `Map<int, String>`, se debe leer de Firestore y usar
  `Map<String, String>`.
- Adaptar el caso de uso `UpdateClientCategory` de la feature `clients` (que
  asigna categoría a un cliente) para trabajar con `String categoryId` en lugar
  de `int categoryId`.
- Adaptar la pestaña `clientes` del spreadsheet de Google Sheets: la columna
  "Categoría cliente" pasará a almacenar el ID de Firestore (`String`) en lugar
  del ID numérico.
- Adaptar la UI de la pantalla de Categorías de Clientes y la pantalla de
  Clientes para trabajar con el nuevo tipo de ID.
- Adaptar la inyección de dependencias.

### Fuera de alcance

- Migración automática de datos existentes de Google Sheets a Firestore (se
  asume migración manual o script independiente).
- Migración de otros datos del spreadsheet `configuracion` (pestaña `clientes`,
  `productos`, etc.) a Firestore.
- Cambios en la estructura de datos de la entidad `Client` más allá de adaptar
  el tipo de referencia a categoría.
- Implementación de listeners en tiempo real de Firestore (se mantendrá el
  patrón actual de carga bajo demanda).
- Reglas de seguridad de Firestore (se asume configuración independiente).

## 4) Actores implicados

| Actor             | Rol                                                                                                                    |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Usuario de la app | Gestiona categorías de clientes (CRUD) y asigna categorías a clientes                                                  |
| Cloud Firestore   | Nuevo almacén de datos para categorías de clientes                                                                     |
| Google Sheets     | Almacén actual (se deja de usar para categorías; sigue usándose para la pestaña `clientes` con el nuevo formato de ID) |

## 5) Requisitos funcionales

- **RF-01:** El sistema debe almacenar las categorías de clientes en una
  colección de Firestore con los campos: `name` (String), `isActive` (bool). El
  ID del documento será el generado automáticamente por Firestore.
- **RF-02:** El sistema debe permitir listar todas las categorías de clientes
  desde Firestore, mostrando ID, nombre y estado activo.
- **RF-03:** El sistema debe permitir crear una nueva categoría de cliente en
  Firestore con un nombre dado. El estado activo por defecto será `true`. El ID
  se generará automáticamente.
- **RF-04:** El sistema debe permitir editar el nombre de una categoría
  existente en Firestore, identificándola por su ID de documento.
- **RF-05:** El sistema debe permitir activar/desactivar una categoría en
  Firestore, identificándola por su ID de documento.
- **RF-06:** El sistema debe permitir eliminar una categoría de Firestore,
  identificándola por su ID de documento.
- **RF-07:** En la feature de Clientes, la resolución del nombre de categoría
  debe obtener las categorías desde Firestore (en lugar de la pestaña
  `categorias_clientes` del sheet) para construir el mapa de ID → nombre.
- **RF-08:** En la feature de Clientes, la asignación de categoría a un cliente
  debe escribir el ID de Firestore (String) en la columna "Categoría cliente" de
  la pestaña `clientes` del spreadsheet.
- **RF-09:** En la feature de Clientes, la lectura de la columna "Categoría
  cliente" de la pestaña `clientes` debe interpretar el valor como String (ID de
  Firestore) en lugar de int.
- **RF-10:** La pantalla de Categorías de Clientes debe funcionar igual que
  actualmente: listar, filtrar por nombre, crear, editar, activar/desactivar y
  eliminar categorías.

## 6) Criterios de aceptación

- **CA-01:** Al abrir la pantalla de Categorías de Clientes, se listan las
  categorías almacenadas en Firestore con nombre y estado activo.
- **CA-02:** Al crear una categoría, se persiste en Firestore con un ID
  auto-generado y aparece en la lista tras recargar.
- **CA-03:** Al editar el nombre de una categoría, el cambio se refleja en
  Firestore y en la lista de la pantalla.
- **CA-04:** Al activar/desactivar una categoría, el cambio se refleja en
  Firestore y en la lista.
- **CA-05:** Al eliminar una categoría, desaparece de Firestore y de la lista.
- **CA-06:** En la pantalla de Clientes, la columna "Categoría" muestra el
  nombre resuelto correctamente obteniendo las categorías desde Firestore.
- **CA-07:** Al asignar una categoría a un cliente, se escribe el ID de
  Firestore (String) en la columna correspondiente del spreadsheet `clientes`.
- **CA-08:** No se realiza ninguna lectura a la pestaña `categorias_clientes`
  del spreadsheet para operaciones de categorías; toda operación CRUD se ejecuta
  contra Firestore.
- **CA-09:** Si Firestore no está disponible, las operaciones de categorías
  devuelven un error controlado (Failure) sin bloquear el resto de la
  aplicación.
- **CA-10:** La app no pierde funcionalidad existente en la gestión de clientes
  más allá de la adaptación del tipo de ID de categoría.

## 7) Flujos y comportamiento esperado

### Flujo principal — Listar categorías

1. El usuario accede a la pantalla de Categorías de Clientes.
2. El sistema consulta Firestore para obtener todas las categorías.
3. Se muestra la lista con nombre, estado activo y las acciones disponibles.

### Flujo principal — Crear categoría

1. El usuario introduce un nombre para la nueva categoría.
2. El sistema crea un documento en Firestore con `name` y `isActive: true`.
3. Se recarga la lista mostrando la nueva categoría con su ID auto-generado.

### Flujo principal — Editar categoría

1. El usuario modifica el nombre de una categoría existente.
2. El sistema actualiza el campo `name` del documento en Firestore.
3. Se refleja el cambio en la lista.

### Flujo principal — Activar/desactivar categoría

1. El usuario cambia el estado activo de una categoría.
2. El sistema actualiza el campo `isActive` del documento en Firestore.
3. Se refleja el cambio en la lista.

### Flujo principal — Eliminar categoría

1. El usuario solicita eliminar una categoría.
2. El sistema elimina el documento de Firestore.
3. La categoría desaparece de la lista.

### Flujo principal — Resolución de categoría en Clientes

1. Al cargar la lista de clientes, el sistema lee las categorías desde Firestore
   (no desde Google Sheets).
2. Construye un mapa `Map<String, String>` (ID Firestore → nombre).
3. Cruza el `categoryId` (String) de cada fila del sheet `clientes` con el mapa
   para resolver el nombre de categoría.
4. Muestra el nombre en la columna "Categoría" de la tabla de clientes.

### Flujos alternativos

- **FA-01:** Si Firestore no está disponible al listar categorías → se muestra
  estado de error con opción de reintentar.
- **FA-02:** Si Firestore no está disponible al cargar clientes → la resolución
  de categorías falla parcialmente; se muestra el dato sin nombre de categoría
  (degradación funcional, como ya existe con Google Sheets).
- **FA-03:** Si un cliente tiene un `categoryId` en el sheet que no existe en
  Firestore (categoría eliminada o dato inconsistente) → se muestra vacío o un
  indicador de categoría desconocida.

### Estados especiales / excepciones

- **Estado vacío:** No existen categorías en Firestore → se muestra lista vacía
  con posibilidad de crear la primera.
- **Estado loading:** Mientras se consulta Firestore → se muestra indicador de
  carga (comportamiento actual mantenido).
- **Estado error:** Fallo de red o Firestore no disponible → se muestra error
  con opción de reintentar.
- **Firebase no inicializado:** Si Firebase no está disponible en el arranque →
  las operaciones de categorías devuelven error controlado.

## 8) Edge cases

- **EC-01:** Categoría eliminada que aún está referenciada por uno o más
  clientes en el sheet → la columna "Categoría" de esos clientes mostrará vacío
  o indicador de categoría no encontrada.
- **EC-02:** Dos usuarios crean categorías simultáneamente → Firestore gestiona
  la concurrencia; cada una obtiene un ID único auto-generado.
- **EC-03:** Categoría con nombre duplicado → no se restringe (comportamiento
  actual; no existe validación de unicidad de nombre).
- **EC-04:** Datos legacy en el sheet `clientes` con IDs numéricos antiguos tras
  la migración → no se resolverán contra Firestore (IDs incompatibles). Requiere
  migración de datos en el sheet.
- **EC-05:** Categoría con nombre vacío → la UI actual ya previene esto; se
  mantiene la validación existente.

## 9) Impacto funcional

### Módulos o procesos afectados

| Módulo                                           | Impacto                                                                                                                   |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| Feature `client_categories` (data layer)         | Reemplazar datasource de Google Sheets por Firestore                                                                      |
| Feature `client_categories` (domain layer)       | Cambiar tipo de ID de `int` a `String` en entidad, repositorio y use cases                                                |
| Feature `client_categories` (presentation layer) | Adaptar cubit, state y page al nuevo tipo de ID                                                                           |
| Feature `clients` (data layer)                   | Cambiar lectura de categorías de Google Sheets a Firestore; adaptar `categoryId` de `int` a `String` en DTO y repositorio |
| Feature `clients` (domain layer)                 | Adaptar `UpdateClientCategory` use case para `String categoryId`                                                          |
| Feature `clients` (presentation layer)           | Adaptar referencia a categorías con tipo `String`                                                                         |
| DI (`client_categories_module.dart`)             | Cambiar dependencias del repositorio                                                                                      |
| DI (`core_module.dart` o `clients_module.dart`)  | Registrar Firestore instance si no está registrada                                                                        |

### Impacto en usuario o negocio

- **Positivo:** Mayor fiabilidad y velocidad en la gestión de categorías.
- **Neutro:** La experiencia de usuario no cambia visualmente.
- **Riesgo:** Los datos existentes en Google Sheets deben migrarse a Firestore
  antes de desplegar (ver EC-04).

### Impacto en experiencia de usuario

- Sin cambios visibles. Las pantallas mantienen la misma estructura, campos y
  acciones.

## 10) Suposiciones

- **S-01:** Firebase ya está inicializado correctamente en la aplicación (existe
  `firebase_core` y `cloud_firestore` en `pubspec.yaml`; el flag
  `firebaseAvailable` se gestiona en el arranque).
- **S-02:** La colección de Firestore se llamará `client_categories` (confirmado
  por el usuario).
- **S-03:** La migración de datos existentes (2 categorías: "Decathlon" y "Otras
  tiendas") se realizará manualmente o mediante script independiente antes de
  desplegar la nueva versión.
- **S-04:** Los valores de la columna "Categoría cliente" en la pestaña
  `clientes` del spreadsheet con IDs numéricos no serán migrados
  automáticamente. Se acepta pérdida temporal de la asignación de categoría en
  clientes existentes hasta que se actualicen manualmente.
- **S-05:** No se requiere soporte offline para Firestore en esta iteración (se
  mantiene el patrón actual de carga bajo demanda con manejo de errores de red).
- **S-06:** No se implementan reglas de seguridad específicas de Firestore como
  parte de este cambio.

## 11) Preguntas abiertas

Todas las preguntas han sido resueltas (ver Decisiones tomadas).

### Decisiones tomadas

- **PA-01 → Corte limpio.** No se mantiene compatibilidad temporal con Google
  Sheets. Se deja de leer/escribir categorías en el sheet en cuanto se
  despliegue la nueva versión.
- **PA-02 → Se acepta pérdida temporal.** Los clientes existentes que tengan un
  ID numérico en la columna "Categoría cliente" del sheet perderán temporalmente
  la categoría asignada hasta que se actualicen manualmente los IDs al formato
  de Firestore.
- **PA-03 → Colección `client_categories`.** La colección de Firestore se
  llamará `client_categories`.

## 12) Notas para análisis técnico

- La entidad `ClientCategory` (actualmente en
  `lib/features/clients/domain/entities/client_category.dart`) tiene
  `final int id` que debe cambiar a `final String id`.
- El `ClientCategorySheetDto` (parseo de Google Sheets) dejará de usarse para el
  CRUD de categorías; será reemplazado por un DTO/modelo de Firestore.
- El `ClientCategoriesRepositoryImpl` actualmente depende de
  `SettingsRepository`, `GoogleSheetsDataSource` y
  `GoogleDriveRemoteDataSource`. Tras la migración, solo necesitará acceso a
  `FirebaseFirestore` (o un datasource abstracto de Firestore).
- En `ClientsRepositoryImpl`, el método `_loadSheetData()` lee
  `categorias_clientes` del sheet para construir
  `categoryMap: Map<int, String>`. Esto debe cambiar a una lectura desde
  Firestore con `Map<String, String>`.
- En `ClientsRepositoryImpl`, los métodos `updateClientCategory()` y
  `saveClientsBatch()` escriben un `int categoryId` en el sheet. Deben adaptarse
  a `String`.
- En `ClientSheetDto`, el campo `categoryId` es `int?`; debe cambiar a
  `String?`.
- En la pantalla de clientes (`clients_page.dart`), los pending changes de
  categoría (`_pendingCategoryNames`, `categoryChanges`) deben adaptarse al
  nuevo tipo.
- Los use cases de `client_categories` (`AddClientCategory`,
  `UpdateClientCategory`, `ToggleClientCategory`, `DeleteClientCategory`) usan
  `int id` en sus params; deben cambiar a `String`.
- El `UpdateClientCategory` de la feature `clients` usa `int categoryId`; debe
  cambiar a `String`.
- El paquete `cloud_firestore` ya está en `pubspec.yaml` pero no hay ningún
  datasource de Firestore implementado aún. Se necesitará crear la
  infraestructura base.
- Considerar registrar `FirebaseFirestore.instance` en `core_module.dart` de
  forma similar a como se registra `FirebaseDatabase`.
- **Estado: Listo para análisis técnico**
