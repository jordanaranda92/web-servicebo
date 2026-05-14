# Technical Analysis: Productos desde Google Sheet con enriquecimiento Factura Directa

- **Fecha:** 2026-05-07
- **Identificador:** products-google-sheet-source
- **Fuente:**
  docs/functional-analysis/2026-05-07-products-google-sheet-source.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- **Enfoque:** Invertir la fuente de datos de la feature `products`: pasar de
  Factura Directa como fuente única a Google Sheets como fuente primaria con
  enriquecimiento desde Factura Directa, replicando (con inversión) el patrón ya
  implementado en `clients`.
- **Áreas impactadas:** Todos los artefactos de la feature `products` (entity,
  DTOs, repository, use case, cubit, state, page) y el módulo DI. También se
  añaden claves i18n.
- **Riesgo general estimado:** Bajo. La entidad `Product` solo se consume dentro
  de su propia feature (confirmado vía análisis de usages). No hay impacto en
  `orders_today`, `orders_history`, `delivery_notes`, `invoices` ni ningún otro
  módulo.

## 2) Contexto técnico observado

### Arquitectura

- **Clean Architecture feature-first** con capas `data/`, `domain/`,
  `presentation/`.
- **BLoC (Cubit)** para gestión de estado.
- **GetIt** para inyección de dependencias.
- **fpdart** (`Either<Failure, T>`) para manejo funcional de errores.

### Patrón de referencia: Clientes

La feature `clients` implementa exactamente el patrón de carga dual que se
necesita:

| Aspecto                  | Clientes (actual)                      | Productos (nuevo)                                      |
| ------------------------ | -------------------------------------- | ------------------------------------------------------ |
| Fuente primaria          | Factura Directa API                    | Google Sheets (hoja "productos")                       |
| Fuente enriquecimiento   | Google Sheets (hoja "clientes")        | Factura Directa API                                    |
| Clave de cruce           | UUID (FD) → Sheet busca por UUID       | UUID Factura Directa (Sheet col H) → FD busca por UUID |
| Si falla fuente primaria | Error bloqueante                       | Error bloqueante                                       |
| Si falla enriquecimiento | Warning + datos parciales              | Warning + datos parciales (columnas FD vacías)         |
| Resultado                | `ClientsResult(clients, sheetWarning)` | `ProductsResult(products, fdWarning)`                  |

### Estructura actual de productos

```
features/products/
├── data/
│   ├── dto/product_dto.dart              ← parsea JSON de FD
│   └── repositories/products_repository_impl.dart  ← solo FD
├── domain/
│   ├── entities/product.dart             ← campos FD (id, name, sku, salesPrice, ...)
│   ├── repositories/products_repository.dart       ← Either<Failure, List<Product>>
│   └── usecases/get_products.dart
└── presentation/
    ├── bloc/products_cubit.dart
    ├── bloc/products_state.dart
    └── pages/products_page.dart          ← tabla 3 columnas (Nombre, Código, Precio)
```

### Dependencias actuales del repositorio

`ProductsRepositoryImpl(FacturaDirectaApiDataSource, SettingsRepository)` — 2
dependencias.

### Datasources reutilizables

- `GoogleSheetsDataSource` (core) — `readRange(spreadsheetId, range)` devuelve
  `List<List<String>>`.
- `GoogleDriveRemoteDataSource` (settings) — `listSpreadsheets(folderId)` para
  localizar el spreadsheet "configuracion".
- `FacturaDirectaApiDataSource` (core) — `getProducts(companyId)` devuelve
  `List<Map<String, dynamic>>`.

Todos ya están registrados en GetIt como `LazySingleton`.

### Restricciones

- La entidad `Product` no se usa fuera de su feature (0 imports externos
  confirmados).
- No existen tests para la feature products actualmente.
- Las claves i18n existentes para products: `productsSearch`, `productsEmpty`,
  `productsColumnName`, `productsColumnSku`, `productsColumnPrice`.

