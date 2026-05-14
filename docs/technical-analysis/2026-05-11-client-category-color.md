# Technical Analysis: Color en categorías de cliente

- **Fecha:** 2026-05-11
- **Identificador:** client-category-color
- **Fuente:** docs/functional-analysis/2026-05-11-client-category-color.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Añadir campo `color` (`String?`, hex) a la entidad `ClientCategory` y
  propagarlo a través de todas las capas (data source → repositorio → use cases
  → cubit → UI).
- Extender la entidad `Client` con un campo `categoryColor` resuelto en el
  repositorio de clientes (patrón ya existente con `categoryName`).
- Modificar los diálogos de crear/editar categoría para incluir un selector de
  10 colores predefinidos con botón "Quitar color".
- Sustituir el color fijo `colorScheme.primary` del badge de categoría por el
  color de la categoría (con fallback).
- Áreas impactadas: `client_categories` (todas las capas) y `clients` (entidad,
  modelo, repositorio, UI).
- Riesgo general estimado: **bajo**. Cambio aditivo, sin reestructuración,
  compatible hacia atrás con datos existentes.

## 2) Contexto técnico observado

- **Arquitectura:** Clean Architecture feature-first con BLoC/Cubit, GetIt,
  fpdart.
- **Módulos relevantes:**
  - `lib/features/client_categories/` — gestión CRUD de categorías.
  - `lib/features/clients/` — listado, detalle y edición de clientes.
- **Entidad `ClientCategory`:** solo `id` y `name`. Definida en
  `lib/features/clients/domain/entities/client_category.dart` (compartida).
- **Entidad `Client`:** tiene `categoryName` (String?) resuelto en runtime por
  `ClientsRepositoryImpl` a partir de un mapa `id → name`.
- **Data source Firestore:** `ClientCategoryFirestoreDataSourceImpl` lee/escribe
  solo `name`. Métodos `add` y `update` reciben `{required String name}`.
- **Repository abstract:** `ClientCategoriesRepository` — métodos
  `addCategory({required String name})` y
  `updateCategory({required String id, required String name})`.
- **Use cases:** `AddClientCategory` con `AddClientCategoryParams(name)`,
  `UpdateClientCategory` con `UpdateClientCategoryParams(id, name)`.
- **Cubit:** `ClientCategoriesCubit` — métodos `addCategory(String name)` y
  `updateCategory(String id, String name)`.
- **UI badges:** En `clients_page.dart` (~línea 520) y `client_detail_page.dart`
  (~línea 110), el badge usa `colorScheme.primary` como fondo fijo y
  `colorScheme.onPrimary` como color de texto.
- **No hay dependencias externas requeridas.** Flutter provee `Color`,
  `Color.computeLuminance()` nativo.

## 3) Objetivo técnico

- Añadir persistencia, transporte y visualización del campo `color` sin romper
  compatibilidad con documentos Firestore existentes (que no tienen el campo).
- Garantizar que el patrón de resolución `id → color` siga el mismo mecanismo ya
  probado con `id → name`.
- Proporcionar un widget de selección de color reutilizable y desacoplado.
- Calcular contraste de texto automáticamente para legibilidad del badge.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Cambio aditivo en todas las capas, siguiendo el patrón exacto de `name`. El
campo `color` es nullable; los documentos existentes sin el campo se interpretan
como `null` (fallback a `colorScheme.primary`).

### Componentes / módulos / servicios afectados

1. **Entidad `ClientCategory`** — añadir `String? color`.
2. **Data source abstract** (`ClientCategoryFirestoreDataSource`) — añadir
   `color` a `add` y `update`.
3. **Data source impl** (`ClientCategoryFirestoreDataSourceImpl`) — leer y
   escribir `color` de/a Firestore.
4. **Repository abstract** (`ClientCategoriesRepository`) — añadir `color` a
   `addCategory` y `updateCategory`.
5. **Repository impl** (`ClientCategoriesRepositoryImpl`) — pasar `color` al
   data source.
6. **Use case `AddClientCategory`** — añadir `color` a
   `AddClientCategoryParams`.
7. **Use case `UpdateClientCategory`** — añadir `color` a
   `UpdateClientCategoryParams`.
8. **Cubit `ClientCategoriesCubit`** — añadir `color` a `addCategory()` y
   `updateCategory()`.
9. **Entidad `Client`** — añadir `String? categoryColor`.
10. **Modelo `ClientModel`** — añadir `categoryColor` a `toEntity()`.
11. **`ClientsRepositoryImpl`** — resolver `categoryColor` del mapa `id → color`
    (en `getClients` y `watchClients`).
12. **UI tabla categorías** (`client_categories_page.dart`) — columna "Color" +
    selector en diálogos.
