# Technical Analysis: Historial de pedidos

- **Fecha:** 2026-05-06
- **Identificador:** orders-history
- **Fuente:** docs/functional-analysis/2026-05-06-orders-history.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- **Enfoque:** Implementar la feature `orders_history` siguiendo Clean
  Architecture feature-first (domain → data → presentation), reutilizando el
  `ExcelLocalDataSource` y las entidades `OrderSheet`/`OrderRow` existentes en
  `orders_today`. Se creará un nuevo repositorio, use cases, BLoC y UI propios
  de la feature.
- **Áreas impactadas:** Feature `orders_history` (nueva implementación
  completa), módulo DI (`injection.dart`), strings i18n (`app_es.arb`). Se crea
  un widget de tabla read-only en `orders_history` inspirado en `OrdersTable` de
  `orders_today`.
- **Riesgo general estimado:** Bajo. No se modifica lógica existente; se
  reutiliza infraestructura probada (datasource Excel, entidades) y se sigue un
  patrón ya establecido en `orders_today`.

## 2) Contexto técnico observado

### Arquitectura detectada

- **Clean Architecture feature-first** con BLoC, GetIt (DI) y fpdart
  (`Either<Failure, T>`).
- Estructura por feature: `data/datasources/local/`, `data/repositories/`,
  `domain/entities/`, `domain/repositories/`, `domain/usecases/`,
  `presentation/bloc/`, `presentation/pages/`, `presentation/widgets/`.

### Módulos y capas relevantes

- **`orders_today`**: Feature completa con datasource Excel
  (`ExcelLocalDataSource` / `ExcelLocalDataSourceImpl`), repositorio, use cases,
  BLoC y UI editable. Es el modelo de referencia.
- **`orders_history`**: Actualmente solo contiene
  `presentation/pages/orders_history_page.dart` con un placeholder.
- **`settings`**: Provee `SettingsRepository.getWorkFolder()` para obtener la
  carpeta de trabajo configurada.
- **`home`**: `SideMenuCubit`/`SideMenuState` controla la navegación lateral.
  `OrdersHistoryPage` está en index 2 del `IndexedStack`.
- **`core/`**: Contiene `UseCase<T, Params>`, `Failure`, excepciones
  (`ParsingException`, `FileAccessException`, `NotFoundException`), `PageHeader`
  widget, y `AppLogger`.

### Restricciones relevantes

- `ExcelLocalDataSource` está registrado como `LazySingleton` en
  `orders_today_module.dart`. Se reutiliza directamente via GetIt (ya está
  disponible globalmente).
- Las entidades `OrderSheet` y `OrderRow` están en
  `orders_today/domain/entities/` — se referenciarán desde `orders_history` como
  dependencia cross-feature aceptable dado que son entidades de dominio
  compartido.
- La convención de nombres de archivo histórico es
  `{workFolder}/historico/{YYYY-MM-DD}.xlsx` (observado en
  `OrdersTodayRepositoryImpl._buildHistoricoPath`).
- El proyecto usa i18n con ARB files; todas las cadenas visibles van en
  `app_es.arb`.
- Design tokens en `theme_constants.dart` (`AppSpacing`, `AppRadii`,
  `AppIconSizes`).

### Dependencias o integraciones relacionadas

- `ExcelLocalDataSource` (interface + impl): operaciones `readExcel(filePath)`,
  `fileExists(filePath)`.
- `SettingsRepository.getWorkFolder()` → `WorkFolderConfig`.
- `SideMenuCubit` → detectar navegación a la sección (index 2) para recarga
  automática.
- Package `dart:io` → `Directory.listSync()` para escanear archivos en
  `historico/`.

## 3) Objetivo técnico

- **Qué debe cambiar:** La feature `orders_history` pasa de un placeholder a una
  feature completa con capas data, domain y presentation.
