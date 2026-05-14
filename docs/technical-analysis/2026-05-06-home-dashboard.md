# Technical Analysis: Dashboard de inicio con contadores y comparativas

- **Fecha:** 2026-05-06
- **Identificador:** home-dashboard
- **Fuente:** docs/functional-analysis/2026-05-06-home-dashboard.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Crear una nueva capa domain+data dentro de `features/home/` con una entidad
  `DashboardStats`, un repository y un use case que orquesten la lectura de
  archivos Excel y el cálculo de contadores y comparativas.
- Crear un `DashboardCubit` que gestione el estado del dashboard (loading,
  loaded, error, no folder).
- Reemplazar el contenido placeholder de `HomePage` por un layout de tarjetas
  estadísticas y comparativas.
- Registrar las nuevas dependencias en un módulo DI actualizado.
- Principales áreas impactadas: `features/home/`,
  `app/di/modules/home_module.dart`, i18n (`app_es.arb`).
- Riesgo general estimado: **bajo**. Es lectura pura, no modifica datos, y
  reutiliza infraestructura existente.

## 2) Contexto técnico observado

- **Arquitectura**: Clean Architecture feature-first con BLoC/Cubit, GetIt para
  DI, fpdart para `Either`.
- **Lectura de datos**: `ExcelLocalDataSource` (singleton en DI) lee archivos
  `.xlsx`. `OrdersHistoryRepository` accede a archivos históricos en
  `historico/YYYY-MM-DD.xlsx`.
- **Entidades existentes**: `OrderSheet` (products: `List<String>`, rows:
  `List<OrderRow>`), `OrderRow` (clientName, quantities: `Map<String, num>`).
- **DI**: `home_module.dart` solo registra `SideMenuCubit`. Los demás módulos
  (settings, orders_today, orders_history) ya están registrados y disponibles.
- **UI shell**: `SideMenuShell` usa `IndexedStack` → `HomePage` se instancia una
  vez y permanece viva. Se necesita recarga explícita cuando el usuario vuelve a
  la pestaña.
- **i18n**: solo español, archivo `app_es.arb`.
- **Design tokens**: `AppSpacing`, `AppRadii`, `AppIconSizes` en
  `theme_constants.dart`. Colores vía `Theme.of(context).colorScheme`.
- **Patrón de use case**: `UseCase<Type, Params>` con `Either<Failure, Type>`.
- **Failures existentes**: `FileSystemFailure`, `InternalFailure`.

## 3) Objetivo técnico

- Introducir capa domain/data en `features/home/` para calcular estadísticas del
  dashboard a partir de archivos Excel existentes.
- Exponer un `DashboardCubit` con estados tipados que la UI consume
  directamente.
- Reemplazar el contenido de `HomePage` con widgets que muestren contadores y
  comparativas.
- No crear nuevos data sources; reutilizar `ExcelLocalDataSource` y
  `OrdersHistoryRepository` existentes.
- Respetar la convención de Clean Architecture feature-first, DI con GetIt, y
  fpdart.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Crear un `DashboardRepository` que encapsule la lógica de obtener las métricas
del día y las comparativas. Un use case `GetDashboardStats` lo consume. Un
`DashboardCubit` en presentación invoca el use case y emite estados. La
`HomePage` se reconstruye para mostrar los datos.

### Componentes / módulos / servicios afectados

- `features/home/domain/` — nueva capa (entidad, repository abstracto, use case)
- `features/home/data/` — nueva capa (repository impl)
- `features/home/presentation/bloc/` — nuevo `DashboardCubit` + estado
- `features/home/presentation/pages/home_page.dart` — reescritura de UI
- `features/home/presentation/widgets/` — nuevos widgets de tarjetas
- `app/di/modules/home_module.dart` — registro de nuevas dependencias
- `lib/app/localization/l10n/app_es.arb` — nuevas claves i18n

### Contratos e interfaces

#### Entidad `DashboardStats`

```dart
class DashboardStats extends Equatable {
  final DaySummary today;
  final Comparison? vsYesterday;
  final Comparison? vsSameWeekday;
  final WeekComparison? vsLastWeek;
}

class DaySummary extends Equatable {
  final int clientCount;
  final int productCount;
  final num totalUnits;
  final String? topProduct; // null si no hay datos
}

class Comparison extends Equatable {
  final int clientDiff;
  final num unitsDiff;
  final double? unitsPercentDiff; // null si referencia = 0 y actual > 0
}

class WeekComparison extends Equatable {
  final int clientDiff;
  final num unitsDiff;
  final double? unitsPercentDiff;
}
```

