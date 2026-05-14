# Technical Analysis: Exportar Excel desde Pedidos de Hoy

- **Fecha:** 2026-05-11
- **Identificador:** export-excel-orders-today
- **Fuente:** docs/functional-analysis/2026-05-11-export-excel-orders-today.md
- **Estado:** Ready for implementation

---

## 1) Resumen técnico

- Se crea un servicio `OrderSheetExcelService` (capa `data/services/`) que
  genera un `Uint8List` con el `.xlsx` usando el paquete `excel` ya presente en
  `pubspec.yaml` (v4.0.6) — **sin nueva dependencia**.
- El botón de exportación se añade como `FloatingActionButton` en
  `_OrdersTodayContentState`, condicionado al estado `OrdersTodayLoaded`, usando
  un `Stack` sobre el `OrdersTable`.
- La descarga en macOS reutiliza el patrón de `FilePicker.saveFile` ya
  implementado en `_generateOrderSheetPdf`. En web se usa `dart:html` con
  `AnchorElement` + `Blob` detrás de un guard `kIsWeb`.
- El servicio se registra en DI (`orders_today_module.dart`) siguiendo el patrón
  de `OrderSheetPdfService`.
- Se añaden 3 claves i18n a `app_es.arb` y se regeneran los locales.
- **Riesgo general: bajo.** No toca BLoC, repositorio ni Firestore. Solo lectura
  del `OrderSheet` en memoria.

---

## 2) Contexto técnico observado

### Arquitectura detectada

- Clean Architecture feature-first con BLoC + GetIt + fpdart.
- Feature `orders_today` con capas `data/`, `domain/`, `presentation/`.
- Servicios de generación de documentos en `data/services/` (patrón
  `OrderSheetPdfService`).

### Dependencias relevantes ya presentes

| Paquete              | Versión   | Uso                                              |
| -------------------- | --------- | ------------------------------------------------ |
| `excel`              | `^4.0.6`  | Generación de `.xlsx` — **ya en `pubspec.yaml`** |
| `file_picker`        | `^11.0.2` | Save dialog nativo (macOS) — ya usado            |
| `flutter/foundation` | SDK       | `kIsWeb` para guard de plataforma — ya importado |

### Patrón de referencia: `OrderSheetPdfService`

- Registrado como `LazySingleton` en `orders_today_module.dart` sin parámetros.
- `generate({...}) → Future<Uint8List>` — genera documento en memoria.
- La presentación (`OrdersTable._generateOrderSheetPdf`) lo invoca vía
  `sl<OrderSheetPdfService>()`, presenta un diálogo de previsualización, y usa
  `FilePicker.saveFile` para guardar en disco.

### Entidad `OrderSheet` — campos relevantes para exportación

| Campo          | Tipo                        | Uso en Excel                                                     |
| -------------- | --------------------------- | ---------------------------------------------------------------- |
| `date`         | `String` (YYYY-MM-DD)       | Cabecera: "SÁBADO, 28 MARZO"                                     |
| `clients`      | `List<String>`              | Cabecera fila 1: nombre cliente por columna                      |
| `clientOrders` | `List<int>`                 | Cabecera fila 2: número de orden (1..N)                          |
| `products`     | `List<String>`              | Col A: nombre producto por fila                                  |
| `quantities`   | `List<List<num>>`           | Celdas de cantidad `[productIdx][clientIdx]`                     |
| `cellRefunds`  | `List<Map<String, num>>`    | Abono sumado al valor de celda: `[productIdx][clientId]`         |
| `clientIds`    | `List<String>`              | Necesario para lookup en `cellFlags`, `cellNotes`, `cellRefunds` |
| `cellFlags`    | `List<Map<String, String>>` | `"reservation"` → azul, `"compensation"` → verde                 |
| `stocks`       | `List<num>`                 | Col STOCKS                                                       |
| `strictStocks` | `List<bool>`                | Fondo rojo en celda STOCKS si `true`                             |
| `pedidos`      | `List<num>`                 | Col PEDIDOS                                                      |
| `quedan`       | `List<num>`                 | Col QUEDAN — fondo rojo si negativo                              |

