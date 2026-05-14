# Technical Analysis: Contadores de Albaranes y Facturas en el Dashboard

- **Fecha:** 2026-05-08
- **Identificador:** dashboard-fd-counters
- **Fuente:** docs/functional-analysis/2026-05-08-dashboard-fd-counters.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Se introduce un **nuevo cubit** (`FdCountersCubit`) en la feature `home` que
  gestiona de forma independiente la carga de contadores de albaranes y facturas
  desde FacturaDirecta, aislando cualquier fallo de FD del dashboard local
  existente.
- Se amplía el grid de `StatCard` en `_DashboardContent` con 2 cards nuevas que
  son **interactivas** (envueltas en `InkWell`) y muestran 3 estados posibles:
  valor numérico, aviso "sin configurar" o error.
- Se reutilizan los repositorios existentes `DeliveryNotesRepository` e
  `InvoicesRepository` para obtener los datos y filtrar por fecha = hoy
  client-side.
- No se introducen nuevas dependencias externas.
- Principales áreas impactadas: `lib/features/home/` (nuevo cubit + estados +
  cambios en la page y widget), `lib/app/di/modules/home_module.dart`,
  `lib/app/localization/`.
- Riesgo general estimado: **bajo** — cambio localizado que reutiliza
  infraestructura existente.

## 2) Contexto técnico observado

### Arquitectura y patrones

- Clean Architecture feature-first con BLoC/Cubit, GetIt, fpdart.
- `DashboardCubit` existente: verifica config de Google Drive → carga stats
  locales → emite `DashboardLoaded(stats)`. Registrado como `registerFactory`
  (una instancia por ciclo de vida de la pantalla).
- `StatCard`: widget stateless, sin soporte de `onTap`. Muestra `label`, `value`
  (String), `icon`, `accentColor`.
- La home page `_DashboardContent` recibe `DashboardStats` y renderiza
  `_buildStatsGrid` con 4 `StatCard` en un `Wrap`.

### Módulos relevantes existentes

- **DeliveryNotesRepository / GetDeliveryNotes**: Devuelve
  `Either<Failure, List<DeliveryNote>>`. Cada `DeliveryNote` tiene
  `date: String?` con formato `"YYYY-MM-DD"` (parseado de `main['date']`).
- **InvoicesRepository / GetInvoices**: Devuelve
  `Either<Failure, List<Invoice>>`. Cada `Invoice` tiene `date: String?` con el
  mismo formato.
- **SettingsRepository**: `getFacturaDirectaConfig()` →
  `Either<Failure, FacturaDirectaConfig?>`. Retorna `null` si no hay config
  guardada.
- **SideMenuCubit**: `selectItem(int index)` para navegar. Índice 6 =
  DeliveryNotes, 7 = Invoices.
- **FacturaDirectaApiDataSource**: Ya hace GET a
  `/{companyId}/deliveryNotes?limit=500` y `/{companyId}/invoices?limit=500`.
  Los repositorios obtienen la config de `SettingsRepository`, configuran el
  token y llaman al datasource.

### Restricciones técnicas

- Los endpoints de FD no soportan filtrado server-side por fecha; el filtro se
  hace client-side.
- La fecha en las entities es `String?` con formato `"YYYY-MM-DD"`.
- El `DashboardCubit` actual no debe modificarse en su lógica de carga para
  evitar acoplar la carga de FD a los datos locales.

## 3) Objetivo técnico

- **Qué debe cambiar:** Añadir un cubit independiente que cargue los contadores
  de FD en paralelo al dashboard local, y ampliar la UI del grid de stats con 2
  cards interactivas.
- **Resultado técnico:** Al abrir el dashboard, se muestran 6 cards; las 2
  nuevas reflejan albaranes y facturas del día actual desde FD, con navegación
  al pulsar.
- **Limitaciones a respetar:** No modificar la lógica del `DashboardCubit`
  existente. No introducir dependencias nuevas. Mantener los 4 stats existentes
  intactos.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Crear un **`FdCountersCubit`** separado en la feature `home` que:

