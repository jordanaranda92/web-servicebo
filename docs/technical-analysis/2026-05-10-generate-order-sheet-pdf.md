# Technical Analysis: Generación de hoja de pedido en PDF

- **Fecha:** 2026-05-10
- **Identificador:** generate-order-sheet-pdf
- **Fuente:** docs/functional-analysis/2026-05-10-generate-order-sheet-pdf.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Crear un servicio de generación de PDF (`OrderSheetPdfService`) que reciba los
  datos de un pedido de cliente y devuelva los bytes del PDF con diseño
  estilizado.
- Añadir el paquete `printing` para presentar el PDF mediante el diálogo nativo
  de impresión/previsualización del SO.
- Habilitar la opción `'generate_order_sheet'` en el menú contextual del widget
  `OrdersTable` y conectar el handler que extrae datos, genera el PDF y lo
  presenta.
- No se modifica BLoC, repositorio, Firestore ni ningún flujo de datos
  existente. El cambio es autocontenido en la capa de presentación + un servicio
  utilitario.
- Riesgo general estimado: **bajo** — operación de solo lectura, sin efecto en
  el estado de la aplicación, con dependencias maduras.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC, GetIt y fpdart.
- Los servicios utilitarios transversales se ubican en `lib/core/services/` con
  patrón **interfaz abstracta + implementación** (ej: `ExcelParserService` /
  `ExcelParserServiceImpl`).
- Sin embargo, este servicio de PDF es específico del feature `orders_today` y
  no será reutilizado por otros features, por lo que ubicarlo dentro del feature
  es más apropiado que en `core/`.

### Módulos relevantes

- **`OrdersTable`**
  (`lib/features/orders_today/presentation/widgets/orders_table.dart`): widget
  que contiene el menú contextual con la opción deshabilitada.
- **`OrderSheet`**
  (`lib/features/orders_today/domain/entities/order_sheet.dart`): entidad con
  todos los datos (clientes, productos, cantidades, cellNotes).
- **`orders_today_module.dart`**
  (`lib/app/di/modules/orders_today_module.dart`): módulo DI donde se registran
  servicios y use cases del feature.

### Dependencias existentes

- `pdf: ^3.12.0` — ya incluido en `pubspec.yaml`. Generación de documentos PDF
  con API de widgets (similar a Flutter).
- `intl: ^0.20.2` — ya incluido; se usará para formatear fecha y hora.
- `printing` — **no incluido**. Necesario para el diálogo nativo de
  impresión/previsualización en desktop.

### Restricciones

- Plataformas objetivo: **Windows** (producción) y **macOS** (desarrollo/test).
- El paquete `printing` soporta ambas plataformas nativamente.
- No se usa HTML para el PDF — el paquete `pdf` de Dart no lo soporta. La API de
  widgets del paquete es suficiente para diseños estilizados.

### Patrones existentes relevantes

- Snackbars: se usan `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))`
  directamente en los widgets para feedback al usuario.
- DI: servicios se registran con `sl.registerLazySingleton()` en los módulos
  correspondientes.
- El widget `OrdersTable` accede al service locator global mediante `sl<T>()`
  importado de `injection.dart`.

## 3) Objetivo técnico

- **Qué debe cambiar:** El menú contextual de cliente pasa de tener la opción
  «Generar hoja de pedido» deshabilitada a funcional. Al seleccionarla se genera
  un PDF estilizado y se presenta al usuario.
- **Resultado técnico:** El usuario obtiene un PDF imprimible/descargable con
  los datos del pedido de un cliente concreto, sin modificar el estado de la
  aplicación ni los datos persistidos.
- **Limitaciones a respetar:**
  - No modificar BLoC, eventos, estados ni repositorio.
  - No añadir dependencias innecesarias (solo `printing`).
  - No alterar el contrato del widget `OrdersTable` (no añadir callbacks
    nuevos).
  - Respetar los patrones de DI y servicio del proyecto.

## 4) Diseño técnico de la solución

### Enfoque propuesto

La generación de PDF es una operación pura y síncrona (datos de entrada → bytes
PDF). No requiere interacción con capas de datos, repositorio ni BLoC. Se
implementa como un **servicio utilitario** registrado en DI al que el widget
accede directamente.

El flujo es:

1. El usuario selecciona «Generar hoja de pedido» en el menú contextual.
2. El handler en `_OrdersTableState` extrae del `OrderSheet` los datos del
   cliente (nombre, fecha, productos con qty > 0, notas).
3. Si no hay productos con cantidad > 0, se muestra un snackbar informativo y se
   aborta.
