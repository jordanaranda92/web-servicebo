# Technical Analysis: Optimización de consultas de facturas en el Dashboard

- **Fecha:** 2026-05-12
- **Identificador:** dashboard-fd-counters-optimization
- **Fuente:**
  docs/functional-analysis/2026-05-12-dashboard-fd-counters-optimization.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Sustituir el use case `GetInvoices` (sin parámetros, descarga 500 facturas) en
  `FdCountersCubit` por un nuevo use case `GetInvoicesByDateRange` que acepta
  `minDate`/`maxDate`.
- Añadir el método `getInvoicesByDateRange` al datasource
  `FacturaDirectaApiDataSource` y al repositorio `InvoicesRepository`.
- Refactorizar `FdCountersCubit.load()` para calcular dos rangos de fechas (mes
  actual y mes anterior) y lanzar ambas peticiones en paralelo con
  `Future.wait`.
- Áreas impactadas: datasource core, feature invoices (repositorio + use case),
  feature home (cubit + DI).
- Riesgo general: **bajo** — cambio acotado, sin impacto en UI ni en otros
  consumidores de `GetInvoices`.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC/Cubit, GetIt, fpdart.
- Patrón `UseCase<Type, Params>` abstracto en `lib/core/usecase/usecase.dart`.
- El datasource `FacturaDirectaApiDataSource` es compartido en `lib/core/data/`
  y consumido por múltiples features.

### Módulos relevantes

| Capa                   | Artefacto                         | Ruta                                                                    |
| ---------------------- | --------------------------------- | ----------------------------------------------------------------------- |
| Datasource (core)      | `FacturaDirectaApiDataSource`     | `lib/core/data/datasources/factura_directa_api_data_source.dart`        |
| Datasource impl (core) | `FacturaDirectaApiDataSourceImpl` | `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`   |
| Repository contract    | `InvoicesRepository`              | `lib/features/invoices/domain/repositories/invoices_repository.dart`    |
| Repository impl        | `InvoicesRepositoryImpl`          | `lib/features/invoices/data/repositories/invoices_repository_impl.dart` |
| Use case existente     | `GetInvoices`                     | `lib/features/invoices/domain/usecases/get_invoices.dart`               |
| Cubit                  | `FdCountersCubit`                 | `lib/features/home/presentation/bloc/fd_counters_cubit.dart`            |
| State                  | `FdCountersState`                 | `lib/features/home/presentation/bloc/fd_counters_state.dart`            |
| DI home                | `home_module.dart`                | `lib/app/di/modules/home_module.dart`                                   |
| DI invoices            | `invoices_module.dart`            | `lib/app/di/modules/invoices_module.dart`                               |

### Restricciones

- El proxy `fdProxy` (Cloud Function) reenvía cualquier `queryParameters` sin
  validación — no requiere cambios.
- `getInvoicesByContact` ya usa `minDate`/`maxDate` en el mismo endpoint
  `/invoices`, confirmando que la API de FD los acepta como query params
  opcionales.
- El use case `GetInvoices` (sin parámetros) sigue siendo necesario para la
  pantalla de listado de facturas (`InvoicesPage`). No se modifica ni se
  reemplaza.

### Dependencias

- No se introducen nuevas dependencias externas.

## 3) Objetivo técnico

- **Qué debe cambiar:** La obtención de datos de facturas para el dashboard pasa
  de una petición sin filtro (`limit=500`) a dos peticiones filtradas por rango
  de fecha.
- **Resultado técnico:** El cubit recibe solo las facturas de los rangos
  relevantes (~2 meses), con datos completos y menor latencia.
- **Limitaciones a respetar:**
  - No modificar `GetInvoices` ni `getInvoices()` existentes (usados por
    `InvoicesPage`).
  - No modificar la Cloud Function `fdProxy`.
  - No alterar `FdCountersState` ni la UI.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Crear un camino vertical nuevo (datasource → repository → use case) para obtener