1. Consulta la config de FacturaDirecta vía `SettingsRepository`.
2. Si no hay config → emite estado `FdCountersNotConfigured`.
3. Si hay config → llama en paralelo a `GetDeliveryNotes` y `GetInvoices`.
4. Filtra resultados por `date == todayString` (formato `YYYY-MM-DD`).
5. Emite `FdCountersLoaded(deliveryNotesCount, invoicesCount)`.
6. Si falla cualquier llamada → emite `FdCountersError`.

Este cubit se instancia en `_HomePageState` (junto al `DashboardCubit`
existente) y se proporciona a `_DashboardContent` como un segundo
`BlocProvider`. Ambos cubits se cargan en paralelo, cada uno con su flujo
independiente.

### Componentes / módulos / servicios afectados

| Módulo                                                  | Tipo de cambio                                                             |
| ------------------------------------------------------- | -------------------------------------------------------------------------- |
| `lib/features/home/presentation/bloc/`                  | Crear `FdCountersCubit` + `FdCountersState`                                |
| `lib/features/home/presentation/pages/home_page.dart`   | Instanciar `FdCountersCubit`, proveerlo, consumirlo en `_DashboardContent` |
| `lib/features/home/presentation/widgets/stat_card.dart` | Añadir parámetro opcional `onTap`                                          |
| `lib/app/di/modules/home_module.dart`                   | Registrar `FdCountersCubit` como factory                                   |
| `lib/app/localization/l10n/app_es.arb`                  | Nuevas claves i18n                                                         |

### Contratos e interfaces

#### `FdCountersState` (sealed class)

```dart
sealed class FdCountersState extends Equatable { ... }

final class FdCountersInitial extends FdCountersState { ... }
final class FdCountersLoading extends FdCountersState { ... }
final class FdCountersNotConfigured extends FdCountersState { ... }
final class FdCountersLoaded extends FdCountersState {
  final int deliveryNotesCount;
  final int invoicesCount;
}
final class FdCountersError extends FdCountersState { ... }
```

#### `FdCountersCubit`

```dart
class FdCountersCubit extends Cubit<FdCountersState> {
  FdCountersCubit({
    required SettingsRepository settingsRepository,
    required GetDeliveryNotes getDeliveryNotes,
    required GetInvoices getInvoices,
  });

  Future<void> load() async { ... }
}
```

No se crean nuevos repositorios, use cases ni datasources. Se reutilizan
`GetDeliveryNotes` y `GetInvoices` ya registrados como singletons en GetIt.

### Flujo de datos o de control

```
HomePage.initState()
├─ DashboardCubit.load()     ← existente, sin cambios
└─ FdCountersCubit.load()    ← NUEVO, en paralelo
     │
     ├─ SettingsRepository.getFacturaDirectaConfig()
     │   ├─ null / failure → emit(FdCountersNotConfigured)
     │   └─ config exists →
     │       ├─ GetDeliveryNotes(NoParams)
     │       │   └─ DeliveryNotesRepository.getDeliveryNotes()
     │       │       └─ FacturaDirectaApiDataSource.getDeliveryNotes(companyId)
     │       ├─ GetInvoices(NoParams)
     │       │   └─ InvoicesRepository.getInvoices()
     │       │       └─ FacturaDirectaApiDataSource.getInvoices(companyId)
     │       └─ Filter both lists: .where(e.date == todayStr).length
     │           ├─ success → emit(FdCountersLoaded(dnCount, invCount))
     │           └─ any failure → emit(FdCountersError)
     │
_DashboardContent._buildStatsGrid()
├─ 4 StatCard existentes ← sin cambios
├─ BlocBuilder<FdCountersCubit, FdCountersState>
│   ├─ FdCountersLoading → 2 StatCard con "—"
│   ├─ FdCountersNotConfigured → 2 StatCard con aviso "Sin configurar"
│   ├─ FdCountersLoaded → 2 StatCard con valores + onTap → SideMenuCubit
│   └─ FdCountersError → 2 StatCard con "Error"
```

### Gestión de errores y validaciones