### Restricciones detectadas

- `FilePicker.saveFile` **no está disponible en web** — requiere rama
  alternativa.
- En web se usa `dart:html` (disponible solo en web); se activa con guard
  `kIsWeb`.
- El proyecto ya usa `kIsWeb` en `OrdersTable` (importa
  `flutter/foundation.dart`).
- En macOS no hay diálogo de previsualización para Excel (a diferencia del PDF
  con `PdfPreview`); la acción es directa: generar → save dialog → escribir.

---

## 3) Objetivo técnico

- Añadir un `FloatingActionButton` "Exportar Excel" en la pantalla de Pedidos de
  Hoy, condicionado al estado `OrdersTodayLoaded`.
- Crear `OrderSheetExcelService` que acepte un `OrderSheet` y devuelva
  `Uint8List` con el `.xlsx` correctamente estructurado y coloreado.
- Gestionar el guardado del archivo de forma diferente según plataforma (macOS
  vs. web).
- No alterar el BLoC, repositorio, casos de uso, ni la estructura de Firestore.
- No alterar la interfaz de `OrdersTable` (no añadir nuevos callbacks al
  widget).

---

## 4) Diseño técnico de la solución

### Enfoque propuesto

Separación en dos responsabilidades:

1. **`OrderSheetExcelService`** — generación pura del `.xlsx` en memoria. Recibe
   un `OrderSheet` completo y devuelve `Uint8List`. Sin dependencias de Flutter
   UI. Testeable en aislamiento.

2. **`_exportExcel(BuildContext, OrderSheet)`** — método privado en
   `_OrdersTodayContentState` que orquesta: invoca el servicio → gestiona el
   save dialog según plataforma → escribe el archivo → muestra SnackBar.

El FAB se añade en `_OrdersTodayContentState.build()`, envolviendo el `switch`
de estados en un `Stack` con `Positioned` para el botón.

---

### Estructura de la hoja Excel generada

```
Col 0            | Col 1..N         | Col N+1  | Col N+2  | Col N+3
─────────────────────────────────────────────────────────────────────
[Fila 0] SÁBADO, | Nombre cliente 1 | PEDIDOS  | STOCKS   | QUEDAN
         28 MARZO| Nombre cliente 2 |          |          |
                 | ...              |          |          |
─────────────────────────────────────────────────────────────────────
[Fila 1] (vacía) | 1                | (vacía)  | (vacía)  | (vacía)
                 | 2                |          |          |
                 | ...              |          |          |
─────────────────────────────────────────────────────────────────────
[Fila 2] Producto A | qty+refund  | pedidos  | stocks   | quedan
[Fila 3] Producto B | qty+refund  | pedidos  | stocks   | quedan
...
```

> **Nota:** La fila 0 tiene una única celda de cabecera en Col 0 (merge de filas
> 0–1 si la librería lo permite, o simplemente en fila 0). Los nombres de
> clientes van en fila 0, los números de orden en fila 1.

---

### Contratos e interfaces

```dart
// lib/features/orders_today/data/services/order_sheet_excel_service.dart

import 'dart:typed_data';
import '../../domain/entities/order_sheet.dart';

class OrderSheetExcelService {
  /// Genera el archivo .xlsx en memoria para el [orderSheet] dado.
  /// Retorna los bytes del archivo listo para guardar.
  Future<Uint8List> generate({required OrderSheet orderSheet});
}
```

El método es `async` para consistencia con `OrderSheetPdfService` aunque la
generación sea síncrona internamente (permite futura offloading a isolate sin
cambiar contrato).

---

### Flujo de datos

```
_OrdersTodayContentState
  ├─ FAB pulsado
  ├─ setState(_isExporting = true)   ← deshabilita FAB
  ├─ sl<OrderSheetExcelService>().generate(orderSheet: orderSheet)
  │     └─ Construye Excel en memoria → Uint8List
  ├─ if (kIsWeb)
  │     └─ _downloadOnWeb(bytes, fileName)   ← dart:html AnchorElement
  │   else
  │     └─ FilePicker.saveFile(fileName, bytes)   ← macOS native dialog
  │         ├─ path != null → File(path).writeAsBytes(bytes)
  │         │                 → SnackBar éxito
  │         └─ path == null → cancelado, sin acción
  └─ setState(_isExporting = false)
```