## 3) Objetivo técnico

- Rediseñar la entidad `Product` para contener campos de ambas fuentes (Sheet +
  FD).
- Crear un `ProductSheetDto` como fuente primaria de datos.
- Reutilizar `ProductDto` (FD) solo para construir el mapa de enriquecimiento
  UUID → (nombre, precio, moneda).
- Reescribir `ProductsRepositoryImpl` con el patrón de carga dual (Sheet
  primario, FD enriquecimiento).
- Introducir `ProductsResult` con `fdWarning` para gestionar degradación.
- Adaptar cubit, state y UI a la nueva estructura de 8 columnas.
- Actualizar DI para inyectar las 2 dependencias adicionales.
- Añadir claves i18n para las nuevas columnas.

### Limitaciones a respetar

- No tocar ninguna otra feature.
- No romper el contrato de `FacturaDirectaApiDataSource.getProducts()`.
- Respetar Clean Architecture: entity pura, DTO en data, cubit solo depende de
  use case.

## 4) Diseño técnico de la solución

### Enfoque propuesto

1. La entidad `Product` se rediseña con campos de ambas fuentes.
2. `ProductSheetDto` parsea las filas de Google Sheets y genera las entidades
   base.
3. `ProductDto` (FD) se simplifica/mantiene para parsear JSON de FD y extraer
   `(uuid, name, salesPrice, currency)`.
4. `ProductsRepositoryImpl` carga Sheet + FD en paralelo, cruza por UUID, y
   devuelve `ProductsResult`.
5. Si Sheet falla → `Left(Failure)`. Si FD falla →
   `Right(ProductsResult(..., fdWarning: "..."))`.

### Componentes / módulos / servicios afectados

Todos dentro de `lib/features/products/` +
`lib/app/di/modules/products_module.dart` + archivo ARB de i18n.

### Contratos e interfaces

**Entidad `Product` (nueva):**

```
Product {
  int id                     // Sheet col B
  String name                // Sheet col C
  bool? isActive             // Sheet col D
  String? color              // Sheet col G (hex)
  bool? showInNewOrders      // Sheet col E
  int? orderInNewOrders      // Sheet col F
  String? fdProductName      // FD name (enriquecido)
  double? fdSalesPrice       // FD salesPrice (enriquecido)
  String? fdCurrency         // FD currency (enriquecido)
}
```

**`ProductsResult` (nuevo):**

```
ProductsResult {
  List<Product> products
  String? fdWarning
}
```

**`ProductsRepository` (modificado):**

```dart
Future<Either<Failure, ProductsResult>> getProducts();
```

**`ProductSheetDto` (nuevo):**

```
ProductSheetDto {
  int id
  String name
  bool? isActive
  bool? showInNewOrders
  int? orderInNewOrders
  String? color
  String? fdUuid

  static List<ProductSheetDto> parseSheet(List<List<String>> rows)
  Product toEntity()  // convierte a Product sin campos FD
}
```

### Flujo de datos o de control

```
ProductsPage → ProductsCubit → GetProducts → ProductsRepository
                                                    │
                                   ┌────────────────┴────────────────┐
                                   ▼                                 ▼
                         _loadSheetData()                   FD API getProducts()
                         (GDrive → Sheets)                  (parallel)
                                   │                                 │
                                   ▼                                 ▼
                        List<ProductSheetDto>            Map<String, FdProductInfo>
                                   │                                 │
                                   └────────────┬────────────────────┘
                                                ▼
                                     _enrichProducts()
                                   (cruce por fdUuid)
                                                │
                                                ▼
                                  ProductsResult(products, fdWarning?)
```

**Detalle del cruce:**

1. Construir `Map<String, _FdProductInfo>` desde la respuesta de FD, indexado
   por UUID.
