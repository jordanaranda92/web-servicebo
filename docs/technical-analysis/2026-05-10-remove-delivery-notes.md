# Technical Analysis: Eliminación completa de la funcionalidad de Albaranes

- **Fecha:** 2026-05-10
- **Identificador:** remove-delivery-notes
- **Fuente:** docs/functional-analysis/2026-05-10-remove-delivery-notes.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Eliminación total de la feature `delivery_notes` (9 archivos), su módulo DI,
  su ítem de navegación, sus métodos en el datasource de API, sus contadores en
  el dashboard y su acción en la toolbar de pedidos.
- Áreas impactadas: `lib/features/delivery_notes/`, `lib/features/home/`,
  `lib/features/orders_today/`, `lib/core/data/datasources/`, `lib/app/di/`,
  `lib/app/localization/`.
- Riesgo general estimado: **bajo** — eliminación pura de código sin lógica
  nueva; el riesgo principal es el reindexado de navegación.

## 2) Contexto técnico observado

- **Arquitectura:** Clean Architecture feature-first con BLoC/Cubit, GetIt para
  DI, fpdart para manejo de errores.
- **Feature `delivery_notes`:** Estructura estándar con `data/` (DTO, repository
  impl), `domain/` (entity, repository interface, use case), `presentation/`
  (cubit, state, page, widgets). 9 archivos.
- **Navegación:** `SideMenuCubit` con `_maxIndex = 8` (9 ítems: índices 0-8).
  `SideMenu` construye la lista de ítems con separadores en índices hardcodeados
  `[0, 2, 5, 7]`. `SideMenuShell._buildPage` usa un `switch` sobre el índice.
- **Dashboard (HomePage):** `FdCountersCubit` depende de `GetDeliveryNotes` y
  `GetInvoices`. `FdCountersLoaded` contiene `deliveryNotesCount`.
  `FdPeriodComparison` contiene `deliveryNotesDiff`. `ComparisonCard` acepta
  `deliveryNotesDiff` y lo renderiza.
- **API datasource:** `FacturaDirectaApiDataSource` (interfaz) y
  `FacturaDirectaApiDataSourceImpl` tienen 3 métodos de albaranes:
  `getDeliveryNotes`, `getDeliveryNoteById`, `createDeliveryNote`.
- **Orders Today:** `OrdersTable` y `OrdersTableToolbar` tienen el callback
  `onGenerateDeliveryNotes`. `OrdersTodayPage` lo conecta como `// TODO`.
- **DI:** `delivery_notes_module.dart` registra repository, use case y cubit.
  `home_module.dart` inyecta `getDeliveryNotes` en `FdCountersCubit`.
  `injection.dart` llama `registerDeliveryNotesModule`.
- **i18n:** ~20 claves en `app_es.arb` relacionadas con delivery notes (prefijos
  `deliveryNotes*`, `deliveryNoteStatus*`, `menuDeliveryNotes`,
  `dashboardDeliveryNotes*`, `ordersTodayGenerateDeliveryNote*`).
- **Tests:** No existen tests unitarios para `delivery_notes`. No hay
  referencias a delivery notes en `test/`.
- **Persistencia de índice:** `SideMenuCubit` no persiste `selectedIndex`
  directamente; el `SideMenuState` inicia con `selectedIndex = 0` por defecto.
  No hay riesgo de índice fuera de rango tras reinicio.

## 3) Objetivo técnico

- Eliminar toda traza de la feature `delivery_notes` del código fuente.
- Reindexar la navegación para que funcione con 8 ítems (0-7).
- Adaptar el dashboard para que no dependa de datos de albaranes.
- Adaptar la toolbar de pedidos para que no ofrezca generar albaranes.
- Mantener intactas las features de Contactos, Productos y Facturas.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Eliminación pura y reindexado. No se introduce lógica nueva ni dependencias. Se
procede de dentro hacia fuera: primero se cortan las dependencias, luego se
eliminan los archivos.

### Componentes / módulos / servicios afectados