---

### Lógica de coloración de celdas (en `OrderSheetExcelService`)

El paquete `excel` ^4.0.6 usa `CellStyle` con `backgroundColorHex` de tipo
`ExcelColor`.

| Condición                                  | Celda afectada            | Color de fondo         |
| ------------------------------------------ | ------------------------- | ---------------------- |
| `cellFlags[p][clientId] == 'reservation'`  | Celda cantidad de cliente | `#BBDEFB` (azul)       |
| `cellFlags[p][clientId] == 'compensation'` | Celda cantidad de cliente | `#C8E6C9` (verde)      |
| `strictStocks[p] == true`                  | Celda STOCKS del producto | `#FFCDD2` (rojo claro) |
| `quedan[p] < 0`                            | Celda QUEDAN del producto | `#EF9A9A` (rojo claro) |

> Se usan variantes "claras" de rojo (`#FFCDD2`, `#EF9A9A`) en lugar del rojo
> puro de la UI (`#FF1744`) para mejor legibilidad en Excel impreso.

### Valor de celda de cliente

```
valorCelda = quantities[productIdx][clientIdx]
           + (cellRefunds[productIdx][clientIds[clientIdx]] ?? 0)
```

Si el valor resultante es `0`, se escribe `0` (no vacío), para mantener
coherencia con la UI.

---

### Descarga en web (`_downloadOnWeb`)

```dart
// Solo accesible en web — usar conditional import o guard kIsWeb
import 'dart:html' as html;

void _downloadOnWeb(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
```

> **Alternativa más robusta:** usar `package:web` (Dart web interop moderno) si
> el proyecto ya lo usa, o mantener `dart:html` con un archivo de implementación
> separado + conditional import. Para esta versión se puede usar el guard
> `kIsWeb` con un bloque `// ignore: avoid_web_libraries_in_flutter` ya que el
> proyecto ya emplea este patrón.

---

### Gestión de errores y validaciones

| Caso                                          | Comportamiento                                                                |
| --------------------------------------------- | ----------------------------------------------------------------------------- |
| Generación exitosa, usuario confirma guardado | Escribe archivo → SnackBar éxito                                              |
| Usuario cancela save dialog                   | Sin acción, sin SnackBar                                                      |
| Error en generación o escritura               | `try/catch` → SnackBar error                                                  |
| `OrderSheet` sin productos                    | Se genera Excel con solo cabeceras, sin error                                 |
| `OrderSheet` sin clientes                     | Se genera Excel con col de productos + 3 cols resumen sin columnas de cliente |

---

### Consideraciones de compatibilidad

- El paquete `excel` ^4.0.6 es compatible con Dart ^3.x y con compilación web.
- `dart:html` está deprecado en favor de `package:web` en Dart 3, pero sigue
  funcionando. Para evitar warnings se puede encapsular en un archivo
  `_web_download_stub.dart` + `_web_download_web.dart` con conditional import.
  Esta complejidad es opcional en esta versión.
- `FilePicker.saveFile` en macOS requiere que `file_picker` tenga los permisos
  de sandbox correctos (`com.apple.security.files.user-selected.read-write`),
  que ya están configurados para la generación de PDF.

---

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                | Propósito                                     |
| ------------------------------------------------------------------------ | --------------------------------------------- |
| `lib/features/orders_today/data/services/order_sheet_excel_service.dart` | Servicio de generación del `.xlsx` en memoria |

### Artefactos a modificar