2. Para cada `ProductSheetDto`:
   - Convertir a `Product` base via `toEntity()`.
   - Si `fdUuid` no es nulo/vacío y existe en el mapa FD → copiar
     `fdProductName`, `fdSalesPrice`, `fdCurrency`.
   - Si no → dejar campos FD como `null`.
3. Ordenar por `orderInNewOrders` ascendente (nulos al final).

### Gestión de errores y validaciones

| Escenario                                 | Comportamiento                                               |
| ----------------------------------------- | ------------------------------------------------------------ |
| Google Drive no configurado               | `Left(ConfigNotFoundFailure())` — misma gestión que clientes |
| Spreadsheet "configuracion" no encontrado | `Left(ServerFailure())` con log descriptivo                  |
| Hoja "productos" vacía o no encontrada    | `Right(ProductsResult([], null))` — tabla vacía              |
| FD config no encontrada                   | `Right(ProductsResult(sheetProducts, "FD no configurado"))`  |
| FD API error (network/server)             | `Right(ProductsResult(sheetProducts, "Error FD"))`           |
| Ambos fallan                              | `Left(Failure)` del error de Sheet (fuente primaria)         |
| Filas vacías en Sheet                     | Se ignoran (filtrar por ID/Nombre no vacío)                  |
| Hex color inválido                        | Se pasa como String; la UI aplicará fallback                 |

### Consideraciones de compatibilidad o migración

- No hay impacto en otras features: `Product` solo se usa internamente.
- El campo `sku` (código) se elimina de la entidad ya que la nueva tabla no lo
  muestra. Si en el futuro se necesita, se puede re-añadir.
- La columna "Código" (SKU) desaparece del filtro de búsqueda; se reemplaza por
  filtro en `name` y `fdProductName`.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                    | Propósito                                                      |
| ------------------------------------------------------------ | -------------------------------------------------------------- |
| `lib/features/products/data/dto/product_sheet_dto.dart`      | DTO para parsear filas de la hoja "productos" de Google Sheets |
| `lib/features/products/domain/entities/products_result.dart` | Wrapper del resultado con lista de productos + fdWarning       |

### Artefactos a modificar

| Artefacto                                                               | Cambio esperado                                                                                                                                                                                                                                              |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `lib/features/products/domain/entities/product.dart`                    | Rediseñar campos: quitar sku/salesDescription/purchasesPrice, añadir isActive/color/showInNewOrders/orderInNewOrders/fdProductName/fdSalesPrice/fdCurrency                                                                                                   |
| `lib/features/products/data/dto/product_dto.dart`                       | Simplificar: solo extraer uuid, name, salesPrice, currency de FD JSON. Eliminar `toEntity()`, reemplazar por método que devuelva un record/map para enriquecimiento                                                                                          |
| `lib/features/products/domain/repositories/products_repository.dart`    | Cambiar retorno a `Either<Failure, ProductsResult>`                                                                                                                                                                                                          |
| `lib/features/products/data/repositories/products_repository_impl.dart` | Reescribir: inyectar GoogleSheetsDataSource + GoogleDriveRemoteDataSource, implementar carga dual, cruce por UUID, gestión de errores degradada                                                                                                              |
| `lib/features/products/domain/usecases/get_products.dart`               | Cambiar tipo de retorno a `ProductsResult`                                                                                                                                                                                                                   |
| `lib/features/products/presentation/bloc/products_cubit.dart`           | Adaptar a `ProductsResult`, actualizar `filterByName` para filtrar por `name` y `fdProductName`                                                                                                                                                              |
| `lib/features/products/presentation/bloc/products_state.dart`           | Añadir `fdWarning` a `ProductsLoaded`                                                                                                                                                                                                                        |
| `lib/features/products/presentation/pages/products_page.dart`           | Rediseñar tabla: 8 columnas, indicador visual de color, booleanos como Sí/No, warning banner para FD                                                                                                                                                         |
| `lib/app/di/modules/products_module.dart`                               | Añadir `sl()` para GoogleSheetsDataSource y GoogleDriveRemoteDataSource (de 2 a 4 deps)                                                                                                                                                                      |
| `lib/app/localization/l10n/app_es.arb`                                  | Añadir claves: `productsColumnId`, `productsColumnActive`, `productsColumnColor`, `productsColumnShowInOrders`, `productsColumnOrderInOrders`, `productsColumnFdProduct`, `productsYes`, `productsNo` (o reutilizar existentes). Retirar `productsColumnSku` |