| Escenario                                   | Fuente del error                      | Estado en cubit           | Presentación                                               |
| ------------------------------------------- | ------------------------------------- | ------------------------- | ---------------------------------------------------------- |
| Sin config FD                               | `SettingsRepository` retorna `null`   | `FdCountersNotConfigured` | Card con icono ⚠ y texto i18n "Sin configurar"             |
| Config parcial (falta apiToken o companyId) | `ConfigNotFoundFailure` en repository | `FdCountersNotConfigured` | Mismo aviso                                                |
| Error de red / timeout                      | `NetworkFailure`                      | `FdCountersError`         | Card con texto i18n "Error"                                |
| Credenciales inválidas (401/403)            | `ServerFailure`                       | `FdCountersError`         | Card con texto i18n "Error"                                |
| 0 albaranes/facturas hoy                    | Sin error                             | `FdCountersLoaded(0, 0)`  | Card con "0"                                               |
| Dashboard local falla                       | `DashboardError`                      | No renderizado            | Cards de FD no se muestran (vista error pantalla completa) |

### Consideraciones de compatibilidad o migración

- No hay migración de datos.
- No hay cambios en la API de FacturaDirecta.
- Los repositorios `DeliveryNotesRepository` e `InvoicesRepository` ya están
  registrados como singletons en GetIt; se reutilizan directamente.
- El `StatCard` recibe un nuevo parámetro opcional `onTap`; al ser opcional y
  defaulting a `null`, no rompe ningún uso existente.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                    | Propósito                            |
| ------------------------------------------------------------ | ------------------------------------ |
| `lib/features/home/presentation/bloc/fd_counters_cubit.dart` | Cubit que carga los contadores de FD |
| `lib/features/home/presentation/bloc/fd_counters_state.dart` | Estados sealed del cubit             |

### Artefactos a modificar

