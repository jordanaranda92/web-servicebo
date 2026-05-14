# Implementation Report: Vista de solo lectura de pedidos de hoy (pantalla empaquetado)

- **Fecha:** 2026-05-13
- **Identificador:** orders-today-readonly-view
- **Plan técnico:**
  docs/technical-analysis/2026-05-13-orders-today-readonly-view.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado la vista de solo lectura de pedidos de hoy accesible desde
una nueva pestaña del navegador. El botón "ampliar" (`Icons.open_in_full`) en la
pantalla de pedidos de hoy ahora abre `/orders-today/view` en una nueva pestaña.
La tabla se muestra a pantalla completa (sin menú lateral), en modo solo lectura
(sin edición de celdas, menús contextuales ni acciones de modificación), con
actualización en tiempo real vía Firestore y un footer con fecha/hora de última
modificación + indicador de conexión parpadeante.

## 2) Alcance ejecutado

- ✅ Propagación de `lastModifiedAt` de Firestore a la entidad `OrderSheet`
- ✅ Modo `readOnly` en `OrdersTable` (desactiva edición, menús contextuales,
  presencia, `BrowserContextMenu`)
- ✅ Utilidad `openUrlInNewTab` con conditional import (web/stub)
- ✅ Claves i18n añadidas y traducciones regeneradas
- ✅ Widget `ReadonlyFooter` con timestamp e indicador parpadeante verde/gris
- ✅ Página `OrdersTodayReadonlyPage` con BLoC propio en modo solo lectura
  (`createIfMissing: false`)
- ✅ Ruta `/orders-today/view` fuera del `ShellRoute`, protegida por auth
- ✅ Botón ampliar conectado a abrir la ruta en nueva pestaña

## 3) Artefactos tocados

### Creados

- `lib/features/orders_today/presentation/pages/orders_today_readonly_page.dart`
- `lib/features/orders_today/presentation/widgets/readonly_footer.dart`
- `lib/core/utils/web_open_url_stub.dart`
- `lib/core/utils/web_open_url_web.dart`

### Modificados

- `lib/features/orders_today/domain/entities/order_sheet.dart` — añadido
  `DateTime? lastModifiedAt`
- `lib/features/orders_today/data/repositories/orders_today_repository_impl.dart`
  — propagado `doc.lastModifiedAt` en `_buildOrderSheet`
- `lib/features/orders_today/presentation/widgets/orders_table.dart` — añadido
  `bool readOnly`, condicionado `isEditable`, menús contextuales, presencia y
  `BrowserContextMenu`
- `lib/features/orders_today/presentation/bloc/orders_today_event.dart` —
  añadido `createIfMissing` a `OrdersTodayLoadRequested`
- `lib/features/orders_today/presentation/bloc/orders_today_bloc.dart` —
  propagado `createIfMissing` a `_loadOrders`, emite `OrdersTodayNoFile` si
  documento no existe y `createIfMissing == false`
- `lib/features/orders_today/presentation/pages/orders_today_page.dart` —
  conectado botón ampliar con `openUrlInNewTab`, import condicional añadido
- `lib/app/router/router.dart` — añadida constante `ordersTodayView`, nueva
  `GoRoute` fuera del `ShellRoute`
- `lib/app/localization/l10n/app_es.arb` — añadidas 5 claves i18n

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

| Validación          | Resultado                               |
| ------------------- | --------------------------------------- |
| `dart analyze lib/` | ✅ No issues found                      |
| `flutter test`      | ✅ 25 tests passed, sin regresiones     |
| `flutter gen-l10n`  | ✅ Traducciones generadas correctamente |

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** Se añadió parámetro `bool createIfMissing = true` al evento
  `OrdersTodayLoadRequested` y a `_loadOrders` del BLoC, en lugar de crear un
  evento separado. El análisis técnico lo sugería como opción más simple y es
  coherente con el patrón existente.
  - **Justificación:** Minimiza la cantidad de código nuevo y no afecta al
    comportamiento existente (default `true` preserva la lógica actual).
  - **Impacto:** Ninguno en funcionalidad existente.

- **Desviación 2:** El `ReadonlyFooter` se pasa como `footerTrailing` al
  `OrdersTable`, reutilizando el footer existente, en lugar de crear un footer
  completamente separado.
  - **Justificación:** Menor duplicación y mejor integración visual. En modo
    readonly sin presencia, la sección de usuarios conectados se oculta
    automáticamente (`SizedBox.shrink`), dejando solo el trailing.
  - **Impacto:** Ninguno.

## 6) Riesgos, incidencias y pendientes

- **Riesgo menor:** Si el stream de Firestore se interrumpe silenciosamente (sin
  emitir error), el indicador de conexión podría permanecer en verde.
  Mitigación: Firestore SDK suele emitir errores en caso de desconexión.
- **Pendiente de validación manual:** Verificar en entorno real que
  `window.open` no es bloqueado por el navegador (al ser acción directa de
  usuario, no debería serlo).
- **Pendiente de validación manual:** Verificar el parpadeo del punto verde y la
  actualización del timestamp en tiempo real con cambios desde otra pestaña.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual en entorno local
  (`flutter run -t lib/main_local.dart`)