| Módulo                                                                     | Tipo de cambio                                                                                                                                                                                          |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/delivery_notes/` (9 archivos)                                | **Eliminar** — carpeta completa                                                                                                                                                                         |
| `lib/app/di/modules/delivery_notes_module.dart`                            | **Eliminar** — archivo                                                                                                                                                                                  |
| `lib/app/di/injection.dart`                                                | **Modificar** — quitar import y llamada a `registerDeliveryNotesModule`                                                                                                                                 |
| `lib/core/data/datasources/factura_directa_api_data_source.dart`           | **Modificar** — quitar 3 métodos                                                                                                                                                                        |
| `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`      | **Modificar** — quitar 3 métodos                                                                                                                                                                        |
| `lib/features/home/presentation/widgets/side_menu.dart`                    | **Modificar** — quitar ítem Albaranes, ajustar separadores                                                                                                                                              |
| `lib/features/home/presentation/pages/side_menu_shell.dart`                | **Modificar** — quitar import y case del switch, reindexar                                                                                                                                              |
| `lib/features/home/presentation/bloc/side_menu_cubit.dart`                 | **Modificar** — `_maxIndex` de 8 a 7                                                                                                                                                                    |
| `lib/features/home/presentation/bloc/fd_counters_cubit.dart`               | **Modificar** — eliminar dependencia de `GetDeliveryNotes` y toda lógica de albaranes                                                                                                                   |
| `lib/features/home/presentation/bloc/fd_counters_state.dart`               | **Modificar** — eliminar `deliveryNotesCount` de `FdCountersLoaded`, eliminar `deliveryNotesDiff` de `FdPeriodComparison`                                                                               |
| `lib/features/home/presentation/pages/home_page.dart`                      | **Modificar** — eliminar constante `_kDeliveryNotesIndex`, ajustar `_kInvoicesIndex` y `_kSettingsIndex`, eliminar tarjeta de albaranes del dashboard, eliminar `deliveryNotesDiff` de `ComparisonCard` |
| `lib/features/home/presentation/widgets/comparison_card.dart`              | **Modificar** — eliminar prop `deliveryNotesDiff` y su fila de métrica                                                                                                                                  |
| `lib/app/di/modules/home_module.dart`                                      | **Modificar** — quitar `getDeliveryNotes: sl()` del constructor de `FdCountersCubit`                                                                                                                    |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`         | **Modificar** — quitar `onGenerateDeliveryNotes` (constructor, field, uso en toolbar)                                                                                                                   |
| `lib/features/orders_today/presentation/widgets/orders_table_toolbar.dart` | **Modificar** — quitar `onGenerateDeliveryNotes` (constructor, field, botón)                                                                                                                            |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart`      | **Modificar** — quitar `onGenerateDeliveryNotes` callback                                                                                                                                               |
| `lib/app/localization/l10n/app_es.arb`                                     | **Modificar** — quitar ~20 claves de delivery notes                                                                                                                                                     |
| `lib/app/localization/l10n/app_localizations.dart` (generado)              | Se regenera automáticamente con `flutter gen-l10n`                                                                                                                                                      |
| `lib/app/localization/l10n/app_localizations_es.dart` (generado)           | Se regenera automáticamente con `flutter gen-l10n`                                                                                                                                                      |

### Contratos e interfaces

**`FacturaDirectaApiDataSource`** — queda con 4 métodos:

```dart
abstract class FacturaDirectaApiDataSource {
  Future<List<Map<String, dynamic>>> getContacts(String companyId);
  Future<List<Map<String, dynamic>>> getProducts(String companyId);
  Future<List<Map<String, dynamic>>> getInvoices(String companyId);
  Future<Map<String, dynamic>> getInvoiceById(String companyId, String id);
}
```

**`FdCountersCubit`** — constructor queda sin `GetDeliveryNotes`:

```dart
FdCountersCubit({
  required SettingsRepository settingsRepository,
  required GetInvoices getInvoices,
})
```

**`FdCountersLoaded`** — pierde `deliveryNotesCount`:

```dart
FdCountersLoaded({
  required this.invoicesCount,
  required this.invoicesTotal,
  ...
})
```

**`FdPeriodComparison`** — pierde `deliveryNotesDiff`:

```dart
FdPeriodComparison({
  required this.invoicesDiff,
  required this.invoicesTotalDiff,
})
```

**`ComparisonCard`** — pierde prop `deliveryNotesDiff`.

**`OrdersTable`** — pierde campo `onGenerateDeliveryNotes`.

**`OrdersTableToolbar`** — pierde campo `onGenerateDeliveryNotes` y el
`FilledButton` asociado.

### Flujo de datos o de control

- `FdCountersCubit.load()`: ya no hace `_getDeliveryNotes(NoParams())`. Solo
  llama a `_getInvoices(NoParams())`. La lógica de comparación se simplifica
  eliminando `allDn`, `todayDn`, `dnCount`, y los parámetros
  `List<DeliveryNote> allDn` de `_compareSingleDay` y `_compareRange`.
- `HomePage._buildFdCounterCards`: eliminar la llamada `_buildFdStatCard` de
  albaranes.
- Todas las `ComparisonCard` en `HomePage._buildComparisonsGrid`: dejan de pasar
  `deliveryNotesDiff`.
- `OrdersTable`: el `OrdersTableToolbar` se construye sin
  `onGenerateDeliveryNotes`, y el bloque condicional que lo invoca desaparece.

### Gestión de errores y validaciones

No se introducen cambios en gestión de errores. Se elimina lógica, no se crea
nueva. El `FdCountersCubit` sigue manejando errores de `getInvoices` como antes.

### Consideraciones de compatibilidad o migración

- `SideMenuState.selectedIndex` inicia en 0 por defecto. No se persiste en
  `SharedPreferences`. No hay riesgo de migración.
- Los archivos ARB generados (`app_localizations.dart`,
  `app_localizations_es.dart`) se regeneran automáticamente con
  `flutter gen-l10n` tras editar `app_es.arb`.

## 5) Impacto por artefactos

### Artefactos a eliminar

| Artefacto                                                                           | Motivo                         |
| ----------------------------------------------------------------------------------- | ------------------------------ |
| `lib/features/delivery_notes/data/dto/delivery_note_dto.dart`                       | Feature eliminada              |
| `lib/features/delivery_notes/data/repositories/delivery_notes_repository_impl.dart` | Feature eliminada              |
| `lib/features/delivery_notes/domain/entities/delivery_note.dart`                    | Feature eliminada              |
| `lib/features/delivery_notes/domain/repositories/delivery_notes_repository.dart`    | Feature eliminada              |
| `lib/features/delivery_notes/domain/usecases/get_delivery_notes.dart`               | Feature eliminada              |
| `lib/features/delivery_notes/presentation/bloc/delivery_notes_cubit.dart`           | Feature eliminada              |
| `lib/features/delivery_notes/presentation/bloc/delivery_notes_state.dart`           | Feature eliminada              |
| `lib/features/delivery_notes/presentation/pages/delivery_notes_page.dart`           | Feature eliminada              |
| `lib/features/delivery_notes/presentation/widgets/delivery_note_status_chip.dart`   | Feature eliminada              |
| `lib/app/di/modules/delivery_notes_module.dart`                                     | Módulo DI de feature eliminada |

### Artefactos a modificar

| Artefacto                                                                  | Cambio esperado                                                                                                                                                                                                                                                                    |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/app/di/injection.dart`                                                | Quitar import y llamada `registerDeliveryNotesModule(sl)`                                                                                                                                                                                                                          |
| `lib/core/data/datasources/factura_directa_api_data_source.dart`           | Quitar 3 métodos de albaranes                                                                                                                                                                                                                                                      |
| `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`      | Quitar 3 métodos de albaranes (~30 líneas)                                                                                                                                                                                                                                         |
| `lib/features/home/presentation/widgets/side_menu.dart`                    | Quitar `_MenuItemData` de Albaranes (índice 6), ajustar separadores de `[0,2,5,7]` a `[0,2,5,6]`                                                                                                                                                                                   |
| `lib/features/home/presentation/pages/side_menu_shell.dart`                | Quitar import `delivery_notes_page.dart`, reindexar switch: `6 → InvoicesPage`, `7 → SettingsPage`, eliminar case 8                                                                                                                                                                |
| `lib/features/home/presentation/bloc/side_menu_cubit.dart`                 | `_maxIndex` de 8 a 7                                                                                                                                                                                                                                                               |
| `lib/features/home/presentation/bloc/fd_counters_cubit.dart`               | Quitar imports de delivery_notes, quitar `_getDeliveryNotes` del constructor y campo, quitar `dnResult` de `load()`, eliminar parámetro `allDn` de `_compareSingleDay` y `_compareRange`, eliminar lógica `todayDn`/`dnCount`                                                      |
| `lib/features/home/presentation/bloc/fd_counters_state.dart`               | Quitar `deliveryNotesCount` de `FdCountersLoaded`, quitar `deliveryNotesDiff` de `FdPeriodComparison`                                                                                                                                                                              |
| `lib/features/home/presentation/pages/home_page.dart`                      | Quitar `_kDeliveryNotesIndex`, cambiar `_kInvoicesIndex` de 7 a 6 y `_kSettingsIndex` de 8 a 7, quitar tarjeta de albaranes de `_buildFdCounterCards`, quitar `deliveryNotesDiff` de cada `ComparisonCard`                                                                         |
| `lib/features/home/presentation/widgets/comparison_card.dart`              | Quitar prop `deliveryNotesDiff`, quitar fila de métrica de albaranes                                                                                                                                                                                                               |
| `lib/app/di/modules/home_module.dart`                                      | Quitar `getDeliveryNotes: sl()` de `FdCountersCubit`                                                                                                                                                                                                                               |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`         | Quitar `onGenerateDeliveryNotes` (constructor, field, doc, uso en toolbar)                                                                                                                                                                                                         |
| `lib/features/orders_today/presentation/widgets/orders_table_toolbar.dart` | Quitar `onGenerateDeliveryNotes` (constructor, field, `FilledButton`)                                                                                                                                                                                                              |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart`      | Quitar `onGenerateDeliveryNotes: (indices) { ... }`                                                                                                                                                                                                                                |
| `lib/app/localization/l10n/app_es.arb`                                     | Eliminar ~20 claves: `dashboardDeliveryNotes`, `dashboardDeliveryNotesLabel`, `menuDeliveryNotes`, `deliveryNotesSearchClient`, `deliveryNotesEmpty`, `deliveryNotesColumn*` (5), `ordersTodayGenerateDeliveryNote`, `ordersTodayGenerateDeliveryNotes`, `deliveryNoteStatus*` (4) |