Cuando una comparativa no tiene datos (archivo inexistente), el campo
correspondiente es `null` en `DashboardStats`.

#### Repository abstracto

```dart
abstract class DashboardRepository {
  Future<Either<Failure, DashboardStats>> getStats(
    String workFolderPath,
    DateTime today,
  );
}
```

#### Use case

```dart
class GetDashboardStats implements UseCase<DashboardStats, GetDashboardStatsParams> {
  // params: workFolderPath, today
}
```

#### Cubit states

```dart
sealed class DashboardState extends Equatable {}
class DashboardInitial extends DashboardState {}
class DashboardLoading extends DashboardState {}
class DashboardLoaded extends DashboardState { final DashboardStats stats; }
class DashboardNoFolder extends DashboardState {}
class DashboardError extends DashboardState {}
```

### Flujo de datos o de control

1. `HomePage.initState()` / `didChangeDependencies()` → `DashboardCubit.load()`
2. `DashboardCubit.load()`: a. Obtiene `WorkFolderConfig` de
   `SettingsRepository` (ya en DI) b. Si no hay carpeta → emite
   `DashboardNoFolder` c. Si hay carpeta → emite `DashboardLoading` → llama
   `GetDashboardStats(workFolderPath, DateTime.now())` d. Resultado
   `Right(stats)` → `DashboardLoaded(stats)` e. Resultado `Left(failure)` →
   `DashboardError`
3. `DashboardRepositoryImpl.getStats()`: a. Lee archivo de hoy con
   `ExcelLocalDataSource.readExcel()` (si existe, `fileExists()` primero) b.
   Calcula `DaySummary` del sheet de hoy c. Lee archivo de ayer
   (`today - 1 día`) → calcula comparativa o devuelve `null` d. Lee archivo de
   hace 7 días → calcula comparativa o devuelve `null` e. Calcula comparativa
   semanal: genera fechas de lunes a hoy para ambas semanas, lee cada archivo
   con `Future.wait` en paralelo, suma totales, calcula diferencia f. Retorna
   `DashboardStats` completo
4. `HomePage` consume `BlocBuilder<DashboardCubit, DashboardState>` y renderiza
   estados

**Recarga al volver a la pestaña**: `SideMenuShell` usa `IndexedStack`, así que
`HomePage` no se desmonta. Se debe escuchar `SideMenuCubit` para detectar cuándo
el usuario vuelve al índice 0 y relanzar `DashboardCubit.load()`. El mismo
patrón ya se usa en `OrdersHistoryPage` con `_menuSub`.

### Gestión de errores y validaciones

- Archivos inexistentes: `fileExists()` check previo → se trata como "sin datos"
  (`null`), no como error.
- Archivos con formato inválido: `try/catch` en la lectura individual → se trata
  como "sin datos" para esa comparativa, sin propagar error.
- Error general (sistema de archivos inaccesible): propaga `FileSystemFailure` →
  cubit emite `DashboardError`.
- División por cero en porcentaje: si referencia = 0 y actual > 0,
  `unitsPercentDiff = null`. Si ambos = 0, `unitsPercentDiff = 0`.
- Producto estrella: si no hay filas o todas las cantidades son 0,
  `topProduct = null`.

### Consideraciones de compatibilidad o migración

- No hay breaking changes. `HomePage` se reescribe pero mantiene su posición en
  `IndexedStack`.