facturas por rango de fechas, y consumirlo desde el cubit.

### Componentes / módulos / servicios afectados

1. **`FacturaDirectaApiDataSource`** (abstracta) — nuevo método.
2. **`FacturaDirectaApiDataSourceImpl`** — implementación del nuevo método.
3. **`InvoicesRepository`** (abstracta) — nuevo método.
4. **`InvoicesRepositoryImpl`** — implementación del nuevo método.
5. **`GetInvoicesByDateRange`** — nuevo use case.
6. **`FdCountersCubit`** — refactorizar `load()` para usar el nuevo use case.
7. **`home_module.dart`** — actualizar inyección de dependencias.
8. **`invoices_module.dart`** — registrar el nuevo use case.

### Contratos e interfaces

#### Nuevo método en `FacturaDirectaApiDataSource`

```dart
Future<List<Map<String, dynamic>>> getInvoicesByDateRange({
  required String minDate,
  required String maxDate,
});
```

#### Nuevo método en `InvoicesRepository`

```dart
Future<Either<Failure, List<Invoice>>> getInvoicesByDateRange({
  required String minDate,
  required String maxDate,
});
```

#### Nuevo use case `GetInvoicesByDateRange`

```dart
class DateRangeParams extends Equatable {
  final String minDate;
  final String maxDate;
  const DateRangeParams({required this.minDate, required this.maxDate});
  @override
  List<Object?> get props => [minDate, maxDate];
}

class GetInvoicesByDateRange extends UseCase<List<Invoice>, DateRangeParams> {
  final InvoicesRepository _repository;
  GetInvoicesByDateRange(this._repository);

  @override
  Future<Either<Failure, List<Invoice>>> call(DateRangeParams params) {
    return _repository.getInvoicesByDateRange(
      minDate: params.minDate,
      maxDate: params.maxDate,
    );
  }
}
```

#### Constructor actualizado de `FdCountersCubit`

```dart
FdCountersCubit({required GetInvoicesByDateRange getInvoicesByDateRange})
    : _getInvoicesByDateRange = getInvoicesByDateRange,
      super(const FdCountersInitial());
```

### Flujo de datos o de control

```
HomePage.initState()
  └─ FdCountersCubit.load()
       ├─ Calcula rangos:
       │   rangoA = (1er día mes actual, hoy)
       │   rangoB = (1er día mes anterior, día equivalente mes anterior)
       │
       ├─ Future.wait([
       │     getInvoicesByDateRange(rangoA),
       │     getInvoicesByDateRange(rangoB),
       │   ])
       │
       ├─ Combina ambas listas (allInv = [...rangoA, ...rangoB])
       │
       ├─ Filtra en memoria (lógica existente sin cambios):
       │   - hoy → contadores
       │   - ayer → comparativa
       │   - weekday semana pasada → comparativa
       │   - semana actual vs anterior → comparativa
       │   - mes actual vs anterior → comparativa
       │
       └─ emit(FdCountersLoaded(...))
```

### Gestión de errores y validaciones

- Si **cualquiera** de las dos peticiones falla → `emit(FdCountersError())`. Se
  usa `Future.wait` que lanza la primera excepción si falla alguna, pero como se
  usa fpdart `Either`, se evalúan ambos resultados: si alguno es `Left`, se
  emite error.
- Las excepciones `ServerException`, `NetworkException`, `ParsingException` se
  capturan en `InvoicesRepositoryImpl` (patrón existente).
- El estado `FdCountersNotConfigured` no aplica actualmente en este flujo (el
  cubit no lo emite; se mantiene sin cambios).

### Consideraciones de compatibilidad o migración

- `GetInvoices` (use case sin parámetros) **no se toca**. Sigue disponible y
  registrado en DI para `InvoicesCubit` y `InvoicesPage`.
- El cambio en `FdCountersCubit` es un breaking change en su constructor (cambia
  de `GetInvoices` a `GetInvoicesByDateRange`), pero solo se instancia desde
  `home_module.dart`, por lo que el impacto está contenido.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                               | Propósito                                   |