- **Resultado técnico:** Un BLoC que gestiona dos estados de navegación (listado
  de fechas → detalle de una fecha), con soporte de filtro por rango de fechas y
  búsqueda de clientes, conectado a un repositorio que escanea la carpeta
  `historico/` y lee archivos Excel individuales.
- **Limitaciones:** Solo lectura. No se implementa exportación (se deja
  preparado el diseño para iteración futura).

## 4) Diseño técnico de la solución

### Enfoque propuesto

La feature se organiza en 3 capas siguiendo el patrón de `orders_today`:

**Domain:**

- Reutilizar `OrderSheet` y `OrderRow` de `orders_today/domain/entities/`.
- Nuevo contrato `OrdersHistoryRepository` con 2 métodos: listar fechas
  disponibles y obtener pedidos de una fecha.
- 2 use cases: `GetAvailableDates` y `GetHistoryOrders`.

**Data:**

- `OrdersHistoryRepositoryImpl` que usa `ExcelLocalDataSource` (ya registrado) y
  `dart:io` `Directory` para listar archivos.
- No se necesita nuevo datasource; el existente cubre `readExcel` y
  `fileExists`.

**Presentation:**

- `OrdersHistoryBloc` con estados y eventos para: carga de fechas, selección de
  fecha, filtro por rango, búsqueda de clientes.
- `OrdersHistoryPage` refactorizada con lógica de carpeta de trabajo (patrón
  idéntico a `OrdersTodayPage`).
- Widget `HistoryDateList` para el listado de fechas con filtro por rango.
- Widget `HistoryOrdersTable` — tabla read-only (sin checkboxes, sin celdas
  editables) inspirada en `OrdersTable`.
- Widgets de estado: vacío, error (reutilizando patrones visuales de
  `orders_today`).

### Componentes / módulos / servicios afectados

| Componente                                  | Tipo           | Acción                             |
| ------------------------------------------- | -------------- | ---------------------------------- |
| `orders_history/domain/repositories/`       | Contrato       | Crear                              |
| `orders_history/domain/usecases/`           | Use cases      | Crear                              |
| `orders_history/data/repositories/`         | Implementación | Crear                              |
| `orders_history/presentation/bloc/`         | BLoC           | Crear                              |
| `orders_history/presentation/pages/`        | Page           | Modificar (reescribir placeholder) |
| `orders_history/presentation/widgets/`      | Widgets        | Crear                              |
| `app/di/modules/orders_history_module.dart` | DI module      | Crear                              |
| `app/di/injection.dart`                     | DI entrypoint  | Modificar (registrar módulo)       |
| `app/localization/l10n/app_es.arb`          | i18n           | Modificar (agregar strings)        |

### Contratos e interfaces

**`OrdersHistoryRepository` (domain/repositories/):**

```dart
abstract class OrdersHistoryRepository {
  Future<Either<Failure, List<DateTime>>> getAvailableDates(String workFolderPath);
  Future<Either<Failure, OrderSheet>> getHistoryOrders(String workFolderPath, DateTime date);
}
```

**Use cases:**

```dart
class GetAvailableDates implements UseCase<List<DateTime>, GetAvailableDatesParams> { ... }
class GetHistoryOrders implements UseCase<OrderSheet, GetHistoryOrdersParams> { ... }
```

**BLoC events:**

- `OrdersHistoryLoadDates` — cargar listado de fechas (disparado al navegar a la
  sección).
- `OrdersHistoryDateSelected` — seleccionar una fecha y cargar sus pedidos.
- `OrdersHistoryBackToList` — volver al listado de fechas.
- `OrdersHistoryDateRangeChanged` — aplicar filtro por rango de fechas.
- `OrdersHistorySearchChanged` — filtrar clientes por nombre.

**BLoC states (sealed class):**

- `OrdersHistoryInitial`
- `OrdersHistoryLoading`
- `OrdersHistoryDatesLoaded` — contiene `List<DateTime> allDates`,
  `List<DateTime> filteredDates`, `DateTime? startDate`, `DateTime? endDate`.