- No se añaden dependencias externas nuevas.
- Los módulos DI existentes no se modifican; solo se amplía `home_module.dart`.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                            | Propósito                                                                  |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `lib/features/home/domain/entities/dashboard_stats.dart`             | Entidad con `DashboardStats`, `DaySummary`, `Comparison`, `WeekComparison` |
| `lib/features/home/domain/repositories/dashboard_repository.dart`    | Contrato abstracto del repository                                          |
| `lib/features/home/domain/usecases/get_dashboard_stats.dart`         | Use case que invoca el repository                                          |
| `lib/features/home/data/repositories/dashboard_repository_impl.dart` | Implementación: lee archivos, calcula métricas                             |
| `lib/features/home/presentation/bloc/dashboard_cubit.dart`           | Cubit que gestiona estados del dashboard                                   |
| `lib/features/home/presentation/bloc/dashboard_state.dart`           | Estados sealed del cubit                                                   |
| `lib/features/home/presentation/widgets/stat_card.dart`              | Widget tarjeta de contador individual                                      |
| `lib/features/home/presentation/widgets/comparison_card.dart`        | Widget tarjeta de comparativa con indicador ▲/▼                            |
| `lib/features/home/presentation/widgets/dashboard_no_folder.dart`    | Widget estado sin carpeta configurada                                      |
| `lib/features/home/presentation/widgets/dashboard_error.dart`        | Widget estado de error con botón reintentar                                |

### Artefactos a modificar

| Artefacto                                             | Cambio esperado                                                                                                  |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `lib/features/home/presentation/pages/home_page.dart` | Reescribir: reemplazar placeholder por layout de dashboard con `BlocProvider`/`BlocBuilder` del `DashboardCubit` |
| `lib/app/di/modules/home_module.dart`                 | Registrar `DashboardRepository`, `GetDashboardStats`, `DashboardCubit`                                           |
| `lib/app/localization/l10n/app_es.arb`                | Añadir claves i18n para etiquetas del dashboard                                                                  |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo                                                                                       |
| --------- | -------------------------------------------------------------------------------------------- |
| —         | No se retira ningún artefacto. El contenido placeholder de `HomePage` se reemplaza in-place. |

## 6) Estrategia de implementación

1. **Paso 1 — Domain**: Crear entidad `DashboardStats` y sus value objects
   (`DaySummary`, `Comparison`, `WeekComparison`).
2. **Paso 2 — Domain**: Crear contrato abstracto `DashboardRepository`.
3. **Paso 3 — Domain**: Crear use case `GetDashboardStats`.
4. **Paso 4 — Data**: Implementar `DashboardRepositoryImpl` con lógica de
   lectura y cálculo.
5. **Paso 5 — Presentation/BLoC**: Crear `DashboardState` y `DashboardCubit`.
6. **Paso 6 — i18n**: Añadir claves de traducción en `app_es.arb`.
7. **Paso 7 — Presentation/Widgets**: Crear `stat_card.dart`,
   `comparison_card.dart`, `dashboard_no_folder.dart`, `dashboard_error.dart`.
8. **Paso 8 — Presentation/Page**: Reescribir `HomePage` para integrar el cubit
   y los widgets.
9. **Paso 9 — DI**: Actualizar `home_module.dart` con los nuevos registros.
10. **Paso 10 — Tests**: Tests unitarios del repository impl, cubit y use case.

### Orden recomendado

Pasos 1-3 (domain) → Paso 4 (data) → Paso 5 (BLoC) → Paso 6 (i18n) → Pasos 7-8
(UI) → Paso 9 (DI) → Paso 10 (tests).

### Dependencias entre pasos

- Pasos 2 y 3 dependen del paso 1 (entidad).
- Paso 4 depende de pasos 1-2 (entidad + contrato).
- Paso 5 depende de paso 3 (use case).
- Pasos 7-8 dependen de pasos 5-6 (cubit + i18n).
- Paso 9 depende de pasos 4-5 (impl + cubit).

### Puntos delicados

- **Rendimiento de lectura**: `DashboardRepositoryImpl` puede necesitar leer
  hasta 12 archivos Excel para la comparativa semanal. Usar `Future.wait` para
  paralelizar lecturas independientes.
- **Recarga al volver a pestaña**: `IndexedStack` no desmonta `HomePage`. Se
  debe suscribir a `SideMenuCubit` para detectar vuelta al índice 0, igual que
  hace `OrdersHistoryPage`.
- **Lectura tolerante a fallos**: cada lectura de archivo individual debe estar
  en su propio `try/catch` para que un fallo en un archivo no impida calcular
  las demás métricas.
- **Cálculo de fechas semanales**: usar `DateTime.monday` de Dart
  (`date.weekday`) para calcular el lunes de la semana.
  `today.subtract(Duration(days: today.weekday - 1))` da el lunes.

## 7) Estrategia de validación

### Tests unitarios (obligatorios)