| Artefacto                                               | Cambio esperado                                                                                                                                                                                                                 |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/home/presentation/widgets/stat_card.dart` | Añadir parámetro opcional `VoidCallback? onTap`; envolver el `Container` en `InkWell` cuando `onTap != null`                                                                                                                    |
| `lib/features/home/presentation/pages/home_page.dart`   | Instanciar `FdCountersCubit` en `_HomePageState.initState()`, cerrarlo en `dispose()`, proveerlo con `BlocProvider`, consumirlo en `_DashboardContent._buildStatsGrid()` con un `BlocBuilder` para renderizar las 2 cards de FD |
| `lib/app/di/modules/home_module.dart`                   | Registrar `FdCountersCubit` como `registerFactory` con dependencias: `SettingsRepository`, `GetDeliveryNotes`, `GetInvoices`                                                                                                    |
| `lib/app/localization/l10n/app_es.arb`                  | Añadir ~5 claves: `dashboardDeliveryNotes`, `dashboardInvoices`, `dashboardFdNotConfigured`, `dashboardFdError`, `dashboardFdLoading`                                                                                           |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo |
| --------- | ------ |
| Ninguno   | —      |

## 6) Estrategia de implementación

1. **Paso 1 — Crear `FdCountersState`**
   - Crear `fd_counters_state.dart` con la sealed class y los 5 estados.

2. **Paso 2 — Crear `FdCountersCubit`**
   - Crear `fd_counters_cubit.dart`.
   - Inyectar `SettingsRepository`, `GetDeliveryNotes`, `GetInvoices`.
   - Implementar `load()`: verificar config → llamar use cases en paralelo →
     filtrar por fecha hoy → emitir estado.

3. **Paso 3 — Registrar en DI**
   - Añadir `FdCountersCubit` como `registerFactory` en `home_module.dart`.
   - Las dependencias (`GetDeliveryNotes`, `GetInvoices`, `SettingsRepository`)
     ya están registradas.

4. **Paso 4 — Añadir `onTap` al `StatCard`**
   - Añadir parámetro `VoidCallback? onTap` al constructor.
   - Envolver el `Container` raíz en un `InkWell` (o `GestureDetector` +
     `Material`) con `borderRadius` para ripple.

5. **Paso 5 — Integrar en `home_page.dart`**
   - En `_HomePageState`: instanciar `_fdCubit = sl<FdCountersCubit>()`, llamar
     `_fdCubit.load()` en `initState`, cerrar en `dispose`.
   - Recargar `_fdCubit.load()` en `_onMenuChanged` (cuando se vuelve al home).
   - Proveer con `MultiBlocProvider` o un segundo `BlocProvider.value`.
   - En `_DashboardContent._buildStatsGrid()`: añadir un `BlocBuilder` para
     `FdCountersCubit` que renderice las 2 cards según el estado.
   - La navegación al pulsar: `context.read<SideMenuCubit>().selectItem(6)` y
     `selectItem(7)`.

6. **Paso 6 — Añadir claves i18n**
   - Añadir las claves al ARB y ejecutar `flutter gen-l10n`.

### Orden recomendado

Paso 1 → Paso 2 → Paso 3 → Paso 4 → Paso 5 → Paso 6

### Dependencias entre pasos

- Paso 2 depende de Paso 1 (necesita los estados).
- Paso 5 depende de Pasos 2, 3 y 4 (necesita el cubit registrado y el `StatCard`
  con `onTap`).
- Paso 4 es independiente de Pasos 1-3 y puede hacerse en paralelo.
- Paso 6 puede hacerse junto con Paso 5.

### Puntos delicados

- **Filtrado por fecha:** La fecha en las entities es `String?` con formato
  `"YYYY-MM-DD"`. El cubit debe construir `todayStr` con el mismo formato
  (`DateTime.now()` → `'${y}-${m.padLeft(2,'0')}-${d.padLeft(2,'0')}'`) y
  comparar con `entity.date?.startsWith(todayStr)` o igualdad directa. Verificar
  en la respuesta real de la API que el formato es consistente (podría incluir
  hora, ej. `"2026-05-08T10:30:00"`), en cuyo caso usar `startsWith`.
- **Acceso al `SideMenuCubit` desde `_DashboardContent`:** El `SideMenuCubit` se
  provee más arriba en el widget tree (`SideMenuShell`). `_DashboardContent`
  puede acceder con `context.read<SideMenuCubit>()` siempre que el
  `BlocProvider` de `SideMenuCubit` sea ancestro. Verificar que el `context` que
  recibe la card tiene acceso a él. Si no, pasar un callback `onNavigate` desde
  `HomePage`.
- **Cierre del cubit:** El `FdCountersCubit` se crea como factory en `initState`
  y debe cerrarse en `dispose()`, igual que el `DashboardCubit` existente.

## 7) Estrategia de validación

### Verificación automática (tests unitarios)

| Componente        | Test                                                                                                                                                                                                                                                           |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FdCountersCubit` | Mock de `SettingsRepository`, `GetDeliveryNotes`, `GetInvoices`. Verificar: `load()` sin config → `NotConfigured`; con config y datos → `Loaded` con conteo correcto filtrado por hoy; con config y error → `Error`; con datos sin fecha hoy → `Loaded(0, 0)`. |

### Verificación manual

- Dashboard con FD configurada y albaranes/facturas con fecha de hoy → cards
  muestran conteo correcto.
- Dashboard con FD configurada pero sin albaranes/facturas hoy → cards muestran
  "0".
- Dashboard sin configuración de FD → cards muestran "Sin configurar".
- Desconectar red con FD configurada → cards muestran "Error"; los 4 contadores
  locales intactos.
- Pulsar card "Albaranes" → navega a la vista de Albaranes.
- Pulsar card "Facturas" → navega a la vista de Facturas.
- Pulsar card con aviso "Sin configurar" → navega igualmente a la sección
  correspondiente.

### Escenarios de test relevantes

- Config FD ausente → `FdCountersNotConfigured`.
- Config FD presente, ambas APIs devuelven datos con fecha hoy →
  `FdCountersLoaded(n, m)` donde n y m son los conteos filtrados.
- Config FD presente, APIs devuelven datos pero ninguno con fecha hoy →
  `FdCountersLoaded(0, 0)`.