| Artefacto                                                             | Cambio esperado                                                                                |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `lib/app/di/modules/orders_today_module.dart`                         | Registrar `OrderSheetExcelService` como `LazySingleton`                                        |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart` | Añadir FAB y método `_exportExcel` en `_OrdersTodayContentState`; envolver `switch` en `Stack` |
| `lib/app/localization/l10n/app_es.arb`                                | Añadir 3 claves i18n nuevas                                                                    |
| `lib/app/localization/l10n/app_en.arb`                                | Añadir las mismas 3 claves en inglés (si existe)                                               |

### Artefactos a retirar o reemplazar

_Ninguno._

---

## 6) Estrategia de implementación

1. **Crear `OrderSheetExcelService`** — implementar `generate()` con la
   estructura de filas/columnas y coloración. Verificar con test unitario básico
   que el `Uint8List` resultante es válido (longitud > 0, empieza con magic
   bytes de ZIP/XLSX).
2. **Registrar en DI** — añadir
   `sl.registerLazySingleton(() => OrderSheetExcelService())` en
   `orders_today_module.dart`, junto al registro de `OrderSheetPdfService`.
3. **Añadir claves i18n** — añadir `ordersTodayExportExcel`,
   `ordersTodayExportExcelSuccess`, `ordersTodayExportExcelError` en
   `app_es.arb` y ejecutar `flutter gen-l10n`.
4. **Añadir FAB en `_OrdersTodayContentState`** — envolver el `BlocBuilder` en
   un `Stack`; añadir `Positioned` con `FloatingActionButton` condicionado a
   estado `OrdersTodayLoaded`; implementar `_exportExcel`.

### Orden recomendado

`OrderSheetExcelService` → DI → i18n → Presentación (FAB + lógica).

### Dependencias entre pasos

- Paso 2 depende del Paso 1 (necesita la clase para registrar).
- Paso 4 depende de Pasos 2 y 3 (necesita el servicio en DI y las claves i18n).
- Paso 1 y 3 son independientes entre sí.

### Puntos delicados

- **API del paquete `excel` ^4.0.6:** La API de estilos de celda cambió
  significativamente en v4. Verificar que `CellStyle` acepta
  `backgroundColorHex` con `ExcelColor.fromHexString(...)`. En v4, el acceso es
  `sheet.cell(CellIndex.indexByColumnRow(...)).cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('BBDEFB'))`.
- **Merge de celdas en cabecera:** Si la librería soporta merge, la celda de
  fecha puede ocupar filas 0 y 1 en Col 0. Si no, simplemente se escribe en
  fila 0. No es bloqueante.
- **Descarga en web:** Comprobar que `dart:html` no genera errores de
  compilación en macOS. Usar `kIsWeb` guard estricto o conditional import.
- **Valor de celda con refund:** Asegurarse de usar `clientIds[clientIdx]` para
  lookear en `cellRefunds[productIdx]`, ya que `cellRefunds` es un mapa sparse
  por `clientId`, no por índice.

---

## 7) Estrategia de validación

### Automática

- **Test unitario de `OrderSheetExcelService`:** Construir un `OrderSheet` de
  prueba con 2 productos, 2 clientes, flags de reserva/compensación, stock
  estricto y quedan negativo. Verificar que `generate()` devuelve bytes no
  vacíos y que el fichero puede ser parseado de nuevo con `excel` sin errores.
- Test de que la celda de reserva tiene el color correcto (inspeccionar
  `CellStyle` del resultado).

### Manual

- Abrir el `.xlsx` generado en macOS (Numbers o Excel) y verificar visualmente:
  - Cabecera con el día correcto y nombres de clientes.
  - Números de orden en fila 2.
  - Cantidades correctas (incluyendo abonos sumados).
  - Colores de reserva (azul), compensación (verde), stock estricto (rojo),
    quedan negativo (rojo).
  - Nombre de archivo correcto (`Pedidos_YYYY-MM-DD.xlsx`).
- Verificar en web que la descarga se dispara correctamente.
- Verificar que cancelar el save dialog no genera ningún archivo ni error.

### Escenarios a cubrir

- Tabla vacía (sin productos, sin clientes).
- Tabla con solo productos y sin clientes.
- Tabla con nombres de cliente con caracteres especiales.
- Tabla con quedan negativo y positivo a la vez.
- Tabla con stock estricto en algunos productos y en otros no.

---

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                    | Probabilidad                  | Impacto                                                                    |
| ------------------------------------------------------------------------- | ----------------------------- | -------------------------------------------------------------------------- |
| API de `excel` ^4.0.6 incompatible con estilos de celda esperados         | Baja (paquete ya en proyecto) | Medio — habría que ajustar el API de colores                               |
| `dart:html` deprecated warnings en compilación web                        | Media                         | Bajo — solo warning, no error; se puede suprimir o usar conditional import |
| `FilePicker.saveFile` no disponible en algunas versiones de macOS sandbox | Baja                          | Bajo — ya funciona para PDF                                                |

### Impacto potencial

- Solo afecta a la pantalla de Pedidos de Hoy, y únicamente al añadir una acción
  nueva.
- No modifica datos existentes ni flujos de lectura/escritura.
- El FAB coexiste con el resto de la UI sin solapamientos (posicionado
  `bottom: 16, right: 16`, ya lejos del `OrdersTableFooter`).

### Mitigación

- Si la API de `excel` no soporta estilos de celda en la versión instalada, se
  puede omitir la coloración en primera iteración y entregar el Excel sin
  colores como fallback.
- Si `dart:html` da problemas en web, usar conditional import con stub para
  macOS.

### Plan de rollback

- El servicio y el FAB son adiciones puras. Rollback = eliminar
  `OrderSheetExcelService`, revertir el registro en DI, revertir el `Stack` en
  `_OrdersTodayContentState`, y eliminar las 3 claves i18n. Sin impacto en datos
  ni en el resto de la app.

---

## 9) Suposiciones

- El paquete `excel` ^4.0.6 ya instalado soporta escritura con estilos de celda
  (`CellStyle` + `backgroundColorHex`). Si no, se usará una versión mayor o la
  coloración se pospondrá.
- La plataforma de producción usa macOS desktop + web. No se contempla
  iOS/Android en este análisis.
- Los colores del Excel (`#BBDEFB`, `#C8E6C9`, `#FFCDD2`, `#EF9A9A`) son
  variantes más suaves que los de la UI para mejor impresión, pero pueden
  ajustarse sin cambiar el diseño.