- **`DashboardRepositoryImpl`**: test con mocks de `ExcelLocalDataSource`:
  - Caso con todos los archivos presentes: verifica cálculos correctos de
    contadores y comparativas.
  - Caso sin archivo de hoy: `DaySummary` con valores a 0.
  - Caso sin archivos históricos: comparativas a `null`.
  - Caso con archivo inválido: comparativa individual a `null`, las demás
    correctas.
  - Caso división por cero: referencia = 0, actual > 0 →
    `unitsPercentDiff = null`.
  - Caso semana parcial: solo algunos días con archivo.

- **`DashboardCubit`**: test con mock de `GetDashboardStats` y
  `SettingsRepository`:
  - Emite `DashboardLoading` → `DashboardLoaded` en caso correcto.
  - Emite `DashboardNoFolder` si no hay carpeta configurada.
  - Emite `DashboardError` si el use case retorna `Left`.

- **`GetDashboardStats`**: test simple verificando que delega al repository.

### Verificación manual

- Abrir la app con carpeta configurada y archivos de prueba: verificar
  contadores y comparativas visualmente.
- Abrir sin carpeta configurada: verificar mensaje orientativo.
- Borrar archivos históricos: verificar "Sin datos" en comparativas.
- Verificar indicadores visuales ▲/▼ con datos positivos/negativos/neutros.

### Escenarios clave

- Hoy con datos + ayer con datos → comparativa numérica correcta.
- Hoy con datos + ayer sin archivo → "Sin datos".
- Hoy sin archivo → contadores a 0, comparativas funcionales.
- Semana con días faltantes → suma parcial.
- Lunes → semana de 1 solo día.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **Rendimiento**: lectura de hasta 12 archivos Excel podría ser lenta en discos
  lentos o con archivos grandes. Probabilidad baja dado que los archivos suelen
  ser pequeños.
- **Inconsistencia temporal**: si el usuario modifica pedidos de hoy en otra
  pestaña y vuelve a Inicio, los datos se recargan desde disco (coherente).

### Impacto potencial

- Solo afecta la pantalla de inicio. Si falla, las demás funcionalidades no se
  ven afectadas.
- El `IndexedStack` mantiene el estado de las demás páginas intacto.

### Mitigación

- Rendimiento: paralelizar lecturas con `Future.wait`. Los archivos Excel de
  pedidos son típicamente < 100 KB.
- Errores de lectura: `try/catch` individual por archivo, degradación graceful a
  `null`.

### Plan de rollback

- Revertir los cambios en `home_page.dart` al placeholder original.
- Eliminar los artefactos creados en `features/home/domain/`,
  `features/home/data/`, y los nuevos widgets.
- Revertir `home_module.dart` a solo registrar `SideMenuCubit`.
- Sin impacto en datos ni en otros módulos.

## 9) Suposiciones

- `ExcelLocalDataSource` ya está registrada como singleton en DI y puede
  reutilizarse directamente.
- `SettingsRepository` ya está en DI y expone `getWorkFolder()`.
- Los archivos históricos siguen invariablemente el patrón
  `historico/YYYY-MM-DD.xlsx`.
- `OrderSheet.rows` contiene todas las filas de clientes; `OrderRow.quantities`
  es un `Map<String, num>` de producto→cantidad.

## 10) Preguntas abiertas

No hay preguntas abiertas. El análisis funcional resolvió todas las incógnitas.

## 11) Notas para implementación

- Reutilizar `ExcelLocalDataSource` directamente en `DashboardRepositoryImpl`
  (no a través de `OrdersHistoryRepository`) para evitar una dependencia cruzada
  entre features. El data source ya está en DI como singleton compartido.
- Para la recarga al volver a la pestaña, seguir el patrón de
  `OrdersHistoryPage`: suscribirse a `SideMenuCubit.stream` en `initState` y
  lanzar `cubit.load()` cuando `state.selectedIndex == 0`.
- La entidad `DaySummary` se calcula con un helper privado en el repository impl
  que reciba un `OrderSheet?` y devuelva `DaySummary`.
- Para las fechas de la semana, calcular el lunes como
  `today.subtract(Duration(days: today.weekday - 1))` y generar los días desde
  lunes hasta hoy inclusive.
- Proteger la división por cero:
  `if (reference == 0) return current == 0 ? 0.0 : null`.
- **Estado: Listo para implementación**