13. **UI tabla clientes** (`clients_page.dart`) — badge con color dinámico.
14. **UI detalle cliente** (`client_detail_page.dart`) — badge con color
    dinámico.
15. **Constantes de colores predefinidos** — lista de 10 colores hex.
16. **i18n** — nuevas claves de traducción.

### Contratos e interfaces

**`ClientCategory` (entidad):**

```
ClientCategory({required String id, required String name, String? color})
```

**`ClientCategoryFirestoreDataSource` (abstract):**

```
Future<void> add({required String name, String? color});
Future<void> update({required String id, required String name, String? color});
```

**`ClientCategoriesRepository` (abstract):**

```
Future<Either<Failure, Unit>> addCategory({required String name, String? color});
Future<Either<Failure, Unit>> updateCategory({required String id, required String name, String? color});
```

**`AddClientCategoryParams`:**

```
AddClientCategoryParams({required String name, this.color})
```

**`UpdateClientCategoryParams`:**

```
UpdateClientCategoryParams({required String id, required String name, this.color})
```

**`ClientCategoriesCubit`:**

```
Future<bool> addCategory(String name, {String? color})
Future<bool> updateCategory(String id, String name, {String? color})
```

**`Client` (entidad):**

```
Client(..., String? categoryColor)
```

**`ClientModel.toEntity`:**

```
Client toEntity({String? categoryName, String? categoryColor})
```

### Flujo de datos o de control

1. **Escritura:** UI (diálogo) → Cubit → UseCase → Repository → DataSource →
   Firestore (`{name, color}`).
2. **Lectura categorías:** Firestore snapshot → DataSource (parsea `name` +
   `color`) → `ClientCategory` con color → Repository → Cubit → UI tabla
   categorías.
3. **Lectura clientes con color:** Firestore snapshots (`clients` +
   `client_categories`) → `ClientsRepositoryImpl` construye mapas `id→name` e
   `id→color` → `ClientModel.toEntity(categoryName, categoryColor)` → `Client`
   con `categoryColor` → Cubit → UI (badges).

### Gestión de errores y validaciones

- **Parseo de color hex malformado (EC-04):** Si el valor de `color` en
  Firestore no tiene formato válido, tratarlo como `null` en la UI (fallback).
  La validación se hace al renderizar, no en el modelo (el campo es simplemente
  `String?`).
- **Campo `color` ausente en Firestore:** Compatible por defecto;
  `data['color'] as String?` devuelve `null`.
- **No se requiere validación de formato al guardar** porque el selector solo
  permite elegir entre 10 valores predefinidos conocidos o `null`.

### Consideraciones de compatibilidad o migración

- **Sin migración requerida.** Los documentos Firestore existentes sin campo
  `color` se leen como `color: null`.
- **Retrocompatibilidad total.** El comportamiento visual no cambia para
  categorías sin color (fallback a `colorScheme.primary`).
- **No hay reglas de seguridad de Firestore que validar** (el campo `color` es
  un string más en el documento, sin restricciones de schema).

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                                          | Propósito                                                                                           |
| -------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Constantes de paleta predefinida (en `lib/features/client_categories/presentation/` o `lib/core/`) | Lista de 10 colores hex predefinidos para el selector                                               |
| Utilidad de contraste de texto (en `lib/core/` o inline)                                           | Función para calcular si el texto debe ser blanco o negro sobre un color dado, basada en luminancia |

### Artefactos a modificar