| ----------------------------------------------------------------------- | ------------------------------------------- |
| `lib/features/invoices/domain/usecases/get_invoices_by_date_range.dart` | Use case con parámetros `minDate`/`maxDate` |

### Artefactos a modificar

| Artefacto                                                               | Cambio esperado                                                                                                         |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `lib/core/data/datasources/factura_directa_api_data_source.dart`        | Añadir método `getInvoicesByDateRange`                                                                                  |
| `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`   | Implementar `getInvoicesByDateRange`: `GET /invoices?minDate=X&maxDate=X&related=state&limit=5000`                      |
| `lib/features/invoices/domain/repositories/invoices_repository.dart`    | Añadir método `getInvoicesByDateRange`                                                                                  |
| `lib/features/invoices/data/repositories/invoices_repository_impl.dart` | Implementar `getInvoicesByDateRange` (mismo patrón que `getInvoices`)                                                   |
| `lib/features/home/presentation/bloc/fd_counters_cubit.dart`            | Cambiar dependencia a `GetInvoicesByDateRange`; refactorizar `load()` para calcular rangos y hacer 2 llamadas paralelas |
| `lib/app/di/modules/home_module.dart`                                   | Cambiar inyección del cubit: `getInvoicesByDateRange: sl()`                                                             |
| `lib/app/di/modules/invoices_module.dart`                               | Registrar `GetInvoicesByDateRange(sl())`                                                                                |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo                                            |
| --------- | ------------------------------------------------- |
| Ninguno   | `GetInvoices` se mantiene para otros consumidores |

## 6) Estrategia de implementación

### Pasos

1. **Datasource** — Añadir `getInvoicesByDateRange` a la interfaz abstracta y a
   la implementación.
2. **Repository** — Añadir `getInvoicesByDateRange` a la interfaz abstracta y a
   la implementación.
3. **Use case** — Crear `GetInvoicesByDateRange` con `DateRangeParams`.
4. **DI** — Registrar el nuevo use case en `invoices_module.dart`.
5. **Cubit** — Refactorizar `FdCountersCubit`:
   - Cambiar dependencia de `GetInvoices` a `GetInvoicesByDateRange`.
   - En `load()`: calcular rangos, lanzar `Future.wait`, combinar resultados,
     mantener lógica de cálculo.
6. **DI Home** — Actualizar `home_module.dart` para inyectar el nuevo use case.
7. **Tests** — Actualizar/crear tests del cubit con el nuevo use case.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 (estrictamente secuencial, cada paso depende del
anterior).

### Dependencias entre pasos

- Paso 2 depende de paso 1 (el repositorio llama al datasource).
- Paso 3 depende de paso 2 (el use case llama al repositorio).
- Pasos 5 y 6 dependen de pasos 3 y 4.
- Paso 7 depende de paso 5.

### Puntos delicados

- **Cálculo de rangos de fecha**: la lógica de edge cases (cambio de mes, año
  cruzado, día equivalente en mes más corto) ya existe en el cubit actual y debe
  reutilizarse sin cambios. Los rangos se calculan con la misma lógica, solo que
  ahora se usan para las peticiones en vez de solo para el filtrado en memoria.
- **Combinar resultados de ambas peticiones**: al juntar las listas de ambos
  rangos, no habrá duplicados porque los rangos son disjuntos (mes actual y mes
  anterior no se solapan).
- **Limit de protección**: usar `limit=5000` como protección. Si la API trunca
  antes, los datos serán parciales (riesgo aceptado y documentado en
  suposiciones).

## 7) Estrategia de validación

### Verificación automática

- **Test unitario del cubit**: mockear `GetInvoicesByDateRange` y verificar que
  se invoca con los rangos correctos para diferentes fechas (día normal, lunes,
  primer día del mes, enero).
- **Test unitario del cubit**: verificar que si una de las dos llamadas falla,
  se emite `FdCountersError`.