- `OrdersHistoryDetailLoading` — cargando pedidos de una fecha.
- `OrdersHistoryDetailLoaded` — contiene `DateTime selectedDate`,
  `OrderSheet orderSheet`, `String searchFilter`.
- `OrdersHistoryEmpty` — sin archivos históricos.
- `OrdersHistoryError` — con tipo de error.

### Flujo de datos o de control

1. `OrdersHistoryPage` (StatefulWidget) escucha `SideMenuCubit` para detectar
   navegación al index 2.
2. Al detectar navegación, obtiene `workFolderPath` via
   `SettingsRepository.getWorkFolder()`.
3. Si no hay carpeta configurada → muestra estado "sin carpeta" con botón a
   Ajustes.
4. Si hay carpeta → crea `OrdersHistoryBloc` via `BlocProvider` y dispara
   `OrdersHistoryLoadDates`.
5. `OrdersHistoryBloc._onLoadDates` → llama `GetAvailableDates` use case →
   repositorio escanea `{workFolder}/historico/`, parsea nombres de archivo
   `YYYY-MM-DD.xlsx`, excluye hoy, ordena desc → emite
   `OrdersHistoryDatesLoaded`.
6. Usuario selecciona fecha → `OrdersHistoryDateSelected` → `GetHistoryOrders` →
   repositorio lee Excel → emite `OrdersHistoryDetailLoaded`.
7. Filtro de rango de fechas se aplica en el BLoC sobre la lista ya cargada (no
   requiere releer el filesystem).
8. Búsqueda de clientes se aplica en UI (filtro sobre `OrderSheet.rows`) o en el
   estado del BLoC.

### Gestión de errores y validaciones

- **Carpeta `historico/` no existe:** El repositorio devuelve `Right([])` (lista
  vacía). No es un error.
- **Archivo no parseable:** `readExcel` lanza `ParsingException` → repositorio
  captura → `Left(EntityMappingFailure())` → BLoC emite estado de error con tipo
  `invalidFormat`.
- **Error de filesystem:** `FileAccessException` → `Left(FileSystemFailure())` →
  BLoC emite estado de error con tipo `fileSystemError`.
- **Nombre de archivo inválido:** Se ignora silenciosamente al escanear (no se
  incluye en la lista de fechas).
- **Archivo del día actual:** Se filtra durante el escaneo, no se incluye en
  resultados.

### Consideraciones de compatibilidad o migración

- No hay migración necesaria. Es funcionalidad nueva sobre datos existentes.
- Las entidades `OrderSheet`/`OrderRow` se importan cross-feature. Si en el
  futuro se quiere evitar este acoplamiento, se pueden mover a
  `core/domain/entities/`. Por ahora es aceptable dado que ambas features operan
  sobre el mismo concepto de dominio.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                           | Propósito                                     |
| ----------------------------------------------------------------------------------- | --------------------------------------------- |
| `lib/features/orders_history/domain/repositories/orders_history_repository.dart`    | Contrato del repositorio                      |
| `lib/features/orders_history/domain/usecases/get_available_dates.dart`              | Use case: obtener fechas con histórico        |
| `lib/features/orders_history/domain/usecases/get_history_orders.dart`               | Use case: obtener pedidos de una fecha        |
| `lib/features/orders_history/data/repositories/orders_history_repository_impl.dart` | Implementación del repositorio                |
| `lib/features/orders_history/presentation/bloc/orders_history_bloc.dart`            | BLoC de la feature                            |
| `lib/features/orders_history/presentation/bloc/orders_history_event.dart`           | Eventos del BLoC                              |
| `lib/features/orders_history/presentation/bloc/orders_history_state.dart`           | Estados del BLoC                              |
| `lib/features/orders_history/presentation/widgets/history_date_list.dart`           | Widget: listado de fechas con filtro de rango |
| `lib/features/orders_history/presentation/widgets/history_orders_table.dart`        | Widget: tabla read-only de pedidos            |
| `lib/features/orders_history/presentation/widgets/history_empty_state.dart`         | Widget: estado vacío                          |
| `lib/features/orders_history/presentation/widgets/history_error_state.dart`         | Widget: estado de error                       |
| `lib/app/di/modules/orders_history_module.dart`                                     | Módulo DI para la feature                     |