4. Se invoca al `OrderSheetPdfService` con los datos extraídos.
5. El servicio genera los bytes del PDF con el paquete `pdf`.
6. Se presenta el PDF con `Printing.layoutPdf()` del paquete `printing`.

### Componentes / módulos / servicios afectados

| Componente                     | Capa            | Rol                                                          |
| ------------------------------ | --------------- | ------------------------------------------------------------ |
| `OrderSheetPdfService` (nuevo) | Data / services | Genera los bytes del PDF a partir de datos del pedido        |
| `OrdersTable`                  | Presentación    | Habilita la opción de menú, extrae datos y llama al servicio |
| `orders_today_module.dart`     | DI              | Registra el servicio                                         |
| `pubspec.yaml`                 | Configuración   | Añade dependencia `printing`                                 |
| `app_es.arb` + localization    | i18n            | Añade string para el caso de "sin productos"                 |

### Contratos e interfaces

**`OrderSheetPdfService`** — Servicio sin interfaz abstracta (no se necesita
mock de esta clase dado que no se testea desde BLoC; si se desea testear en el
futuro, se puede extraer interfaz):

```dart
class OrderSheetPdfService {
  Uint8List generate({
    required String clientName,
    required String date,       // Fecha formateada (ej: "10/05/2026")
    required String time,       // Hora formateada (ej: "19:50:30")
    required List<OrderSheetPdfRow> rows,
  });
}

class OrderSheetPdfRow {
  final String product;
  final String quantity;   // Ya formateado como string
  final String? notes;
}
```

No se expone `UseCase` formal porque:

- La operación no interactúa con repositorio ni devuelve `Either<Failure, T>`.
- Es una transformación pura de datos → bytes, síncrona.
- El patrón existente de use cases del proyecto siempre delega en `repository`.
  Aquí no hay repositorio.

### Flujo de datos o de control

```
OrdersTable._showClientContextMenu()
  └─ usuario selecciona 'generate_order_sheet'
      └─ _generateOrderSheetPdf(col)
          ├─ extrae datos de widget.orderSheet para col
          ├─ filtra productos con qty > 0
          ├─ si vacío → ScaffoldMessenger.showSnackBar() → return
          ├─ formatea fecha/hora con intl
          ├─ invoca sl<OrderSheetPdfService>().generate(...)
          └─ Printing.layoutPdf(onLayout: (_) => pdfBytes)
              └─ SO abre diálogo nativo de impresión/previsualización
```

### Diseño del PDF

El PDF sigue el formato de la captura de referencia con mejoras estilísticas:

**Cabecera:**

- Tabla de 2 columnas con bordes: etiqueta (bold) | valor.
- Filas: Cliente, Fecha, Hora.
- Fondo gris claro en la columna de etiquetas.

**Tabla de productos:**

- 3 columnas: Producto, Cantidad, Notas.
- Cabecera con fondo gris/azulado y texto bold.
- Filas con bordes, alternancia de fondo (zebra striping) para legibilidad.
- Contenido con word-wrap automático (comportamiento por defecto de `pw.Table`).
- Si supera una página, el paquete `pdf` maneja paginación automática con
  `pw.MultiPage`.

**Formato general:**

- Página A4.
- Fuente por defecto del paquete (Helvetica, soporta caracteres latinos
  incluidos tildes y ñ).
- Márgenes estándar.

### Gestión de errores y validaciones

| Escenario                               | Manejo                                                |
| --------------------------------------- | ----------------------------------------------------- |
| Cliente sin productos con qty > 0       | Snackbar informativo, no se genera PDF                |
| Error en generación de PDF (improbable) | try-catch en el handler, snackbar de error            |
| Usuario cierra el diálogo sin imprimir  | Sin efecto — `Printing.layoutPdf` retorna normalmente |

### Consideraciones de compatibilidad o migración

- No hay migración de datos.
- El paquete `printing` requiere configuración nativa mínima en macOS/Windows,
  pero su setup es automático vía plugin Flutter.
- En macOS con sandbox, `printing` funciona correctamente (usa APIs nativas de
  impresión del SO que están permitidas en sandbox).

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                              | Propósito                                                                         |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `lib/features/orders_today/data/services/order_sheet_pdf_service.dart` | Servicio que genera los bytes del PDF estilizado a partir de los datos del pedido |

### Artefactos a modificar