### Artefactos a retirar o reemplazar

| Artefacto                      | Motivo                                     |
| ------------------------------ | ------------------------------------------ |
| Clave i18n `productsColumnSku` | La columna "Código" desaparece de la tabla |

## 6) Estrategia de implementación

1. **Paso 1 — Entidad y resultado:** Rediseñar `Product` y crear
   `ProductsResult`.
2. **Paso 2 — DTO de Sheet:** Crear `ProductSheetDto` con `parseSheet()` y
   `toEntity()`.
3. **Paso 3 — DTO de FD:** Simplificar `ProductDto` para exponer solo los datos
   de enriquecimiento (uuid, name, salesPrice, currency).
4. **Paso 4 — Contrato del repositorio:** Actualizar `ProductsRepository` para
   devolver `ProductsResult`.
5. **Paso 5 — Implementación del repositorio:** Reescribir
   `ProductsRepositoryImpl` con carga dual, cruce por UUID y gestión de errores
   degradada.
6. **Paso 6 — Use case:** Actualizar `GetProducts` al nuevo tipo de retorno.
7. **Paso 7 — State:** Añadir `fdWarning` a `ProductsLoaded`.
8. **Paso 8 — Cubit:** Adaptar `ProductsCubit` para manejar `ProductsResult` y
   actualizar filtro.
9. **Paso 9 — i18n:** Añadir nuevas claves ARB y regenerar.
10. **Paso 10 — UI:** Rediseñar `products_page.dart` con 8 columnas, color
    indicator, booleanos, warning banner.
11. **Paso 11 — DI:** Actualizar `products_module.dart` con las 2 dependencias
    adicionales.

### Orden recomendado

Estrictamente secuencial de dominio → data → presentación → DI, ya que cada capa
depende de la anterior.

### Dependencias entre pasos

- Pasos 1-3 son independientes entre sí.
- Paso 4 depende de paso 1.
- Paso 5 depende de pasos 2, 3 y 4.
- Paso 6 depende de paso 4.
- Pasos 7-8 dependen de paso 6.
- Paso 9 es independiente.
- Paso 10 depende de pasos 7, 8 y 9.
- Paso 11 depende de paso 5.

### Puntos delicados

- **Rango de lectura del Sheet:** El rango `productos!B3:I` debe coincidir con
  la estructura real de la hoja. Si las cabeceras están en fila 3 y los datos
  desde fila 4, `B3:I` incluye la fila de cabeceras (necesario para
  `parseSheet`).
- **Formato del color hex:** El Sheet almacena `#FFFFFF`. La UI debe interpretar
  el valor y mostrar un indicador visual. Validar que el parsing de hex sea
  robusto (con/sin `#`).
- **Ordenamiento:** Productos sin `orderInNewOrders` deben ir al final. Usar
  `int.maxValue` como sentinel o comparar con null-aware.

## 7) Estrategia de validación

### Verificación automática

- Compilación limpia (`flutter analyze`) tras cada paso.
- Tests unitarios recomendados para:
  - `ProductSheetDto.parseSheet()` — filas válidas, filas vacías, valores
    inválidos.
  - `ProductsRepositoryImpl` — mock de Sheet + FD, cruce correcto, degradación
    cuando FD falla.
  - `ProductsCubit` — estados correctos, filtro por nombre y fdProductName.

### Verificación manual

