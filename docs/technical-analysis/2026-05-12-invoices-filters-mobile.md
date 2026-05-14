# Technical Analysis: Filtros avanzados y vista mobile en Facturas

- **Fecha:** 2026-05-12
- **Identificador:** invoices-filters-mobile
- **Fuente:** docs/functional-analysis/2026-05-12-invoices-filters-mobile.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Rediseñar `InvoicesState` para soportar filtros multidimensionales (fechas,
  estados, clientes) y carga progresiva, eliminando la paginación clásica.
- Refactorizar `InvoicesCubit` para usar `GetInvoicesByDateRange` como carga por
  defecto (últimos 7 días), aplicar filtros client-side (estado, cliente, texto
  libre) y soportar carga acumulativa cuando la API devuelve 500 resultados.
- Crear `InvoiceFiltersDialog` (dialog de filtros), `InvoiceCard` (card mobile),
  y reestructurar `InvoicesPage` con layout responsive desktop/mobile siguiendo
  el patrón de `ProductsPage` y `ClientsPage`.
- Principales áreas impactadas: `invoices/presentation/`, `invoices_module.dart`
  (DI), claves i18n.
- Riesgo general estimado: **medio** — cambios significativos en estado y
  presentación, pero el patrón ya está probado en otros módulos.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC (Cubit), GetIt, fpdart.
- Patrón mobile responsive consolidado en `ProductsPage` y `ClientsPage`:
  detección por `AppSideMenu.mobileBreakpoint` (768 px),
  `_buildDesktopLayout`/`_buildMobileLayout`, `_buildSearchField` compartido con
  parámetro `onPrimary`, card widgets independientes.

### Módulos relevantes

- `InvoicesCubit` — carga con `GetInvoices` (sin rango), filtro texto libre
  (`filterByClient`), paginación (`goToPage`, `changePageSize`).
- `InvoicesLoaded` — contiene `allInvoices`, `filteredInvoices`, `clientFilter`,
  `currentPage`, `pageSize` + getters `totalPages`, `pageItems`.
- `InvoicesRepository` — ya expone `getInvoices()` y
  `getInvoicesByDateRange(minDate, maxDate)`.
- `FacturaDirectaApiDataSourceImpl` — usa `limit: 500` en las llamadas. El proxy
  pasa `queryParameters` tal cual a la API de FD.
- `InvoiceStatusChip` — reconoce 5 estados: `paid`, `pending`, `overdue`,
  `draft`, `voided`.
- `PaginationFooter` — solo se usa en `InvoicesPage`. Se eliminará de esta
  pantalla.

### Restricciones

- La API de Factura Directa devuelve máximo 500 items por petición. Se asume que
  soporta el parámetro `start` para paginación offset-based (PA-04 pendiente de
  verificación; si no lo soporta, la carga progresiva se omitirá en la primera
  iteración).
- Filtros de estado y cliente no están soportados server-side; se aplican
  client-side.
- `InvoicesCubit` recibe `SettingsRepository` solo para `pageSize`. Al eliminar
  la paginación, esta dependencia se eliminará.

### Dependencias/integraciones

- `GetInvoicesByDateRange` y `DateRangeParams` ya registrados en DI
  (`invoices_module.dart`).
- i18n: ya existen claves `invoiceStatusPaid`, `invoiceStatusPending`,
  `invoiceStatusOverdue`, `invoiceStatusDraft`, `invoiceStatusVoided`,
  `invoicesSearchClient`, `invoicesEmpty`, y todas las claves de columna.

## 3) Objetivo técnico

- **Qué debe cambiar:** La carga, filtrado, estado y presentación de facturas.
- **Resultado técnico:** `InvoicesCubit` carga por rango de fechas, gestiona
  filtros compound (fechas server-side + estado/cliente/texto client-side),
  soporta carga progresiva. `InvoicesPage` muestra botón filtrar + chips +
  layout responsive desktop/mobile sin paginación clásica.