- Config FD presente, `GetDeliveryNotes` falla → `FdCountersError`.
- Config FD presente, `GetInvoices` falla → `FdCountersError`.
- Config FD presente, ambas APIs fallan → `FdCountersError`.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                                                  | Probabilidad | Impacto                                                                           |
| ------------------------------------------------------------------------------------------------------- | ------------ | --------------------------------------------------------------------------------- |
| El formato de fecha de la API incluye hora (`"2026-05-08T..."`) en vez de solo `"2026-05-08"`           | Media        | Bajo — usar `startsWith` en vez de igualdad                                       |
| La carga de todos los albaranes/facturas solo para contar los de hoy es ineficiente con volúmenes altos | Media        | Bajo — aceptable para MVP; optimizable con filtro server-side en iteración futura |
| El `SideMenuCubit` no es accesible desde el context de `_DashboardContent`                              | Baja         | Bajo — se resuelve pasando un callback                                            |

### Impacto potencial

- Solo la feature `home` se modifica sustancialmente.
- El `StatCard` recibe un parámetro opcional; todos los usos existentes (sin
  `onTap`) siguen funcionando sin cambios.
- No se tocan features de FD (delivery_notes, invoices) ni Settings.

### Mitigación

- Usar `startsWith(todayStr)` en vez de igualdad exacta para el filtro de fecha,
  cubriendo ambos formatos posibles.
- Si el rendimiento es un problema, se puede crear un endpoint con filtro de
  fecha o agregar un `limit` con parámetro de fecha en una iteración futura.

### Plan de rollback

- Revertir los commits en orden inverso.
- Los artefactos nuevos (`fd_counters_cubit.dart`, `fd_counters_state.dart`) son
  aditivos; eliminarlos y revertir los cambios en `home_page.dart`,
  `stat_card.dart`, `home_module.dart` y ARB restaura el estado original.

## 9) Suposiciones

- Los use cases `GetDeliveryNotes` y `GetInvoices` ya están registrados como
  singletons en GetIt (confirmado en `delivery_notes_module.dart` y
  `invoices_module.dart`).
- El `SideMenuCubit` es accesible desde el context de `_DashboardContent` porque
  se provee en `SideMenuShell` que es ancestro de `HomePage`.
- La fecha en la API de FacturaDirecta usa formato `"YYYY-MM-DD"` o
  `"YYYY-MM-DDTHH:MM:SS"`.
- No se requiere caché; los contadores se recargan cada vez que se accede al
  dashboard.

## 10) Preguntas abiertas

- Ninguna. Todas las cuestiones fueron resueltas en el análisis funcional.

## 11) Notas para implementación

- **No modificar `DashboardCubit`**: El nuevo `FdCountersCubit` es completamente
  independiente. Se instancia, carga y cierra por separado.
- **Patrón de instanciación:** Seguir el mismo patrón que `DashboardCubit` en
  `_HomePageState`: `late final`, crear en `initState` con `sl<>()`, llamar
  `load()`, cerrar en `dispose()`.
- **Recarga al volver al Home:** En `_onMenuChanged`, cuando
  `state.selectedIndex == _kHomeIndex`, llamar también `_fdCubit.load()` para
  refrescar los contadores.
- **Formato de fecha para filtro:** Construir la fecha de hoy con:
  ```dart
  final now = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  ```
  Y filtrar con `entity.date?.startsWith(todayStr) == true`.
- **Widget tree:** Usar `MultiBlocProvider` en `HomePage.build()` para proveer
  tanto `DashboardCubit` como `FdCountersCubit`, o anidar dos
  `BlocProvider.value`.
- **Cards de FD en el grid:** Añadirlas dentro del `Wrap` existente en
  `_buildStatsGrid`, después de las 4 cards actuales. Usar un `BlocBuilder`
  inline para `FdCountersCubit`.
- **Secuencia sugerida:** Implementar Pasos 1-3 primero (cubit + DI), luego Paso
  4 (StatCard onTap), luego Paso 5 (integración en home), luego Paso 6 (i18n).
- **Estado: Listo para implementación**