### Artefactos a retirar o reemplazar

_Ninguno adicional a los listados en "Artefactos a eliminar"._

## 6) Estrategia de implementación

### Pasos ordenados

1. **Eliminar la carpeta `lib/features/delivery_notes/`** completa (9 archivos).
2. **Eliminar `lib/app/di/modules/delivery_notes_module.dart`** y actualizar
   `lib/app/di/injection.dart` (quitar import y llamada).
3. **Actualizar `FacturaDirectaApiDataSource`** (interfaz e impl): quitar los 3
   métodos de albaranes.
4. **Actualizar `FdCountersCubit` y `FdCountersState`**: eliminar toda
   referencia a delivery notes.
5. **Actualizar `home_module.dart`**: quitar inyección de `getDeliveryNotes`.
6. **Actualizar `ComparisonCard`**: quitar prop y fila de albaranes.
7. **Actualizar `HomePage`**: quitar constante, tarjeta y diffs de albaranes;
   reindexar constantes de índice.
8. **Actualizar `SideMenu`**: quitar ítem Albaranes, ajustar separadores.
9. **Actualizar `SideMenuShell`**: quitar import, reindexar switch.
10. **Actualizar `SideMenuCubit`**: `_maxIndex = 7`.
11. **Actualizar `OrdersTableToolbar`**: quitar `onGenerateDeliveryNotes` y
    botón.