### Artefactos a modificar

| Artefacto                                                                 | Cambio esperado                                                         |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `lib/features/orders_history/presentation/pages/orders_history_page.dart` | Reescribir: reemplazar placeholder por implementación completa con BLoC |
| `lib/app/di/injection.dart`                                               | Agregar import y llamada a `registerOrdersHistoryModule(sl)`            |
| `lib/app/localization/l10n/app_es.arb`                                    | Agregar claves i18n para la feature                                     |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo                        |
| --------- | ----------------------------- |
| N/A       | No se retira ningún artefacto |

## 6) Estrategia de implementación

1. **Paso 1 — Domain layer:** Crear contrato `OrdersHistoryRepository` y use
   cases `GetAvailableDates`, `GetHistoryOrders`.
2. **Paso 2 — Data layer:** Crear `OrdersHistoryRepositoryImpl` que usa
   `ExcelLocalDataSource` y `dart:io.Directory`.
3. **Paso 3 — i18n:** Agregar todas las claves de localización necesarias en
   `app_es.arb`.
4. **Paso 4 — BLoC:** Crear `OrdersHistoryBloc` con events y states.
5. **Paso 5 — DI module:** Crear `orders_history_module.dart` y registrar en
   `injection.dart`.
6. **Paso 6 — Widgets:** Crear `HistoryDateList`, `HistoryOrdersTable`,
   `HistoryEmptyState`, `HistoryErrorState`.
7. **Paso 7 — Page:** Reescribir `OrdersHistoryPage` con la lógica completa.
8. **Paso 8 — Tests:** Tests unitarios para repositorio, use cases y BLoC.

### Orden recomendado

- Pasos 1-2 primero (domain + data) — son la base sin dependencias de Flutter.
- Paso 3 (i18n) puede hacerse en paralelo con 1-2.
- Pasos 4-5 (BLoC + DI) dependen de 1-2.
- Pasos 6-7 (UI) dependen de 3-5.
- Paso 8 (tests) puede empezarse tras el paso 2 (tests de repo) y completarse
  tras el paso 4 (tests de BLoC).

### Dependencias entre pasos

- Paso 4 depende de paso 1 (use cases).
- Paso 5 depende de pasos 1, 2 y 4 (todo lo registrable).
- Pasos 6-7 dependen de pasos 3, 4 y 5.

### Puntos delicados

- **Referencia cross-feature a entidades:** `OrderSheet`/`OrderRow` se importan
  desde `orders_today/domain/entities/`. Es aceptable y pragmático, pero debe
  documentarse como decisión consciente.
- **Escaneo de directorio:** Usar `Directory.listSync()` con filtro por
  extensión `.xlsx` y regex para el patrón de nombre. Manejar el caso de
  directorio inexistente.
- **Recarga al navegar:** El patrón de escuchar `SideMenuCubit.stream` ya está
  probado en `OrdersTodayPage`. Replicar la misma estrategia con el index 2.
- **Filtro de rango de fechas:** Se aplica sobre la lista ya cargada en memoria
  (no requiere releer filesystem). El BLoC mantiene `allDates` y calcula
  `filteredDates`.

## 7) Estrategia de validación

### Tests automáticos recomendados

- **Unit test `OrdersHistoryRepositoryImpl`:** Mockear `ExcelLocalDataSource` y
  filesystem. Verificar escaneo de fechas, exclusión de hoy, lectura de archivo,
  manejo de errores.
- **Unit test `GetAvailableDates`:** Verificar delegación al repositorio.
- **Unit test `GetHistoryOrders`:** Verificar delegación al repositorio.
- **Unit test `OrdersHistoryBloc`:** Usando `bloc_test`, verificar transiciones
  de estado para todos los eventos: carga de fechas, selección de fecha, filtro
  de rango, búsqueda, volver al listado, errores.