- El FAB se ubica en `_OrdersTodayContentState` (nivel de página), no dentro de
  `OrdersTable`, para no añadir más parámetros al widget más complejo de la app.
- No se necesita un estado de progreso complejo: basta con un
  `bool _isExporting` en `setState` para deshabilitar el FAB durante la
  exportación.

---

## 10) Preguntas abiertas

_Ninguna. Todas las dudas funcionales están resueltas. Las decisiones técnicas
menores (colores exactos en Excel, merge de celdas en cabecera) quedan a
criterio del implementador._

---

## 11) Notas para implementación

### Claves i18n a añadir en `app_es.arb`

```json
"ordersTodayExportExcel": "Exportar Excel",
"@ordersTodayExportExcel": {
  "description": "Botón para exportar la tabla de pedidos de hoy como Excel"
},
"ordersTodayExportExcelSuccess": "Excel exportado correctamente",
"@ordersTodayExportExcelSuccess": {
  "description": "Mensaje de éxito al exportar el Excel"
},
"ordersTodayExportExcelError": "Error al exportar el Excel",
"@ordersTodayExportExcelError": {
  "description": "Mensaje de error al exportar el Excel"
}
```

### Registro en DI (`orders_today_module.dart`)

Añadir junto al bloque de servicios existente:

```dart
sl.registerLazySingleton(() => OrderSheetExcelService());
```

### Estructura del FAB en `_OrdersTodayContentState`

```dart
// Envolver el BlocBuilder existente:
Stack(
  children: [
    BlocBuilder<OrdersTodayBloc, OrdersTodayState>(
      builder: (context, state) { /* switch existente */ },
    ),
    if (state is OrdersTodayLoaded)
      Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton.extended(
          onPressed: _isExporting ? null : () => _exportExcel(context, state.orderSheet),
          icon: _isExporting
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.table_chart_outlined),
          label: Text(l10n.ordersTodayExportExcel),
        ),
      ),
  ],
)
```