- **Limitaciones:** No se modifica la capa domain/data (repositorio, entidad,
  DTOs) salvo para añadir soporte de `start` (offset) en la API si se confirma
  que lo soporta.

## 4) Diseño técnico de la solución

### Enfoque propuesto

#### 4.1 Modelo de filtros

Crear una clase inmutable `InvoiceFilters` en `invoices_state.dart`:

```dart
class InvoiceFilters extends Equatable {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Set<String> statuses;   // ej: {'paid', 'pending'}
  final Set<String> clients;    // contactName values
  final String textQuery;       // búsqueda libre

  // Factory con defaults (últimos 7 días)
  factory InvoiceFilters.defaultFilters() => InvoiceFilters(
    dateFrom: DateTime.now().subtract(Duration(days: 7)),
    dateTo: DateTime.now(),
  );
}
```

#### 4.2 Rediseño de `InvoicesState`

```dart
class InvoicesLoaded extends InvoicesState {
  final List<Invoice> allInvoices;       // acumulado de todas las páginas API
  final List<Invoice> filteredInvoices;  // resultado tras filtros client-side
  final InvoiceFilters filters;
  final bool hasMore;                    // true si última página devolvió 500
  final bool isLoadingMore;              // true mientras carga siguiente página
}
```

Eliminar: `clientFilter`, `currentPage`, `pageSize`, `totalPages`, `pageItems`.

#### 4.3 Refactorización de `InvoicesCubit`

- **Constructor:** Reemplazar `GetInvoices` + `SettingsRepository` por
  `GetInvoices` + `GetInvoicesByDateRange`. Eliminar dependencia de
  `SettingsRepository`.
- **`loadInvoices({InvoiceFilters? filters})`:** Carga inicial o recarga cuando
  cambian las fechas.
  - Si `filters.dateFrom` y `filters.dateTo` existen → usar
    `GetInvoicesByDateRange`.
  - Si alguna fecha falta → usar `GetInvoices` (carga completa).
  - Guardar `hasMore = items.length == 500`.
  - Aplicar filtros client-side antes de emitir.
- **`loadMore()`:** Si `hasMore`, solicitar siguiente página con
  `start = allInvoices.length`. Acumular resultados. Re-aplicar filtros
  client-side.
- **`applyFilters(InvoiceFilters newFilters)`:** Si las fechas cambiaron →
  `loadInvoices`. Si solo cambiaron estado/cliente/texto → re-filtrar
  client-side sin llamar API.
- **`removeFilter(tipo, valor)`:** Actualizar `filters` y re-evaluar (si se
  eliminó fecha → nueva llamada API).
- **`clearAllFilters()`:** Resetear a `InvoiceFilters()` vacío (sin fechas) →
  llamar `getInvoices()`.
- **`filterByText(String query)`:** Mantener la funcionalidad actual
  refactorizada.
- **Eliminar:** `goToPage()`, `changePageSize()`.

**Lógica de filtrado client-side** (método privado `_applyClientSideFilters`):

```
filteredInvoices = allInvoices.where((invoice) {
  if (filters.statuses.isNotEmpty && !filters.statuses.contains(invoice.status?.toLowerCase())) → excluir
  if (filters.clients.isNotEmpty && !filters.clients.contains(invoice.contactName)) → excluir
  if (filters.textQuery.isNotEmpty) → aplicar búsqueda en docNumber, contactName, subtotal, total
  return true;
}).toList();
```

#### 4.4 Capa data — Soporte de offset (condicional)

Si se confirma que la API soporta `start`:

- Añadir parámetro opcional `start` a `getInvoicesByDateRange` y `getInvoices`
  en el data source abstracto e implementación.
- Pasar `'start': '$start'` en `queryParameters`.

Si la API **no** soporta `start`:

- Omitir `loadMore()` y `hasMore` en la primera iteración. Se muestra todo lo
  que devuelve la primera petición (hasta 500).