- **Test unitario del cubit**: verificar que los contadores y comparativas se
  calculan correctamente a partir de datos parciales de los dos rangos.
- **Test del repositorio**: verificar que `getInvoicesByDateRange` llama al
  datasource con los parámetros correctos y mapea la respuesta.

### Verificación manual

- Abrir el dashboard y verificar que los contadores y comparativas se muestran
  correctamente.
- Verificar en los logs (`[FD API]`) que las peticiones incluyen `minDate` y
  `maxDate` y no `limit=500`.
- Comparar valores del dashboard antes y después del cambio (deben ser idénticos
  si el volumen es < 500 facturas).

### Escenarios a cubrir

- Día normal a mitad de mes.
- Primer día del mes (rango A = un solo día).
- Lunes (semana actual = un solo día).
- Enero (mes anterior = diciembre del año anterior).
- Sin facturas en los rangos → contadores a 0, comparativas neutras.
- Error de red en una de las peticiones → estado error.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                | Probabilidad                               | Impacto                                       |
| --------------------------------------------------------------------- | ------------------------------------------ | --------------------------------------------- |
| La API de FD no acepta `minDate`/`maxDate` sin `contact`              | Baja (ya se usa en `getInvoicesByContact`) | Alto — el cambio no funcionaría               |
| La API trunca resultados a un límite interno < volumen real del rango | Baja (rangos de ~30 días)                  | Medio — comparativas parcialmente incorrectas |

### Mitigación

- **Riesgo 1**: Probar manualmente una llamada al proxy con solo
  `minDate`/`maxDate` antes de integrar. Si no funciona, se puede enviar
  `contact` vacío o buscar un parámetro alternativo.
- **Riesgo 2**: Usar `limit=5000` como protección. Monitorizar si alguna
  respuesta devuelve exactamente 5000 items (indicaría truncamiento).

### Impacto potencial

- Si falla: el dashboard muestra estado de error en las cards de FD (mismo
  comportamiento que un fallo de red actual). No afecta a otras funcionalidades.

### Plan de rollback

- Revertir el commit. El cambio es autocontenido y no modifica artefactos
  compartidos de forma destructiva (`GetInvoices` se mantiene intacto).

## 9) Suposiciones

- La API de FD acepta `minDate`/`maxDate` como query params opcionales en
  `GET /invoices` sin requerir `contact`.
- Un `limit=5000` es suficiente para cualquier rango mensual en el volumen de
  negocio de Servicebo.
- El proxy `fdProxy` no impone restricciones de tamaño de respuesta que bloqueen
  rangos de ~30 días.

## 10) Preguntas abiertas

- Ninguna bloqueante. Las dos preguntas del análisis funcional se han resuelto
  con evidencia del código existente (ver conversación previa).

## 11) Notas para implementación

- El método `_dateStr` del cubit actual (formato `YYYY-MM-DD`) debe usarse para
  generar los strings de `minDate`/`maxDate` del `DateRangeParams`. Considerar
  extraerlo a un helper o replicarlo en donde se necesite.
- La lógica de cálculo de rangos en `load()` (mondayThisWeek, firstDayThisMonth,
  equivalentDayLastMonth, etc.) ya existe y se mantiene; solo cambia el punto en
  el que se usa: ahora define los params de las peticiones, no solo los filtros
  en memoria.
- Los helpers `_compareSingleDay` y `_compareRange` del cubit siguen siendo
  útiles para filtrar dentro de la lista combinada de ambos rangos. No se
  eliminan.
- Asegurarse de que el constructor del cubit en `home_module.dart` pasa
  `getInvoicesByDateRange: sl()` en vez de `getInvoices: sl()`.
- No quitar el import/registro de `GetInvoices` del `invoices_module.dart` —
  sigue siendo usado por `InvoicesCubit`.
- Secuencia sugerida: datasource → repository → use case → DI → cubit → DI home
  → tests.
- **Estado: Listo para implementación**