| Artefacto                                                                                         | Cambio esperado                                                                                                               |
| ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/clients/domain/entities/client_category.dart`                                       | Añadir campo `String? color` al constructor y `props`                                                                         |
| `lib/features/client_categories/data/datasources/client_category_firestore_data_source.dart`      | Añadir `String? color` a firmas de `add` y `update`                                                                           |
| `lib/features/client_categories/data/datasources/client_category_firestore_data_source_impl.dart` | Leer `color` de Firestore en `getAll`/`watchAll`; escribir `color` en `add`/`update`                                          |
| `lib/features/client_categories/domain/repositories/client_categories_repository.dart`            | Añadir `String? color` a `addCategory` y `updateCategory`                                                                     |
| `lib/features/client_categories/data/repositories/client_categories_repository_impl.dart`         | Pasar `color` a data source en `addCategory` y `updateCategory`                                                               |
| `lib/features/client_categories/domain/usecases/add_client_category.dart`                         | Añadir `String? color` a `AddClientCategoryParams` y pasarlo al repositorio                                                   |
| `lib/features/client_categories/domain/usecases/update_client_category.dart`                      | Añadir `String? color` a `UpdateClientCategoryParams` y pasarlo al repositorio                                                |
| `lib/features/client_categories/presentation/bloc/client_categories_cubit.dart`                   | Añadir `String? color` a `addCategory` y `updateCategory`                                                                     |
| `lib/features/clients/domain/entities/client.dart`                                                | Añadir campo `String? categoryColor` al constructor, `copyWith` y `props`                                                     |
| `lib/features/clients/data/models/client_model.dart`                                              | Añadir `String? categoryColor` a `toEntity()`                                                                                 |
| `lib/features/clients/data/repositories/clients_repository_impl.dart`                             | Construir mapa `id→color` y pasarlo a `toEntity` en `getClients` y `watchClients`                                             |
| `lib/features/client_categories/presentation/pages/client_categories_page.dart`                   | Añadir columna "Color" a la tabla; integrar selector de color en diálogos de añadir y editar; botón "Quitar color" en edición |
| `lib/features/clients/presentation/pages/clients_page.dart`                                       | Usar `client.categoryColor` como fondo del badge (con fallback y contraste)                                                   |
| `lib/features/clients/presentation/pages/client_detail_page.dart`                                 | Usar `client.categoryColor` como fondo del badge (con fallback y contraste)                                                   |
| Archivos i18n (`*.arb`)                                                                           | Añadir claves para "Color", "Quitar color", label del selector                                                                |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo |
| --------- | ------ |
| Ninguno   | —      |

## 6) Estrategia de implementación

1. **Paso 1 — Entidad `ClientCategory`:** Añadir `String? color` con `props`.
2. **Paso 2 — Capa data (data source):** Actualizar abstract e impl para
   leer/escribir `color`.
3. **Paso 3 — Capa domain (repositorio abstract + use cases):** Añadir `color` a
   firmas y params.
4. **Paso 4 — Capa data (repositorio impl):** Pasar `color` al data source.
5. **Paso 5 — Cubit `ClientCategoriesCubit`:** Añadir `color` a métodos
   públicos.
6. **Paso 6 — Entidad `Client` + `ClientModel`:** Añadir `categoryColor`.
7. **Paso 7 — `ClientsRepositoryImpl`:** Construir mapa `id→color` y resolver en
   `toEntity`.
8. **Paso 8 — Constantes de paleta y utilidad de contraste.**
9. **Paso 9 — i18n:** Añadir claves de traducción.
10. **Paso 10 — UI tabla de categorías:** Columna "Color" + selector en
    diálogos + botón "Quitar color".
11. **Paso 11 — UI tabla de clientes y detalle:** Badge con color dinámico y
    contraste.
12. **Paso 12 — Tests unitarios:** Entidad, data source, repositorio, use cases,
    cubit.

### Orden recomendado

Pasos 1–5 (capa `client_categories` bottom-up) → Pasos 6–7 (capa `clients`
entity+repo) → Paso 8 (utilidades) → Paso 9 (i18n) → Pasos 10–11 (UI) → Paso 12
(tests).

### Dependencias entre pasos

- Los pasos 2–5 dependen del paso 1 (entidad actualizada).
- Los pasos 6–7 pueden ejecutarse en paralelo con 2–5 pero lógicamente van
  después.
- Los pasos 10–11 dependen de todos los anteriores.
- El paso 12 puede iniciarse en paralelo con los pasos de UI.

### Puntos delicados

- **`ClientModel.toEntity`:** Actualmente recibe solo `categoryName`. Debe
  añadir `categoryColor` como parámetro nombrado opcional para no romper la
  firma existente.
- **Mapa `id→color` en `ClientsRepositoryImpl`:** Debe construirse junto al
  `id→name` existente, tanto en `getClients()` como en `watchClients()`.
  Atención a mantener la sincronización en el stream de `watchClients`.
- **Cálculo de contraste en la UI:** Usar `Color.computeLuminance()` > 0.5 para
  decidir texto oscuro vs claro. Importante parsear el hex de forma segura (con
  fallback).
- **Botón "Quitar color":** Solo visible en el diálogo de edición cuando la
  categoría ya tiene color asignado, o siempre visible pero deshabilitado si no
  hay color seleccionado.

## 7) Estrategia de validación

### Verificación automática (tests unitarios)

- **`ClientCategory`:** Constructor con y sin `color`; `props` incluye `color`.
- **`ClientCategoryFirestoreDataSourceImpl`:** `getAll`/`watchAll` parsea
  `color`; `add`/`update` envía `color` a Firestore.
- **`ClientCategoriesRepositoryImpl`:** `addCategory`/`updateCategory` pasa
  `color` al data source.
- **`AddClientCategory` / `UpdateClientCategory`:** Params incluyen `color`; se
  pasa al repositorio.
- **`ClientCategoriesCubit`:** `addCategory`/`updateCategory` pasa `color` al
  use case.
- **`Client` entidad:** Campo `categoryColor` en constructor, `copyWith`,
  `props`.
- **`ClientModel.toEntity`:** Recibe y propaga `categoryColor`.
- **`ClientsRepositoryImpl`:** Mapa `id→color` se construye y resuelve en
  `getClients` y `watchClients`.

### Verificación manual

- Crear una categoría con color → verificar que el badge en tabla de clientes y
  detalle muestra el color elegido.
- Editar una categoría → cambiar color → verificar que los badges se actualizan
  en tiempo real (stream).
- Editar una categoría → pulsar "Quitar color" → verificar que el badge vuelve
  al fallback `primary`.
- Verificar contraste de texto en badges con colores claros y oscuros.
- Verificar que categorías existentes (sin campo `color` en Firestore) siguen
  mostrando el badge con `colorScheme.primary`.

### Escenarios de edge case

- Documento Firestore con `color` malformado (ej. `"xyz"`) → badge usa fallback
  sin error.
- Dos categorías con el mismo color → ambas muestran el badge correctamente.
- Eliminar categoría con color → los clientes pierden badge (comportamiento
  existente, sin regresión).

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                         | Probabilidad | Impacto             |
| ------------------------------------------------------------------------------ | ------------ | ------------------- |
| Regresión en resolución de `categoryName` al modificar `ClientsRepositoryImpl` | Baja         | Medio               |
| Color hex malformado en Firestore rompe la UI                                  | Baja         | Bajo (con fallback) |
| Contraste insuficiente en algún color predefinido                              | Baja         | Bajo (visual)       |

### Impacto potencial

- Si la resolución del mapa `id→color` tiene un bug, los badges podrían perder
  color o mostrar el incorrecto. No afecta a datos ni a funcionalidad CRUD.

### Mitigación

- Tests unitarios en `ClientsRepositoryImpl` para `getClients` y `watchClients`
  verificando que `categoryColor` se resuelve correctamente.
- Parseo defensivo del hex con try/catch y fallback.
- Paleta predefinida con colores de contraste verificado.

### Plan de rollback

- El campo `color` en Firestore es aditivo y no afecta a ningún otro sistema. Si
  se necesita revertir, basta con revertir el código; los documentos con `color`
  no causan problemas (se ignoran).

## 9) Suposiciones

- Los 10 colores predefinidos serán constantes en código. Propuesta de paleta
  (Material Design-inspired, buen contraste):
  ```
  #E53935  (rojo)
  #FB8C00  (naranja)
  #FDD835  (amarillo)
  #43A047  (verde)
  #00ACC1  (cian)
  #1E88E5  (azul)
  #5E35B1  (morado)
  #D81B60  (rosa)
  #6D4C41  (marrón)
  #546E7A  (gris azulado)
  ```
- El formato hex en Firestore será de 7 caracteres: `#RRGGBB`.
- El cálculo de contraste usará `Color.computeLuminance()` con umbral 0.5.
- No se añade canal alfa; los badges serán siempre opacos.