| Artefacto                                                          | Cambio esperado                                                                                                                                                                      |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `pubspec.yaml`                                                     | Añadir dependencia `printing: ^5.13.5`                                                                                                                                               |
| `lib/features/orders_today/presentation/widgets/orders_table.dart` | 1) Habilitar `PopupMenuItem` de `'generate_order_sheet'` (`enabled: true`). 2) Añadir case `'generate_order_sheet'` en el switch. 3) Crear método `_generateOrderSheetPdf(int col)`. |
| `lib/app/di/modules/orders_today_module.dart`                      | Registrar `OrderSheetPdfService` con `sl.registerLazySingleton()`                                                                                                                    |
| `lib/app/localization/l10n/app_es.arb`                             | Añadir string `ordersTodayGenerateOrderSheetEmpty` para el caso sin productos                                                                                                        |

### Artefactos a retirar o reemplazar

| Artefacto | Motivo |
| --------- | ------ |
| Ninguno   | —      |

## 6) Estrategia de implementación

### Pasos

1. **Añadir dependencia `printing`** en `pubspec.yaml` y ejecutar
   `flutter pub get`.
2. **Crear `OrderSheetPdfService`** en
   `lib/features/orders_today/data/services/order_sheet_pdf_service.dart`:
   - Clase con método `generate()` que recibe datos del pedido y retorna
     `Uint8List`.
   - Usa `pw.Document`, `pw.MultiPage`, `pw.Table`,
     `pw.TableHelper.fromTextArray`.
   - Diseño estilizado: cabecera con datos del cliente, tabla de productos con
     zebra striping y cabecera coloreada.
3. **Registrar servicio en DI** en `orders_today_module.dart`:
   - `sl.registerLazySingleton(() => OrderSheetPdfService());`
4. **Añadir string i18n** en `app_es.arb`:
   - `ordersTodayGenerateOrderSheetEmpty`: mensaje para cuando no hay productos.
5. **Modificar `OrdersTable`**:
   - Añadir imports: `package:printing/printing.dart`, servicio PDF.
   - Cambiar `enabled: false` → `enabled: true` en el `PopupMenuItem` de
     `'generate_order_sheet'`.
   - Eliminar el color deshabilitado del icono (usar `_colorScheme.onSurface` en
     lugar de `.withValues(alpha: 0.38)`).
   - Añadir case `'generate_order_sheet': _generateOrderSheetPdf(col);` en el
     switch del handler.
   - Crear método `_generateOrderSheetPdf(int col)` que: extrae datos, valida
     que haya productos, invoca al servicio, presenta con `Printing.layoutPdf`.

### Orden recomendado

1 → 2 → 3 → 4 → 5

Cada paso es incremental. Los pasos 2, 3 y 4 son independientes entre sí y
podrían hacerse en paralelo, pero el paso 5 depende de todos los anteriores.

### Dependencias entre pasos

- El paso 5 requiere que los pasos 1–4 estén completados.
- Los pasos 2, 3 y 4 son independientes entre sí.

### Puntos delicados

- **Fuentes y caracteres especiales:** La fuente por defecto de `pdf`
  (Helvetica) soporta caracteres latinos (tildes, ñ, ç). No se necesitan fuentes
  TTF custom para español.
- **Paginación:** Usar `pw.MultiPage` en lugar de `pw.Page` para que tablas
  largas fluyan a páginas adicionales automáticamente.
- **Formato de cantidades:** Reutilizar la misma lógica de `_formatNum` del
  widget para consistencia (enteros sin decimales, decimales tal cual).
- **macOS sandbox + printing:** El paquete `printing` usa `NSPrintOperation` en
  macOS, que está permitida en sandbox sin entitlements adicionales.

## 7) Estrategia de validación

### Verificación automática

- Compilación exitosa en macOS y Windows.
- `flutter analyze` sin errores ni warnings nuevos.
- Test unitario del servicio `OrderSheetPdfService`: verificar que genera bytes
  válidos de PDF para diferentes inputs (con notas, sin notas, una fila, muchas
  filas, caracteres especiales).

### Validación manual

- Hacer click derecho sobre un cliente con pedidos → verificar que se abre el
  diálogo de impresión con el PDF correcto.
- Verificar diseño visual del PDF: cabecera con datos, tabla estilizada, bordes,
  colores.
- Verificar que solo aparecen productos con cantidad > 0.
- Verificar notas en la columna correspondiente.
- Verificar que un cliente sin pedidos muestra snackbar informativo.
- Verificar impresión real en impresora física (opcional pero recomendable).
- Verificar guardado como archivo PDF desde el diálogo.

### Escenarios a cubrir