#### 4.5 DI — `invoices_module.dart`

Cambiar el `InvoicesCubit` factory:

```dart
// Antes: InvoicesCubit(sl(), sl())  → GetInvoices, SettingsRepository
// Después: InvoicesCubit(sl(), sl()) → GetInvoices, GetInvoicesByDateRange
```

#### 4.6 `InvoiceFiltersDialog` (nuevo widget)

- Recibe `InvoiceFilters currentFilters` y `List<String> availableClients`.
- Layout del dialog:
  - **Estado:** `Wrap` de `FilterChip` para cada uno de los 5 estados
    (multi-select).
  - **Clientes:** Lista scrollable con `CheckboxListTile` para cada cliente. Con
    campo de búsqueda para filtrar en la lista.
  - **Fecha desde / Fecha hasta:** Cada uno con un `TextFormField` readOnly +
    `IconButton` de calendario que abre `showDatePicker`.
  - **Botones:** "Limpiar filtros" (TextButton), "Cancelar" (OutlinedButton),
    "Aplicar" (FilledButton).
- Validación: fecha desde ≤ fecha hasta (si ambas definidas). Si no se cumple,
  deshabilitar "Aplicar" y mostrar error inline.
- Devuelve `InvoiceFilters?` — `null` si cancela.
- Responsive: en mobile usa `insetPadding` reducido (patrón de
  `FdProductSelectorDialog`).

#### 4.7 `InvoiceCard` (nuevo widget)

Siguiendo el patrón de `ClientCard` y `ProductCard`:

```
Card(
  elevation: AppElevation.low,
  shape: RoundedRectangleBorder(borderRadius, side),
  child: Padding(
    child: Column([
      Row([docNumber, date]),        // header
      Text(contactName),              // nombre cliente
      InvoiceStatusChip(status),      // chip de estado
      Row([subtotalText, totalText]), // importes
    ]),
  ),
)
```

#### 4.8 Reestructuración de `InvoicesPage`

Siguiendo el patrón de `ProductsPage` y `ClientsPage`:

- **`build()`:** Detectar `isMobile` → delegar a `_buildDesktopLayout` o
  `_buildMobileLayout`.
- **`_buildDesktopLayout`:** `PageHeader` + barra búsqueda (search + botón
  filtrar) + chips de filtros + tabla + botón "Cargar más" (si `hasMore`).
- **`_buildMobileLayout`:** `_buildMobileSearchBar` (con fondo
  `colorScheme.primary` y botón filtrar) + chips de filtros + lista de
  `InvoiceCard` con infinite scroll (si `hasMore`).
- **`_buildSearchField`:** Widget compartido con parámetro `onPrimary` (misma
  lógica que en `ProductsPage`).
- **`_buildFilterChips`:** `SingleChildScrollView(scrollDirection: horizontal)`
  con `Chip`s para cada filtro activo. Cada chip tiene `onDeleted` →
  `_cubit.removeFilter(...)`.
- **`_buildContent`:** Unificado con parámetro `isMobile` — renderiza tabla o
  cards.
- **Tabla desktop:** Usar `_buildTable(state.filteredInvoices, ...)`
  directamente (sin `pageItems`). Al final, si `state.hasMore`, mostrar botón
  "Cargar más" centrado.
- **Cards mobile:** `ListView.builder` con `ScrollController` para detectar
  scroll near-end → `_cubit.loadMore()`.
- **Eliminar:** import y uso de `PaginationFooter`, referencia a `pageItems`,
  `goToPage`, `changePageSize`.

### Componentes / módulos / servicios afectados