## 10) Preguntas abiertas

_Ninguna. Todas las preguntas funcionales fueron resueltas._

## 11) Notas para implementación

- **Respetar firmas backwards-compatible:** El parámetro `color` debe ser
  opcional (`String? color`) en todas las capas para no romper código que llame
  sin él.
- **Parseo seguro de hex:** Crear una función helper tipo
  `Color? tryParseHex(String? hex)` que devuelva `null` si el formato no es
  válido. Se puede ubicar en `lib/core/utils/` o como función privada en el
  widget.
- **Contraste de texto:** Función `Color contrastTextColor(Color bg)` que
  devuelva `Colors.white` o `Colors.black` según luminancia. Puede ir junto al
  helper de parseo.
- **Selector de color en diálogos:** Usar un `Wrap` con 10 widgets circulares
  (`GestureDetector` + `Container` circular). El color seleccionado se indica
  con un borde o check. En edición, añadir debajo un `TextButton` "Quitar color"
  que resetee la selección a `null`.
- **Columna "Color" en tabla de categorías:** Insertar entre la columna "Nombre"
  (flex: 3) y "Acciones" (width: 80). Ancho fijo (ej. 60) con un `Container`
  circular de 20x20 relleno del color. Si `color` es `null`, mostrar un
  `Container` con borde punteado o un icono vacío.
- **No cambiar la firma del delete** — no necesita `color`.
- **Secuencia sugerida:** Implementar bottom-up desde la entidad hasta la UI.
  Compilar y verificar en cada capa antes de avanzar.
- **Estado: Listo para implementación**
