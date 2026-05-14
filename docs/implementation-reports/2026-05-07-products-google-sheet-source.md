# Implementation Report: Productos desde Google Sheet con enriquecimiento Factura Directa

- **Fecha:** 2026-05-07
- **Identificador:** products-google-sheet-source
- **Plan técnico:**
  docs/technical-analysis/2026-05-07-products-google-sheet-source.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado el cambio de fuente de datos de la feature `products`: la
fuente primaria es ahora Google Sheets (hoja "productos" del spreadsheet
"configuracion") y se enriquece con datos de Factura Directa (nombre y precio)
mediante cruce por UUID. La tabla de la UI muestra 8 columnas según la
especificación funcional. La compilación es limpia sin errores ni warnings.

## 2) Alcance ejecutado

- Rediseño completo de la entidad `Product` con campos de ambas fuentes
- Nuevo `ProductsResult` con `fdWarning` para degradación controlada
- Nuevo `ProductSheetDto` para parsear la hoja "productos" de Google Sheets
- Simplificación de `ProductDto` (FD) como fuente de enriquecimiento
- Reescritura de `ProductsRepositoryImpl` con patrón de carga dual (Sheet
  primario + FD enriquecimiento)
- Actualización del contrato `ProductsRepository`, use case `GetProducts`, state
  y cubit
- Rediseño de la UI con 8 columnas: ID, Nombre, Activo, Color, Mostrar en
  pedidos, Orden, Producto FD, Precio
- Indicador visual de color (círculo con color hex)
- Warning banner cuando FD no está disponible
- Nuevas claves i18n generadas
- Actualización del módulo DI (de 2 a 4 dependencias)

## 3) Artefactos tocados

### Creados

- `lib/features/products/data/dto/product_sheet_dto.dart`
- `lib/features/products/domain/entities/products_result.dart`

### Modificados

- `lib/features/products/domain/entities/product.dart`
- `lib/features/products/data/dto/product_dto.dart`
- `lib/features/products/domain/repositories/products_repository.dart`
- `lib/features/products/data/repositories/products_repository_impl.dart`
- `lib/features/products/domain/usecases/get_products.dart`
- `lib/features/products/presentation/bloc/products_state.dart`
- `lib/features/products/presentation/bloc/products_cubit.dart`
- `lib/features/products/presentation/pages/products_page.dart`
- `lib/app/di/modules/products_module.dart`
- `lib/app/localization/l10n/app_es.arb`
- `lib/app/localization/l10n/app_localizations.dart` (auto-generado)
- `lib/app/localization/l10n/app_localizations_es.dart` (auto-generado)

### Retirados o reemplazados

- Clave i18n `productsColumnSku` reemplazada por las nuevas claves de columna

## 4) Validación ejecutada

- **flutter analyze** sobre `lib/features/products/` y
  `lib/app/di/modules/products_module.dart`: **0 issues**
- **IDE errors check**: **0 errores**
- Verificación manual de que todas las claves i18n se generaron correctamente (9
  nuevas claves confirmadas)
- Verificación de que `Product` no tiene imports externos a su feature (sin
  impacto en otros módulos)

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** El análisis técnico sugería eliminar `toEntity()` de
  `ProductDto` y reemplazarlo por un record/map. Se optó por simplificar el DTO
  directamente a los 4 campos de enriquecimiento (`uuid`, `name`, `salesPrice`,
  `currency`) sin `toEntity()`, exponiendo los campos directamente para el mapa
  de cruce. Es más simple y directo.
- **Justificación:** Menor complejidad, mismo resultado funcional.
- **Impacto:** Ninguno.

- **Desviación 2:** En el repositorio, el mapa de cruce `fdUuids` se implementó
  como `Map<int, String>` (product ID → UUID FD) y se pasa como parámetro
  separado a `_enrichProducts()`, en lugar de pasar el UUID a través de la
  entidad. Esto mantiene la entidad limpia (sin campo temporal `fdUuid`).
- **Justificación:** Respetar la pureza de la entidad de dominio.
- **Impacto:** Ninguno.

## 6) Riesgos, incidencias y pendientes

- **Riesgo:** El rango de lectura del Sheet (`productos!B3:I`) debe coincidir
  con la estructura real de la hoja de Google Sheets. Si las cabeceras no
  coinciden exactamente, `ProductSheetDto.parseSheet()` no encontrará las
  columnas. Se recomienda validar con datos reales.
- **Pendiente:** Tests unitarios — no existían tests para la feature products y
  no se han creado en esta implementación. Se recomienda añadir tests para:
  - `ProductSheetDto.parseSheet()`
  - `ProductsRepositoryImpl` (mock de Sheet + FD)
  - `ProductsCubit` (estados y filtro)
- **Pendiente:** Validación manual end-to-end con datos reales del Google Sheet
  y Factura Directa.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual con datos reales + creación de
  tests unitarios