| Capa                 | Artefacto                                | Tipo de cambio               |
| -------------------- | ---------------------------------------- | ---------------------------- |
| Presentation         | `InvoicesPage`                           | Reestructuración completa    |
| Presentation         | `InvoicesCubit`                          | Refactorización de lógica    |
| Presentation         | `InvoicesState`                          | Rediseño de modelo de estado |
| Presentation         | `InvoiceFiltersDialog`                   | Nuevo                        |
| Presentation         | `InvoiceCard`                            | Nuevo                        |
| DI                   | `invoices_module.dart`                   | Ajuste de dependencias       |
| i18n                 | `app_es.arb`                             | Nuevas claves                |
| Data (condicional)   | `FacturaDirectaApiDataSource` + impl     | Parámetro `start` opcional   |
| Data (condicional)   | `InvoicesRepository` + impl              | Parámetro `start` opcional   |
| Domain (condicional) | `GetInvoicesByDateRange` / `GetInvoices` | Soporte de offset            |

### Contratos e interfaces

**`InvoiceFilters`** — Clase de valor inmutable (Equatable):

- `DateTime? dateFrom`
- `DateTime? dateTo`
- `Set<String> statuses`
- `Set<String> clients`
- `String textQuery`
- `factory InvoiceFilters.defaultFilters()`
- `InvoiceFilters copyWith(...)`
- `bool get hasActiveFilters`
- `bool get hasDateFilters`

**`InvoicesCubit` — API pública nueva:**

- `loadInvoices({InvoiceFilters? filters})` — reemplaza el actual
  `loadInvoices()`
- `applyFilters(InvoiceFilters filters)` — aplica desde dialog
- `removeStatusFilter(String status)`
- `removeClientFilter(String client)`
- `removeDateFromFilter()`
- `removeDateToFilter()`
- `clearAllFilters()`
- `filterByText(String query)` — renombrado desde `filterByClient`
- `loadMore()` — carga progresiva

**`InvoiceFiltersDialog`** — retorna `InvoiceFilters?`:

- Params: `InvoiceFilters currentFilters`, `List<String> availableClients`

### Flujo de datos o de control

```
Usuario abre pantalla
  → InvoicesCubit.loadInvoices(filters: InvoiceFilters.defaultFilters())
  → GetInvoicesByDateRange(minDate: hoy-7d, maxDate: hoy)
  → API FD: GET /invoices?minDate=X&maxDate=X&related=state&limit=500
  → InvoicesLoaded(allInvoices, filteredInvoices, filters, hasMore)
  → UI renderiza tabla/cards + chips de fecha

Usuario pulsa Filtrar
  → Abre InvoiceFiltersDialog(currentFilters, availableClients)
  → Usuario modifica filtros → pulsa Aplicar
  → InvoicesCubit.applyFilters(newFilters)
  → Si fechas cambiaron → loadInvoices(filters: newFilters) → API call
  → Si solo estado/cliente → _applyClientSideFilters() → emit
  → UI actualiza tabla/cards + chips

Usuario elimina chip
  → InvoicesCubit.removeXxxFilter(...)
  → Re-evalúa si necesita API call o solo client-side
  → Emit nuevo estado

Usuario scroll/pulsa "Cargar más" (si hasMore)
  → InvoicesCubit.loadMore()
  → API FD con start=currentCount
  → Acumula a allInvoices, re-aplica filtros client-side
  → Emit con hasMore actualizado
```

### Gestión de errores y validaciones

- **Error de API** (cambio de fechas): Se emite `InvoicesError` igual que
  actualmente. El botón "Reintentar" llama a `loadInvoices()` con los últimos
  filtros activos.
- **Error de carga progresiva**: Se emite un estado transitorio de error sin
  perder los datos ya cargados. Se puede reintentar `loadMore()`.
- **Validación en dialog**: Fecha desde > fecha hasta → deshabilitar botón
  "Aplicar", mostrar mensaje inline.
- **contactName null/vacío**: Se excluye del selector de clientes en el dialog.

### Consideraciones de compatibilidad o migración

- `PaginationFooter` deja de usarse en `InvoicesPage` pero el widget sigue
  disponible en `core/presentation/widgets/` por si se usa en el futuro. No se
  elimina.