12. **Actualizar `OrdersTable`**: quitar campo `onGenerateDeliveryNotes` y su
    uso.
13. **Actualizar `OrdersTodayPage`**: quitar callback `onGenerateDeliveryNotes`.
14. **Actualizar `app_es.arb`**: eliminar ~20 claves i18n de albaranes.
15. **Ejecutar `flutter gen-l10n`** para regenerar archivos de localización.
16. **Verificar compilación** con `flutter build` o `flutter analyze`.

### Orden recomendado

El orden de pasos es el indicado arriba: primero eliminar archivos de la feature
(cortar la raíz), luego actualizar las dependencias de dentro hacia fuera (core
→ DI → home → orders_today → i18n).

### Dependencias entre pasos

- Los pasos 1-3 son prerrequisitos para que compilen los pasos 4-7.
- Los pasos 4-5 son prerrequisitos para que compile el paso 7.
- Los pasos 8-10 son independientes entre sí pero deben aplicarse juntos para
  coherencia de navegación.
- Los pasos 11-13 son independientes del resto.
- El paso 14 es independiente pero el paso 15 depende de él.
- El paso 16 valida todo.

### Puntos delicados

- **Reindexado de navegación:** Los índices en `SideMenu`, `SideMenuShell` y
  `HomePage` deben ser consistentes. Error en un solo índice causa navegación
  rota.