### Validación manual

- Navegar a la sección con carpeta configurada que tenga archivos históricos →
  ver listado de fechas.
- Seleccionar una fecha → ver tabla con pedidos.
- Aplicar filtro de rango de fechas → verificar que el listado se acota
  correctamente.
- Buscar cliente por nombre → verificar filtrado.
- Navegar sin carpeta configurada → verificar estado "sin carpeta".
- Navegar con carpeta vacía (sin históricos) → verificar estado vacío.
- Navegar fuera y volver → verificar que se recarga la lista.

### Escenarios a cubrir

- Carpeta `historico/` no existe.
- Carpeta `historico/` vacía.
- Archivos con nombres inválidos (ignorados).
- Archivo del día actual (excluido).
- Archivo corrupto / formato inválido.
- Archivo con 0 filas de clientes.
- Filtro de rango que excluye todas las fechas.
- Búsqueda sin resultados.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **Bajo:** Acoplamiento cross-feature con entidades de `orders_today`.
  Mitigación: las entidades son de dominio compartido y no tienen dependencias
  de infraestructura.
- **Bajo:** Performance con muchos archivos en `historico/`
  (`Directory.listSync`). Mitigación: el escaneo es síncrono pero rápido para
  volúmenes razonables; si fuera necesario, se puede mover a un `Isolate` en el
  futuro.

### Impacto potencial

- Ningún impacto en funcionalidad existente. Es código nuevo autocontenido.
- El registro DI agrega un nuevo módulo pero no afecta los existentes.

### Mitigación

- Tests unitarios cubren la lógica de negocio.
- El placeholder actual se reemplaza, pero es código trivial sin lógica.

### Plan de rollback

- Revertir el commit. El placeholder original se restaura y no hay migración de
  datos.

## 9) Suposiciones

- `ExcelLocalDataSource` ya está registrado como singleton en GetIt y es seguro
  reutilizarlo desde otra feature.
- El volumen de archivos en `historico/` es razonable (< 1000 archivos) y no
  requiere paginación ni carga asíncrona del listado de directorio.
- Las entidades `OrderSheet`/`OrderRow` son estables y no cambiarán su
  estructura en el corto plazo.
- El patrón de nombre de archivo `YYYY-MM-DD.xlsx` es estricto y no hay
  variantes.

## 10) Preguntas abiertas

- Ninguna. El análisis funcional resolvió todas las dudas previas.

## 11) Notas para implementación

- **Referencia cross-feature:** Importar `OrderSheet` y `OrderRow` desde
  `package:servicebo/features/orders_today/domain/entities/`. No mover a `core/`
  en esta iteración para minimizar el impacto.
- **Secuencia sugerida:** Domain → Data → i18n → BLoC → DI → Widgets → Page →
  Tests.
- **Recarga al navegar:** Replicar el patrón de `OrdersTodayPage._onMenuChanged`
  escuchando `SideMenuCubit.stream` y comparando con index 2
  (`_kOrdersHistoryIndex = 2`).
- **Tabla read-only:** No reutilizar `OrdersTable` directamente (tiene lógica de
  edición, checkboxes, etc.). Crear `HistoryOrdersTable` más simple, sin
  callbacks de edición.
- **Filtro de rango:** Usar `showDateRangePicker` de Material o dos `DatePicker`
  independientes. El estado del filtro se mantiene en el BLoC.
- **Preparar exportación futura:** El diseño del BLoC y la disponibilidad de
  `OrderSheet` en el estado `OrdersHistoryDetailLoaded` facilitan agregar
  exportación en una iteración posterior sin cambios estructurales.
- **No romper comportamiento existente:** No se modifica ningún archivo de
  `orders_today`, `settings` ni `home`. Solo se agrega el nuevo módulo DI y las
  claves i18n.
- **Estado: Listo para implementación**