- La dependencia de `SettingsRepository` en `InvoicesCubit` se elimina. Si se
  usa en tests, actualizar.
- Los tests existentes de `InvoicesCubit` necesitarán refactorización para el
  nuevo constructor y estado.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                | Propósito                                                 |
| ------------------------------------------------------------------------ | --------------------------------------------------------- |
| `lib/features/invoices/presentation/widgets/invoice_filters_dialog.dart` | Dialog con filtros de estado, clientes, fecha desde/hasta |
| `lib/features/invoices/presentation/widgets/invoice_card.dart`           | Card de factura para layout mobile                        |

### Artefactos a modificar

| Artefacto                                                               | Cambio esperado                                                                                                                          |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/invoices/presentation/bloc/invoices_state.dart`           | Añadir `InvoiceFilters`, rediseñar `InvoicesLoaded` (eliminar paginación, añadir filtros + hasMore + isLoadingMore)                      |
| `lib/features/invoices/presentation/bloc/invoices_cubit.dart`           | Cambiar constructor (reemplazar `SettingsRepository` por `GetInvoicesByDateRange`), añadir métodos de filtrado, eliminar paginación      |
| `lib/features/invoices/presentation/pages/invoices_page.dart`           | Reestructurar con layout responsive desktop/mobile, botón filtrar, chips, eliminar PaginationFooter, añadir "Cargar más"/infinite scroll |
| `lib/app/di/modules/invoices_module.dart`                               | Cambiar factory de InvoicesCubit: reemplazar `sl<SettingsRepository>()` por `sl<GetInvoicesByDateRange>()`                               |
| `lib/app/localization/l10n/app_es.arb`                                  | Añadir ~15 nuevas claves i18n                                                                                                            |
| `lib/core/data/datasources/factura_directa_api_data_source.dart`        | (condicional) Añadir param `start` a `getInvoices` y `getInvoicesByDateRange`                                                            |
| `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`   | (condicional) Pasar `start` en queryParameters                                                                                           |
| `lib/features/invoices/data/repositories/invoices_repository_impl.dart` | (condicional) Pasar `start`                                                                                                              |
| `lib/features/invoices/domain/repositories/invoices_repository.dart`    | (condicional) Añadir param `start`                                                                                                       |
| `lib/features/invoices/domain/usecases/get_invoices_by_date_range.dart` | (condicional) Añadir `start` a `DateRangeParams`                                                                                         |
| `lib/features/invoices/domain/usecases/get_invoices.dart`               | (condicional) Añadir `start` a params                                                                                                    |

### Artefactos a retirar o reemplazar

| Artefacto         | Motivo                                                                         |
| ----------------- | ------------------------------------------------------------------------------ |
| Ninguno eliminado | `PaginationFooter` deja de usarse en esta pantalla pero se mantiene en el core |

## 6) Estrategia de implementación

### Paso 1 — Claves i18n

Añadir las nuevas claves al archivo ARB:

| Clave                         | Valor ES                                      |
| ----------------------------- | --------------------------------------------- |
| `invoicesFilter`              | `Filtrar`                                     |
| `invoicesFilterTitle`         | `Filtros`                                     |
| `invoicesFilterStatus`        | `Estado`                                      |
| `invoicesFilterClients`       | `Clientes`                                    |
| `invoicesFilterDateFrom`      | `Desde`                                       |
| `invoicesFilterDateTo`        | `Hasta`                                       |
| `invoicesFilterApply`         | `Aplicar`                                     |
| `invoicesFilterClear`         | `Limpiar filtros`                             |
| `invoicesFilterDateError`     | `Fecha desde debe ser anterior a fecha hasta` |
| `invoicesFilterSearchClients` | `Buscar cliente...`                           |
| `invoicesLoadMore`            | `Cargar más`                                  |
| `invoicesLoadingMore`         | `Cargando más facturas...`                    |
| `invoicesFilterChipFrom`      | `Desde: {date}`                               |
| `invoicesFilterChipTo`        | `Hasta: {date}`                               |

### Paso 2 — Rediseñar `InvoicesState`

- Crear clase `InvoiceFilters` con `defaultFilters()`, `copyWith`,
  `hasActiveFilters`.
- Rediseñar `InvoicesLoaded`: eliminar campos de paginación, añadir `filters`,
  `hasMore`, `isLoadingMore`.
- Mantener `InvoicesInitial`, `InvoicesLoading`, `InvoicesError` sin cambios.

### Paso 3 — Refactorizar `InvoicesCubit`

- Cambiar constructor: `InvoicesCubit(GetInvoices, GetInvoicesByDateRange)`.
- Implementar `loadInvoices`, `applyFilters`, `removeXxxFilter`,
  `clearAllFilters`, `filterByText`, `loadMore`.
- Eliminar `goToPage`, `changePageSize` y dependencia de `SettingsRepository`.

### Paso 4 — Actualizar DI (`invoices_module.dart`)

- Cambiar factory:
  `InvoicesCubit(sl<GetInvoices>(), sl<GetInvoicesByDateRange>())`.

### Paso 5 — Crear `InvoiceFiltersDialog`

- Implementar dialog con los 4 campos de filtro, botón limpiar, validación de
  fechas.

### Paso 6 — Crear `InvoiceCard`

- Implementar card mobile siguiendo patrón de `ClientCard`/`ProductCard`.

### Paso 7 — Reestructurar `InvoicesPage`

- Layout responsive desktop/mobile.
- Barra de búsqueda + botón filtrar.
- Chips de filtros activos.
- Tabla (desktop) / cards (mobile).
- Botón "Cargar más" (desktop) / infinite scroll (mobile).
- Eliminar `PaginationFooter`.

### Paso 8 (condicional) — Soporte de `start` en data layer

- Solo si se confirma que la API soporta offset. Si no, omitir `loadMore` y
  `hasMore` en esta iteración.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

### Dependencias entre pasos

- Paso 2 es prerequisito de 3 y 7.
- Paso 3 es prerequisito de 7.
- Paso 5 y 6 son independientes entre sí pero necesarios para 7.
- Paso 8 es independiente y puede hacerse al final o en paralelo.

### Puntos delicados

- **Constructor de `InvoicesCubit`:** El cambio de dependencias afecta al DI y a
  los tests. Ejecutar los pasos 3 y 4 juntos.
- **Orden de sort:** Actualmente `getInvoices()` ordena por fecha descendente en
  el repositorio pero `getInvoicesByDateRange()` no. Unificar el sort en el
  cubit o en el repositorio.
- **Acumulación en `loadMore`:** Al acumular resultados de múltiples páginas,
  los filtros client-side deben re-aplicarse sobre el total acumulado, no solo
  sobre la nueva página.
- **Recálculo de `availableClients`:** La lista de clientes disponibles en el
  dialog depende de `allInvoices`. Si se cambian las fechas y se recargan datos,
  esta lista cambia. El dialog debe recibir la lista actualizada cada vez que se
  abre.

## 7) Estrategia de validación

### Verificación automática

- `flutter analyze lib/features/invoices/presentation/` — sin issues.
- Tests unitarios de `InvoicesCubit`: verificar carga con rango de fechas por
  defecto, aplicación de filtros client-side, carga progresiva, eliminación de
  filtros individuales, limpiar todos los filtros.
- Tests de `InvoiceFilters`: factory `defaultFilters`, `copyWith`,
  `hasActiveFilters`, equality.

### Validación manual

- Desktop: Verificar tabla + botón filtrar + chips + dialog + "Cargar más".
- Mobile (≤ 768 px): Verificar cards + search bar primary + botón filtrar +
  chips + infinite scroll.
- Verificar que los chips de fecha aparecen por defecto al entrar.
- Verificar validación de fechas en el dialog (desde > hasta).
- Verificar combinación de filtros (estado + cliente + texto + fechas).
- Verificar eliminación de chips individuales y "Limpiar filtros".
- Verificar que se llama a la API solo cuando cambian las fechas.

### Escenarios que deben cubrirse

- Carga inicial con filtro de 7 días por defecto.
- Filtrar por 1 estado, por múltiples estados.
- Filtrar por 1 cliente, por múltiples clientes.
- Cambiar rango de fechas → nueva llamada API.
- Eliminar todas las fechas → carga completa.
- Combinación de filtros: estado + cliente + texto.
- Sin resultados tras filtrar → mensaje vacío.
- Error de API → pantalla de error + reintentar.
- Carga progresiva (si aplica): verificar acumulación y re-filtrado.
- Mobile: scroll de chips horizontales cuando hay muchos filtros.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **R-01 (medio):** La API de FD puede no soportar el parámetro `start` para
  offset, bloqueando la carga progresiva.
- **R-02 (bajo):** Rendimiento client-side con >1000 facturas acumuladas y
  filtros complejos.
- **R-03 (bajo):** Cambio de constructor de `InvoicesCubit` puede romper tests
  existentes.

### Impacto potencial

- La pantalla de Facturas cambia completamente su comportamiento de carga y
  filtrado.
- El módulo DI de invoices cambia.
- Los tests existentes del cubit necesitan refactorización.

### Mitigación

- **R-01:** Diseñar `loadMore` como feature opcional. Si la API no soporta
  `start`, simplemente `hasMore` siempre será `false` y no se muestra el
  mecanismo de carga progresiva. Verificar con una llamada de prueba antes de
  implementar.
- **R-02:** 500-1000 facturas con filtrado `where()` en Dart es despreciable
  (<1ms). No requiere optimización.
- **R-03:** Actualizar los tests como parte del paso 3.

### Plan de rollback

- El cambio está contenido en el feature `invoices` (presentación + DI).
  Revertir los commits del feature es suficiente.
- `PaginationFooter` no se elimina del core, por lo que un rollback no rompe
  nada.

## 9) Suposiciones

- Los 5 estados del `InvoiceStatusChip` (`paid`, `pending`, `overdue`, `draft`,
  `voided`) son exhaustivos para el selector de filtros. Estados desconocidos no
  aparecen en el selector pero sus facturas siguen visibles sin filtro de
  estado.
- La API de FD probablemente soporta `start` como parámetro de offset (estándar
  REST). Se verificará en la implementación.
- El `sort` de facturas por fecha descendente se unificará en el cubit tras
  cargar/acumular.

## 10) Preguntas abiertas

- **PA-04 (heredada):** Verificar si la API soporta `start` para paginación
  offset. Si no lo soporta, la carga progresiva se pospone. No es bloqueante
  para el resto del diseño.

## 11) Notas para implementación

- **Restricciones técnicas:** Respetar design tokens del tema (no hardcodear
  colores/tamaños). Usar `AppSpacing`, `AppRadii`, `AppElevation`,
  `AppDimensions`, `AppSideMenu.mobileBreakpoint`. Usar `Theme.of(context)` para
  colores.
- **Secuencia sugerida:** i18n → state → cubit → DI → widgets nuevos → page.
  Esto permite compilar y verificar en cada paso.
- **No romper comportamiento existente:** El search TextField actual debe seguir
  funcionando exactamente igual. Solo se añade funcionalidad (filtros + layout
  mobile).
- **`SettingsRepository`:** Al eliminarla del cubit, verificar que no hay otros
  usos indirectos.
- **Sort:** Actualmente `InvoicesRepositoryImpl.getInvoices()` ordena por fecha
  descendente pero `getInvoicesByDateRange()` no. Mover el sort al cubit o
  unificar en el repo para que ambos sean consistentes.
- **Estado: Listo para implementación**