> **Nota:** Para acceder a `state` dentro del `Positioned`, el `BlocBuilder`
> debe envolver todo el `Stack`, o bien usar
> `context.read<OrdersTodayBloc>().state`. La forma más limpia es usar
> `BlocBuilder` en el nivel superior y pasar el `orderSheet` al método.

### Skeleton de `OrderSheetExcelService.generate()`

```dart
Future<Uint8List> generate({required OrderSheet orderSheet}) async {
  final excel = Excel.createExcel();
  excel.delete('Sheet1'); // eliminar hoja por defecto
  final sheetName = 'Pedidos';
  final sheet = excel[sheetName];

  final date = DateTime.tryParse(orderSheet.date) ?? DateTime.now();
  final dayName = DateFormat('EEEE', 'es').format(date).toUpperCase();
  final dayPart = DateFormat("d 'DE' MMMM", 'es').format(date).toUpperCase();
  final headerDateLabel = '$dayName, $dayPart';

  final numClients = orderSheet.clients.length;
  final pedidosCol = numClients + 1;
  final stocksCol  = numClients + 2;
  final quedanCol  = numClients + 3;

  // ── Fila 0: cabecera ─────────────────────────────────────
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
    ..value = TextCellValue(headerDateLabel);
  for (var c = 0; c < numClients; c++) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: 0))
      ..value = TextCellValue(orderSheet.clients[c]);
  }
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: pedidosCol, rowIndex: 0))
    ..value = const TextCellValue('PEDIDOS');
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: stocksCol, rowIndex: 0))
    ..value = const TextCellValue('STOCKS');
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: quedanCol, rowIndex: 0))
    ..value = const TextCellValue('QUEDAN');

  // ── Fila 1: números de orden ─────────────────────────────
  for (var c = 0; c < numClients; c++) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: 1))
      ..value = IntCellValue(c + 1);
  }

  // ── Filas de producto ────────────────────────────────────
  for (var p = 0; p < orderSheet.products.length; p++) {
    final rowIdx = p + 2;
    // Nombre producto
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
      ..value = TextCellValue(orderSheet.products[p]);

    // Celdas de cliente
    for (var c = 0; c < numClients; c++) {
      final clientId = c < orderSheet.clientIds.length ? orderSheet.clientIds[c] : '';
      final qty = p < orderSheet.quantities.length && c < orderSheet.quantities[p].length
          ? orderSheet.quantities[p][c]
          : 0;
      final refund = p < orderSheet.cellRefunds.length
          ? (orderSheet.cellRefunds[p][clientId] ?? 0)
          : 0;
      final cellValue = qty + refund;

      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: rowIdx));
      cell.value = DoubleCellValue(cellValue.toDouble());

      // Color de fondo por flag
      final flag = p < orderSheet.cellFlags.length ? orderSheet.cellFlags[p][clientId] : null;
      if (flag == 'reservation') {
        cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#BBDEFB'));
      } else if (flag == 'compensation') {
        cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#C8E6C9'));
      }
    }

    // PEDIDOS
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: pedidosCol, rowIndex: rowIdx))
      ..value = DoubleCellValue((p < orderSheet.pedidos.length ? orderSheet.pedidos[p] : 0).toDouble());

    // STOCKS
    final stockCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: stocksCol, rowIndex: rowIdx));
    stockCell.value = DoubleCellValue((p < orderSheet.stocks.length ? orderSheet.stocks[p] : 0).toDouble());
    if (p < orderSheet.strictStocks.length && orderSheet.strictStocks[p]) {
      stockCell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#FFCDD2'));
    }

    // QUEDAN
    final quedanValue = p < orderSheet.quedan.length ? orderSheet.quedan[p] : 0;
    final quedanCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: quedanCol, rowIndex: rowIdx));
    quedanCell.value = DoubleCellValue(quedanValue.toDouble());
    if (quedanValue < 0) {
      quedanCell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#EF9A9A'));
    }
  }

  final bytes = excel.save();
  return Uint8List.fromList(bytes!);
}
```

### Sanitización del nombre de archivo

```dart
final fileName = 'Pedidos_${orderSheet.date}.xlsx'; // date ya es YYYY-MM-DD, sin caracteres peligrosos
```

- **Estado: Listo para implementación**