| Escenario                                 | Tipo              |
| ----------------------------------------- | ----------------- |
| Cliente con 3 productos, 1 con nota       | Manual + unitario |
| Cliente con 0 productos (todo en 0)       | Manual + unitario |
| Cliente con 1 solo producto               | Unitario          |
| Cliente con muchos productos (> 1 página) | Manual            |
| Nombre de cliente con tildes/ñ            | Unitario          |
| Nota con texto largo                      | Manual            |
| Cantidad decimal (0.5)                    | Unitario          |

### Pruebas recomendables

- **Unitarias:** `OrderSheetPdfService.generate()` — verificar que retorna bytes
  no vacíos, que el PDF tiene el número de páginas esperado (si se puede
  inspeccionar), que no lanza excepciones para inputs válidos y edge cases.
- **Widget test (opcional):** Verificar que el menú contextual tiene la opción
  habilitada y que al seleccionarla se llama al servicio.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                          | Probabilidad                     | Impacto                           |
| ----------------------------------------------- | -------------------------------- | --------------------------------- |
| `printing` no funciona correctamente en Windows | Baja (paquete maduro, 5k+ likes) | Alto — funcionalidad inutilizable |
| PDF con caracteres mal renderizados             | Baja (Helvetica soporta latin)   | Medio — PDF ilegible parcialmente |
| Latencia en generación de PDFs muy largos       | Muy baja (datos pequeños)        | Bajo — UX degradada               |

### Impacto potencial

- **En el usuario:** Positivo — nueva funcionalidad que resuelve necesidad
  operativa.
- **En el código existente:** Mínimo — solo se habilita una opción de menú y se
  añade un handler. No se tocan callbacks, BLoC ni flujo de datos.
- **En dependencias:** Se añade una dependencia nueva (`printing`), que es el
  paquete complementario oficial del paquete `pdf` ya incluido.

### Mitigación

- Probar `Printing.layoutPdf()` en ambas plataformas antes de dar por cerrada la
  implementación.
- Si `printing` presenta problemas en alguna plataforma, alternativa de
  fallback: generar bytes y guardar directamente con `file_picker` + `dart:io`.

### Plan de rollback

- Revertir los cambios en los 5 artefactos.
- Eliminar `printing` de `pubspec.yaml`.
- Volver a poner `enabled: false` en el `PopupMenuItem`.
- Riesgo de rollback: **nulo** — no se modifica estado persistido ni esquema de
  datos.

## 9) Suposiciones

- S-01: El paquete `printing` (v5.x) es compatible con Flutter 3.10+ y funciona
  en Windows y macOS sin configuración adicional.
- S-02: La fuente Helvetica del paquete `pdf` soporta todos los caracteres
  necesarios para nombres de clientes/productos en español.
- S-03: El volumen de datos por cliente (típicamente < 50 productos) no supone
  problema de rendimiento para la generación síncrona del PDF.
- S-04: No se necesita interfaz abstracta para `OrderSheetPdfService` en esta
  iteración (el servicio es una transformación pura sin efectos secundarios que
  requieran mock).

## 10) Preguntas abiertas

- PA-01: ¿Se desea un nombre de documento específico en el diálogo de impresión?
  `Printing.layoutPdf` acepta un parámetro `name` para el job de impresión (ej:
  `"Pedido - Aida Verdes - 10/05/2026"`). Se recomienda usarlo.
- PA-02: ¿Se necesita un logotipo en el PDF en futuras iteraciones? Si sí, se
  puede preparar un `pw.MemoryImage` cargado desde assets. No se implementa en
  esta versión.

## 11) Notas para implementación

- Respetar el patrón de imports del proyecto: imports relativos con
  `../../../../` para archivos del propio feature.
- El método `_generateOrderSheetPdf` debe ser `async` porque
  `Printing.layoutPdf` es asíncrono.
- Reutilizar la lógica de `_formatNum` existente en `_OrdersTableState` para
  formatear cantidades (o extraer a un helper si se prefiere, aunque por
  simplicidad se puede duplicar en el servicio como un helper estático).
- Usar `pw.MultiPage` (no `pw.Page`) para soportar paginación automática en caso
  de muchos productos.
- El color de fondo de la cabecera de tabla en el PDF puede ser
  `PdfColors.grey300` o un tono azulado suave (`PdfColor.fromHex('#E3F2FD')`)
  para un diseño más atractivo.
- Registrar el servicio **antes** del BLoC en el módulo DI para mantener el
  orden lógico (services → usecases → BLoC).
- No olvidar regenerar los archivos de localización después de modificar
  `app_es.arb` (ejecutar `flutter gen-l10n`).
- **Estado: Listo para implementación**
