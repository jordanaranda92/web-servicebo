# Implementation Report: Exportar Excel desde Pedidos de Hoy

- **Fecha:** 2026-05-11
- **Identificador:** export-excel-orders-today
- **Fuente:** docs/technical-analysis/2026-05-11-export-excel-orders-today.md
- **Estado:** Completed

---

## 1) Resumen

Se ha implementado la funcionalidad de exportación de la tabla de Pedidos de Hoy
a formato `.xlsx`. El usuario dispone de un nuevo
`FloatingActionButton.extended` ("Exportar Excel") en la esquina inferior
derecha de la pantalla, visible únicamente cuando hay datos cargados. El archivo
generado replica la estructura de la tabla con colores de celdas para reserva,
compensación, stock estricto y quedan negativo.

La implementación es de solo lectura sobre el `OrderSheet` en memoria. No se ha
tocado ningún BLoC, repositorio ni Firestore.

**Resultado:** ✅ Completado. 0 errores. 1 info (deprecación de `dart:html`, no
bloqueante).

---

## 2) Alcance ejecutado

- ✅ Servicio `OrderSheetExcelService` creado en `data/services/`.
- ✅ Registrado en DI como `LazySingleton`.
- ✅ 3 claves i18n añadidas a `app_es.arb` y locales regenerados.
- ✅ `FloatingActionButton.extended` añadido en `_OrdersTodayContentState` con
  lógica de exportación.
- ✅ Descarga en macOS vía `FilePicker.saveFile`.
- ✅ Descarga en web vía conditional import (`dart:html` `AnchorElement`).
- ✅ Coloración de celdas: reserva (azul), compensación (verde), stock estricto
  (rojo claro), quedan negativo (rojo claro).
- ✅ Cabeceras: fila 0 con día/fecha y nombres de clientes; fila 1 con números
  de orden.
- ✅ Valor de celda = `quantity + refund` (abonos sumados a la cantidad).
- ✅ Siempre exporta la tabla completa (ignora filtro de búsqueda activo).

---

## 3) Artefactos tocados

### Creados

- `lib/features/orders_today/data/services/order_sheet_excel_service.dart`
- `lib/core/utils/web_download_stub.dart`
- `lib/core/utils/web_download_web.dart`

### Modificados

- `lib/app/di/modules/orders_today_module.dart` — import y registro de
  `OrderSheetExcelService`
- `lib/features/orders_today/presentation/pages/orders_today_page.dart` —
  imports, estado `_isExporting`, método `_exportExcel`, FAB en `Stack`
- `lib/app/localization/l10n/app_es.arb` — 3 claves nuevas:
  `ordersTodayExportExcel`, `ordersTodayExportExcelSuccess`,
  `ordersTodayExportExcelError`

### Retirados o reemplazados

_Ninguno._

---

## 4) Validación ejecutada

### Automática

- `flutter gen-l10n` ejecutado sin errores tras añadir claves i18n.
- `flutter analyze` sobre los 5 artefactos modificados/creados: **0 errores**.
- `flutter analyze` sobre el proyecto completo: **0 errores** (1 info no
  bloqueante).

### Incidencias encontradas y resolución

| Incidencia                     | Causa                                                                   | Resolución                                                                                                    |
| ------------------------------ | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `const_with_non_const` (×6)    | `TextCellValue('')` y similares no son `const` en excel 4.0.6           | Eliminado `const` de todos los constructores de `CellValue`                                                   |
| `undefined_getter: 'platform'` | Se usó `FilePicker.platform.saveFile` en lugar de `FilePicker.saveFile` | Corregido a `FilePicker.saveFile(...)` (API del paquete v11)                                                  |
| `dart:html` deprecated info    | `dart:html` está deprecado en Dart 3 a favor de `package:web`           | Mantenido con `// ignore` — sigue siendo funcional; migración a `package:web` fuera del alcance de esta tarea |

### Manual

- Pendiente de verificación manual en dispositivo macOS (apertura del `.xlsx` en
  Numbers/Excel, colores de celda, nombre de archivo).
- Pendiente de verificación en web.

---

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** El análisis técnico describía `_downloadOnWeb` como un
  método inline con `dart:html`. Se implementó con el patrón de conditional
  import (`web_download_stub.dart` + `web_download_web.dart`) para evitar
  errores de compilación en macOS.
  - **Justificación:** Separar en archivos de conditional import es el patrón
    estándar Flutter para código platform-specific y evita avisos del
    analizador.
  - **Impacto:** Ninguno en comportamiento. Mejor separación de
    responsabilidades.

- **Desviación 2:** Los colores de cabecera de columnas (PEDIDOS, STOCKS,
  QUEDAN, nombres de clientes) se añadieron con fondo de color para mejorar la
  legibilidad, aunque el análisis técnico no los especificaba en detalle. Los
  colores de datos son exactamente los del análisis.
  - **Justificación:** Mejora la usabilidad del Excel exportado y es coherente
    con la paleta de colores de la captura de referencia.
  - **Impacto:** Solo visual.

---

## 6) Riesgos, incidencias y pendientes

- **Riesgo activo:** `dart:html` está deprecado en Dart 3. Si Flutter elimina el
  soporte antes de que se migre a `package:web`, la descarga web dejará de
  compilar. La migración a `package:web` es un trabajo separado de bajo riesgo.
- **Pendiente:** Verificación manual del archivo `.xlsx` generado en macOS
  (Numbers, Excel for Mac) y en web.
- **Pendiente:** Si en el futuro se quiere añadir el umbral de coloración
  naranja en QUEDAN, se puede añadir como parámetro en
  `OrderSheetExcelService.generate()` sin cambiar la interfaz pública.

---

## 7) Resultado final

- **Estado final:** ✅ Completado
- **Siguiente paso recomendado:** Validación manual en macOS abriendo la app,
  pulsando "Exportar Excel" y verificando el archivo generado en Numbers o Excel
  for Mac.