- Abrir la pantalla de Productos y verificar las 8 columnas.
- Verificar producto con UUID FD → columnas FD rellenas.
- Verificar producto sin UUID FD → columnas FD vacías.
- Desconectar FD y verificar warning + columnas FD vacías.
- Probar el buscador con nombre de sheet y nombre FD.
- Verificar indicador visual de color.
- Verificar orden por "Orden en nuevos pedidos".

### Escenarios de cobertura

- Happy path: Sheet + FD OK, productos con y sin UUID.
- FD falla: productos de Sheet sin enriquecimiento + warning.
- Sheet vacío: tabla vacía con mensaje.
- Sheet no configurado: error bloqueante.
- Datos inválidos en Sheet (color hex roto, orden no numérico): degradación
  controlada.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                    | Probabilidad | Impacto                   |
| --------------------------------------------------------- | ------------ | ------------------------- |
| Rango del Sheet no coincide con la estructura real        | Baja         | Alto — sin datos          |
| Campos consumidos por otras features en el futuro         | Baja         | Medio — requiere revisión |
| Rendimiento con muchos productos (Sheet + FD en paralelo) | Baja         | Bajo — igual que clientes |

### Impacto potencial

- La pantalla de Productos cambia completamente su fuente de datos y columnas
  mostradas.
- El filtro de búsqueda cambia de (name + sku) a (name + fdProductName).

### Mitigación

- Verificar el rango del Sheet con datos reales antes del deploy.
- El patrón es probado (idéntico a clientes): bajo riesgo técnico.

### Plan de rollback

- Revertir el commit. La feature es autocontenida y no afecta a otros módulos.

## 9) Suposiciones

- El spreadsheet "configuracion" y la hoja "productos" existen y tienen el
  formato descrito en la captura (fila 3 = cabeceras, datos desde fila 4).
- Las columnas del Sheet son fijas en orden: B=ID, C=Nombre, D=Activo, E=Mostrar
  en nuevos pedidos, F=Orden en nuevos pedidos, G=Color por defecto, H=UUID
  Factura Directa, I=Nombre Factura Directa.
- El rango de lectura será `productos!B3:I` (cabeceras + datos).
- Los datasources `GoogleSheetsDataSource` y `GoogleDriveRemoteDataSource` ya
  están registrados en GetIt y funcionan correctamente.
- No se requiere paginación: el catálogo de productos cabe en una sola lectura.

## 10) Preguntas abiertas

Ninguna. Todas las preguntas del análisis funcional fueron resueltas.

## 11) Notas para implementación

- **Patrón de referencia directo:** `ClientsRepositoryImpl` en
  `lib/features/clients/data/repositories/clients_repository_impl.dart`.
  Replicar la estructura `_loadSheetData()` + `_enrichProducts()` con la
  inversión de flujo descrita.
- **`ProductSheetDto.parseSheet()`** debe seguir el mismo patrón que
  `ClientSheetDto.parseSheet()`: leer cabeceras de la primera fila, construir
  índice de columnas, iterar filas restantes.
- **Rango de lectura:** `productos!B3:I`. La columna A está vacía en el Sheet y
  se omite.
- **Construcción del mapa FD:** Iterar los productos de FD y crear
  `Map<String, _FdProductInfo>` donde la key es `content.uuid` y el value
  contiene `(name, salesPrice, currency)`.
- **Color en UI:** Parsear el hex (`#FFFFFF` → `Color(0xFFFFFFFF)`) y mostrar un
  `Container` circular de ~16px con ese color. Si el hex es inválido, mostrar un
  container gris o sin color.
- **Booleanos en UI:** Mostrar texto localizado "Sí" / "No" (usar claves i18n
  existentes tipo `commonYes`/`commonNo` o crear `productsYes`/`productsNo`).
- **Warning FD:** Mostrar un banner discreto sobre la tabla (similar al patrón
  de clientes) cuando `fdWarning` no sea null.
- **No romper comportamiento existente:** Aunque no hay consumers externos de
  `Product`, asegurar que la compilación sea limpia antes de merge.
- **Estado: Listo para implementación**