- **Separadores del `SideMenu`:** Los separadores visuales usan índices
  hardcodeados. Tras eliminar Albaranes (índice 6 antiguo), el separador entre
  "FacturaDirecta" y "Ajustes" debe moverse de `index == 7` a `index == 6`.
- **`FdCountersCubit.load()`:** Actualmente falla si
  `dnResult.isLeft() || invResult.isLeft()`. Tras eliminar `dnResult`, la
  condición solo evalúa `invResult.isLeft()`.

## 7) Estrategia de validación

### Verificación automática

- `flutter analyze` — sin errores ni warnings.
- `flutter test` — todos los tests existentes pasan (no hay tests de
  delivery_notes que romper).
- `flutter gen-l10n` — regeneración limpia sin claves huérfanas.

### Verificación manual

- Abrir la app y verificar que el menú lateral muestra exactamente 8 ítems en el
  orden correcto.
- Navegar a cada ítem del menú y verificar que la página correcta se muestra.
- Verificar que el dashboard de Inicio no muestra tarjeta ni comparativa de
  albaranes.
- Entrar en Pedidos Hoy, seleccionar clientes, y verificar que la toolbar no
  muestra "Generar albarán".
- Verificar que las secciones Contactos, Productos y Facturas siguen
  funcionando.

### Escenarios a cubrir

1. Navegación secuencial por los 8 ítems del menú.
2. Dashboard con y sin configuración de FacturaDirecta.
3. Dashboard con datos cargados (solo facturas, sin albaranes).
4. Toolbar de Pedidos Hoy con columnas seleccionadas.

### Tipo de pruebas recomendables

- Smoke test manual de navegación.
- Test unitario de `FdCountersCubit` actualizado (sin delivery notes) —
  recomendado pero opcional en esta iteración.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                 | Probabilidad | Impacto                                |
| ------------------------------------------------------ | ------------ | -------------------------------------- |
| Reindexado incorrecto de navegación                    | Baja         | Alto — navegación rota                 |
| Olvido de referencia a delivery notes en algún archivo | Baja         | Media — error de compilación inmediato |
| Claves i18n huérfanas en ARB                           | Baja         | Bajo — warning en gen-l10n             |

### Impacto potencial

- El usuario pierde acceso a la funcionalidad de Albaranes de forma permanente.
- Si el reindexado falla, la app muestra páginas incorrectas en el menú.

### Mitigación

- Compilar tras cada grupo de cambios (no acumular todos antes de verificar).
- Buscar globalmente `delivery_notes`, `DeliveryNote`, `deliveryNote` en el
  proyecto tras finalizar para detectar restos.
- Los separadores del menú se verifican visualmente.

### Plan de rollback

- `git revert` del commit de eliminación. Todos los archivos eliminados se
  restauran. No hay migración de datos ni cambios de esquema que revertir.

## 9) Suposiciones

- No existen tests de delivery_notes que deban migrarse o reescribirse.
- Los archivos generados de localización (`app_localizations.dart`,
  `app_localizations_es.dart`) se regeneran correctamente con `flutter gen-l10n`
  tras editar el ARB.
- `SideMenuState.selectedIndex` no se persiste en `SharedPreferences`, por lo
  que no hay riesgo de índice fuera de rango al actualizar.
- No hay otros archivos fuera de los identificados que importen o referencien
  `delivery_notes`.

## 10) Preguntas abiertas

- Ninguna. El análisis funcional fue lo suficientemente explícito y la
  inspección del código confirmó todos los puntos.

## 11) Notas para implementación

- Respetar el patrón de Clean Architecture existente: no dejar imports
  huérfanos.
- En `FdCountersCubit._compareSingleDay` y `_compareRange`, eliminar el
  parámetro `List<DeliveryNote> allDn` y toda la lógica de conteo de albaranes.
  Las funciones pasan a recibir solo `List<Invoice> allInv` además de las
  fechas.
- En `ComparisonCard`, al eliminar la fila de albaranes, el layout de las 3
  filas restantes (pedidos, facturas, total €) debe mantener el `spaceEvenly`
  actual.
- Tras eliminar los archivos, ejecutar
  `grep -r "delivery_notes\|DeliveryNote\|deliveryNote" lib/` para confirmar
  limpieza total antes de commit.
- **Estado: Listo para implementación**
