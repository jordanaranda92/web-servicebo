# Technical Analysis: Generación de factura provisional en Factura Directa

- **Fecha:** 2026-05-10
- **Identificador:** generate-provisional-invoice
- **Fuente:**
  docs/functional-analysis/2026-05-10-generate-provisional-invoice.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- **Enfoque:** Crear un nuevo Cubit (`ProvisionalInvoiceCubit`) dentro de la
  feature `invoices` que orqueste el flujo completo: validación de vinculación,
  consolidación de productos, obtención de precios de FD, detección de
  duplicados, y creación de la factura provisional. La UI se implementa como un
  diálogo modal lanzado desde el menú contextual de `OrdersTable`.
- **Áreas impactadas:**
  - `lib/core/data/datasources/` — nuevo método `createInvoice` +
    `getInvoicesByContact`
  - `lib/features/products/domain/entities/` — ampliar `FdProduct`
  - `lib/features/products/domain/usecases/` — ampliar `GetFdProducts`
  - `lib/features/invoices/` — nuevas entities, use cases, cubit, widgets
  - `lib/features/orders_today/presentation/widgets/` — habilitar menú y
    callback
  - `lib/app/di/modules/invoices_module.dart` — registrar nuevas dependencias
  - `lib/app/localization/l10n/app_es.arb` — nuevas claves i18n
- **Riesgo general estimado:** medio — la integración API ya existe pero se
  añade la primera operación de escritura (POST) y un flujo complejo con
  múltiples validaciones.

## 2) Contexto técnico observado

### Arquitectura

Clean Architecture feature-first con BLoC/Cubit, GetIt (DI), fpdart (`Either`).
Capas: `domain/` (entities, repos, usecases) → `data/` (datasources, DTOs, repos
impl) → `presentation/` (blocs, pages, widgets).

### Módulos relevantes

| Módulo         | Rol actual                                                                                                                                                                 |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `invoices`     | Tiene `Invoice`, `InvoiceLine` entities, `InvoicesRepository` (solo `getInvoices`), `InvoiceDto` (parsea respuesta GET), `InvoicesCubit` (listado, filtrado, paginación)   |
| `products`     | `Product` entity (Firestore), `FdProduct` entity (API FD, solo `uuid`, `name`, `salesPrice`, `currency`), `GetFdProducts` use case (parsea GET)                            |
| `clients`      | `Client` entity con `facturaDirectaUuid` (ya incluye `con_`), `ClientsRepository` con `getClients()`                                                                       |
| `orders_today` | `OrderSheet` entity con `clientIds[]`, `productIds[]`, `quantities[][]`. `OrdersTable` widget con menú contextual placeholder                                              |
| `core`         | `FacturaDirectaApiDataSource` (abstract: `getContacts`, `getProducts`, `getInvoices`, `getInvoiceById`), impl con Dio, helpers `_get`, `_authOptions`, `_validateResponse` |
| `settings`     | `FacturaDirectaConfig` (`companyId`, `apiToken`), `SettingsRepository`                                                                                                     |

### Restricciones

- Solo se permite `POST /{companyId}/invoices` con `draft: true`. No se debe
  realizar ninguna otra llamada POST.
- Los UUID de FD ya incluyen prefijos (`con_`, `pro_`).
- Serie hardcodeada `"B"`.
- Moneda siempre `EUR`.

### Dependencias externas

- **API Factura Directa v1.0.9** — ya integrada con Dio.
- **Firestore** — para clients y products (ya integrado).

## 3) Objetivo técnico

- Añadir capacidad de escritura (POST) al datasource de FD.
- Ampliar `FdProduct` con `salesTax` y `salesDescription` que faltan.
- Crear un use case que orqueste la preparación del preview de factura
  (validaciones + obtención de datos + consolidación).
- Crear un use case para la creación efectiva de la factura provisional.
- Crear un use case para la detección de facturas provisionales duplicadas.
- Implementar un Cubit dedicado que gestione los estados del flujo.
- Implementar el diálogo de preview y los diálogos de error/aviso.
- Conectar el menú contextual existente con el nuevo flujo.

### Limitaciones a respetar

- No introducir dependencias nuevas.
- Respetar la estructura feature-first existente.
- El `OrdersTodayBloc` no debe asumir responsabilidades del flujo de factura; el
  nuevo Cubit es independiente.
- No crear DTOs de request; el body JSON se construye directamente en el
  datasource o repositorio, ya que la estructura es simple y fija.

## 4) Diseño técnico de la solución

### Enfoque propuesto

El flujo se organiza en tres fases claramente separadas:

1. **Preparación** (use case `PrepareInvoicePreview`): Recibe los datos del
   OrderSheet para un cliente específico. Obtiene `Client` y `Product` entities
   de Firestore, valida vinculación FD, consolida productos duplicados, obtiene
   precios/impuestos de la API FD. Devuelve un `InvoicePreview` listo para
   mostrar.

2. **Detección de duplicados** (use case `CheckDuplicateInvoice`): Consulta
   facturas existentes en FD filtrando por contacto y rango de fecha. Devuelve
   un booleano indicando si hay facturas provisionales previas.

3. **Creación** (use case `CreateProvisionalInvoice`): Recibe el
   `InvoicePreview` confirmado y envía el POST a FD. Devuelve el `Invoice`
   creado.

El `ProvisionalInvoiceCubit` orquesta las tres fases y expone estados que la UI
consume para mostrar loading, preview, avisos y resultados.

### Componentes / módulos / servicios afectados

#### Core — `FacturaDirectaApiDataSource`

Añadir al contrato abstracto y a la implementación:

```dart
// Nuevo: crear factura
Future<Map<String, dynamic>> createInvoice(
  String companyId,
  Map<String, dynamic> body,
);

// Nuevo: buscar facturas filtradas por contacto y fecha (para duplicados)
Future<List<Map<String, dynamic>>> getInvoicesByContact(
  String companyId, {
  required String contactUuid,
  required String minDate,
  required String maxDate,
  String? draft,
});
```

La implementación necesita un método `_post` similar a `_get`:

```dart
Future<Response<dynamic>> _post(String path, {required Map<String, dynamic> data}) async {
  final url = '$_baseUrl$path';
  dev.log('[FD API] POST $url', name: 'FD');
  try {
    final response = await _dio.post(url, data: data, options: _authOptions(_apiToken));
    _validateResponse(response);
    return response;
  } on DioException catch (e) {
    _handleDioException(e);
  }
}
```

`createInvoice` usa `_post('/$companyId/invoices', data: body)`.

`getInvoicesByContact` usa `_get` con query params:
`/$companyId/invoices?contact=$contactUuid&minDate=$minDate&maxDate=$maxDate&draft=$draft&limit=5`.

#### Products — `FdProduct` entity

Añadir dos campos:

```dart
final List<String> salesTax;     // IDs de impuesto, e.g. ["tax_iva21"]
final String? salesDescription;  // Descripción de venta del producto
```

#### Products — `GetFdProducts` use case

Ampliar el parsing dentro del bucle `for` para extraer `sales['tax']` y
`sales['description']`:

```dart
final salesTax = (sales['tax'] as List<dynamic>?)
    ?.map((e) => e.toString())
    .toList() ?? [];
final salesDescription = sales['description'] as String?;
```

#### Invoices — Nuevas entities

**`InvoicePreviewLine`** (inmutable, Equatable):

| Campo           | Tipo           | Descripción                                    |
| --------------- | -------------- | ---------------------------------------------- |
| `fdProductUuid` | `String`       | UUID del producto en FD (con prefijo)          |
| `productName`   | `String`       | Nombre del producto (de FD)                    |
| `quantity`      | `num`          | Cantidad total (consolidada si hay duplicados) |
| `unitPrice`     | `double`       | Precio unitario de venta en FD                 |
| `tax`           | `List<String>` | IDs de impuesto del producto en FD             |
| `taxPercentage` | `double?`      | Porcentaje de impuesto para mostrar en UI      |
| `description`   | `String?`      | Descripción de venta del producto en FD        |
| `lineTotal`     | `double`       | `quantity * unitPrice`                         |

**`InvoicePreview`** (inmutable, Equatable):

| Campo          | Tipo                       | Descripción                           |
| -------------- | -------------------------- | ------------------------------------- |
| `clientName`   | `String`                   | Nombre del cliente                    |
| `clientFdUuid` | `String`                   | UUID del cliente en FD                |
| `date`         | `String`                   | Fecha del pedido (YYYY-MM-DD)         |
| `lines`        | `List<InvoicePreviewLine>` | Líneas consolidadas                   |
| `subtotal`     | `double`                   | Suma de `lineTotal`                   |
| `taxBreakdown` | `Map<String, double>`      | Desglose: clave tax → importe         |
| `total`        | `double`                   | `subtotal + sum(taxBreakdown.values)` |

#### Invoices — Nuevos use cases

**`PrepareInvoicePreview`**

- **Params:** `String clientId`, `String date`, `List<String> productIds`,
  `List<num> quantities` (cantidades por producto para este cliente).
- **Dependencias:** `ClientsRepository`, `ProductsRepository`, `GetFdProducts`,
  `SettingsRepository`.
- **Retorno:** `Either<Failure, InvoicePreview>`.
- **Lógica:**
  1. Obtener config FD. Si no existe → `ConfigNotFoundFailure`.
  2. Obtener lista de clients de Firestore. Buscar el client por `clientId`.
  3. Validar que `client.facturaDirectaUuid` no esté vacío. Si está vacío →
     `ClientNotLinkedFailure`.
  4. Obtener lista de products de Firestore. Filtrar los que están en
     `productIds` y tienen `quantity > 0`.
  5. Validar que todos tengan `facturaDirectaUuid` no vacío. Si hay productos
     sin vincular → `ProductsNotLinkedFailure(productNames)`.
  6. Consolidar: agrupar por `facturaDirectaUuid`, sumando cantidades.
  7. Llamar a `GetFdProducts` para obtener precios y tax de FD.
  8. Para cada grupo consolidado, buscar el `FdProduct` correspondiente por
     UUID. Si no se encuentra → `ProductNotFoundInFdFailure(productName)`.
  9. Construir `InvoicePreviewLine` por cada grupo.
  10. Calcular subtotal, desglose de impuestos y total.
  11. Devolver `InvoicePreview`.

**`CheckDuplicateInvoice`**

- **Params:** `String contactUuid`, `String date`.
- **Dependencias:** `FacturaDirectaApiDataSource`, `SettingsRepository`.
- **Retorno:** `Either<Failure, bool>`.
- **Lógica:**
  1. Obtener config FD.
  2. Llamar a
     `getInvoicesByContact(companyId, contactUuid, minDate: date,
     maxDate: date, draft: 'only')`.
  3. Si la lista es no vacía → `Right(true)`. Si vacía → `Right(false)`.

**`CreateProvisionalInvoice`**

- **Params:** `InvoicePreview preview`.
- **Dependencias:** `FacturaDirectaApiDataSource`, `SettingsRepository`.
- **Retorno:** `Either<Failure, Invoice>`.
- **Lógica:**
  1. Obtener config FD.
  2. Construir el body JSON:
     ```json
     {
       "content": {
         "type": "invoice",
         "main": {
           "docNumber": { "series": "B" },
           "contact": "<preview.clientFdUuid>",
           "currency": "EUR",
           "date": "<preview.date>",
           "draft": true,
           "lines": [ ... ]
         }
       }
     }
     ```
  3. Llamar a `createInvoice(companyId, body)`.
  4. Parsear la respuesta con `InvoiceDto.fromJson(response)` → `toEntity()`.
  5. Devolver `Right(invoice)`.

#### Invoices — Nuevos Failures

| Failure                                        | Propósito                                             |
| ---------------------------------------------- | ----------------------------------------------------- |
| `ClientNotLinkedFailure`                       | El cliente no tiene `facturaDirectaUuid`              |
| `ProductsNotLinkedFailure(List<String> names)` | Productos sin vincular a FD                           |
| `ProductNotFoundInFdFailure(String name)`      | Producto local vinculado pero no encontrado en API FD |
| `NoLinesFailure`                               | No hay productos con cantidad > 0                     |

Estos failures se definen en `lib/features/invoices/domain/entities/` o en un
fichero dedicado `invoice_failures.dart` dentro de
`lib/features/invoices/domain/`.

#### Invoices — `ProvisionalInvoiceCubit`

**Estados** (sealed class `ProvisionalInvoiceState`):

| Estado                               | Campos                                                      | Descripción               |
| ------------------------------------ | ----------------------------------------------------------- | ------------------------- |
| `ProvisionalInvoiceInitial`          | —                                                           | Estado por defecto        |
| `ProvisionalInvoiceLoading`          | —                                                           | Obteniendo datos de FD    |
| `ProvisionalInvoicePreview`          | `InvoicePreview preview`                                    | Preview listo             |
| `ProvisionalInvoiceDuplicateWarning` | `InvoicePreview preview`                                    | Preview + aviso duplicado |
| `ProvisionalInvoiceCreating`         | `InvoicePreview preview`                                    | Enviando POST             |
| `ProvisionalInvoiceSuccess`          | `Invoice invoice`                                           | Factura creada            |
| `ProvisionalInvoiceError`            | `ProvisionalInvoiceErrorType type`, `List<String>? details` | Error                     |

**`ProvisionalInvoiceErrorType`** (enum):

`configNotFound`, `clientNotLinked`, `productsNotLinked`, `productNotFoundInFd`,
`noLines`, `network`, `server`, `unknown`.

**Métodos:**

```
prepare(clientId, date, productIds, quantities)
  1. emit(Loading)
  2. call PrepareInvoicePreview → fold:
     - Left → emit(Error) con tipo mapeado
     - Right(preview) → call CheckDuplicateInvoice:
       - Left → emit(Error) (error de red/servidor, no bloquea; se puede
         optar por mostrar preview sin aviso)
       - Right(true) → emit(DuplicateWarning(preview))
       - Right(false) → emit(Preview(preview))

confirm(preview)
  1. emit(Creating(preview))
  2. call CreateProvisionalInvoice → fold:
     - Left → emit(Error)
     - Right(invoice) → emit(Success(invoice))
```

#### Orders Today — `OrdersTable`

- Habilitar el `PopupMenuItem` de `'generate_provisional_invoice'`
  (`enabled: true`).
- Añadir un callback `onGenerateProvisionalInvoice` al widget `OrdersTable`.
- En el `switch` de `_showClientContextMenu`, manejar el case
  `'generate_provisional_invoice'` invocando el callback con los datos del
  cliente: `col` (índice de columna), para que la capa superior extraiga los
  datos necesarios del `OrderSheet`.
- En `_OrdersTodayContentState`, pasar el callback a `OrdersTable`. El callback:
  1. Extrae del `OrderSheet`: `clientIds[col]`, `date`, `productIds`, y
     `quantities[p][col]` para cada producto.
  2. Crea una instancia de `ProvisionalInvoiceCubit` desde `sl()`.
  3. Muestra el diálogo `ProvisionalInvoiceDialog` pasándole el cubit y los
     datos de entrada.

#### UI — `ProvisionalInvoiceDialog`

Widget de diálogo modal que:

1. Recibe un `ProvisionalInvoiceCubit` y los datos de entrada (clientId, date,
   productIds, quantities).
2. En `initState` llama a `cubit.prepare(...)`.
3. Usa `BlocBuilder` para renderizar según el estado:
   - `Loading` → `CircularProgressIndicator` centrado.
   - `Preview` → Tabla con líneas, subtotal, impuestos, total. Botones
     «Cancelar» / «Generar factura provisional».
   - `DuplicateWarning` → Igual que `Preview` pero con un banner de aviso
     amarillo arriba indicando que ya existe una factura provisional para ese
     cliente y fecha. Los botones permanecen disponibles.
   - `Creating` → Misma vista que Preview pero con botón deshabilitado y
     spinner.
   - `Success` → Mensaje de éxito con número de documento. Botón «Cerrar».
   - `Error` → Mensaje de error según tipo. Botón «Cerrar».

Ubicación:
`lib/features/invoices/presentation/widgets/provisional_invoice_dialog.dart`.

### Contratos e interfaces

#### Nuevos métodos en `FacturaDirectaApiDataSource` (abstracta)

```dart
Future<Map<String, dynamic>> createInvoice(
  String companyId,
  Map<String, dynamic> body,
);

Future<List<Map<String, dynamic>>> getInvoicesByContact(
  String companyId, {
  required String contactUuid,
  required String minDate,
  required String maxDate,
  String? draft,
});
```

#### Nuevos métodos en `InvoicesRepository`

```dart
Future<Either<Failure, Invoice>> createProvisionalInvoice(
  Map<String, dynamic> body,
);

Future<Either<Failure, bool>> checkDuplicateInvoice({
  required String contactUuid,
  required String date,
});
```

### Flujo de datos

```
OrdersTable (click derecho → menú contextual)
  │
  ├─ extrae: clientId, date, productIds, quantities[p][col]
  │
  ▼
ProvisionalInvoiceCubit.prepare(...)
  │
  ├─ ClientsRepository.getClients() → filtra por clientId
  │   └─ valida facturaDirectaUuid no vacío
  │
  ├─ ProductsRepository.getProducts() → filtra por productIds con qty > 0
  │   └─ valida facturaDirectaUuid no vacío en todos
  │
  ├─ consolida productos por facturaDirectaUuid (suma cantidades)
  │
  ├─ GetFdProducts(NoParams) → obtiene precios + tax de API FD
  │   └─ mapea cada grupo consolidado a su FdProduct
  │
  ├─ construye InvoicePreview (líneas, subtotal, tax, total)
  │
  ├─ CheckDuplicateInvoice → GET /invoices?contact=X&minDate=D&maxDate=D&draft=only
  │   └─ si hay resultados → DuplicateWarning, si no → Preview
  │
  ▼
UI: ProvisionalInvoiceDialog (muestra preview / aviso)
  │
  ├─ usuario confirma
  │
  ▼
ProvisionalInvoiceCubit.confirm(preview)
  │
  ├─ CreateProvisionalInvoice → POST /invoices con draft: true
  │   └─ parsea respuesta → Invoice entity
  │
  ▼
UI: muestra éxito con docNumber
```

### Gestión de errores y validaciones

| Escenario                        | Failure                                  | UI                                            |
| -------------------------------- | ---------------------------------------- | --------------------------------------------- |
| Config FD no existe              | `ConfigNotFoundFailure`                  | Error: «Configura Factura Directa en Ajustes» |
| Cliente sin UUID FD              | `ClientNotLinkedFailure`                 | Error: «El cliente no está vinculado a FD»    |
| Productos sin UUID FD            | `ProductsNotLinkedFailure(names)`        | Error: lista de productos no vinculados       |
| Sin productos con qty > 0        | `NoLinesFailure`                         | Error: «No hay productos para facturar»       |
| Producto no encontrado en API FD | `ProductNotFoundInFdFailure(name)`       | Error: «Producto X no encontrado en FD»       |
| Error de red                     | `NetworkFailure`                         | Error: «Sin conexión»                         |
| Error de servidor (4xx/5xx)      | `ServerFailure`                          | Error: «Error del servidor»                   |
| Credenciales inválidas (401/403) | `ServerFailure`                          | Error: «Credenciales de FD inválidas»         |
| Check duplicado falla por red    | No bloquea, se muestra preview sin aviso | —                                             |

### Consideraciones de compatibilidad o migración

- Los cambios en `FdProduct` (nuevos campos con valores por defecto) son
  retrocompatibles. `salesTax` tiene default `[]`, `salesDescription` es
  nullable.
- Los nuevos métodos en `FacturaDirectaApiDataSource` son aditivos; no rompen la
  interfaz existente (se añaden, no se modifican los existentes).
- El `InvoiceDto.fromJson` existente ya parsea la estructura de respuesta de la
  API y se reutiliza para la respuesta del POST.

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                                    | Propósito                                                                                                                  |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/invoices/domain/entities/invoice_preview.dart`                 | Entities `InvoicePreview` e `InvoicePreviewLine`                                                                           |
| `lib/features/invoices/domain/invoice_failures.dart`                         | Failures específicos: `ClientNotLinkedFailure`, `ProductsNotLinkedFailure`, `ProductNotFoundInFdFailure`, `NoLinesFailure` |
| `lib/features/invoices/domain/usecases/prepare_invoice_preview.dart`         | Use case de preparación/validación                                                                                         |
| `lib/features/invoices/domain/usecases/check_duplicate_invoice.dart`         | Use case de detección de duplicados                                                                                        |
| `lib/features/invoices/domain/usecases/create_provisional_invoice.dart`      | Use case de creación POST                                                                                                  |
| `lib/features/invoices/presentation/bloc/provisional_invoice_cubit.dart`     | Cubit con estados del flujo                                                                                                |
| `lib/features/invoices/presentation/bloc/provisional_invoice_state.dart`     | Estados sealed del Cubit                                                                                                   |
| `lib/features/invoices/presentation/widgets/provisional_invoice_dialog.dart` | Diálogo de preview/resultado                                                                                               |

### Artefactos a modificar

| Artefacto                                                               | Cambio esperado                                                 |
| ----------------------------------------------------------------------- | --------------------------------------------------------------- |
| `lib/core/data/datasources/factura_directa_api_data_source.dart`        | Añadir `createInvoice` y `getInvoicesByContact` al contrato     |
| `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`   | Implementar `_post`, `createInvoice` y `getInvoicesByContact`   |
| `lib/features/products/domain/entities/fd_product.dart`                 | Añadir `salesTax` (List<String>) y `salesDescription` (String?) |
| `lib/features/products/domain/usecases/get_fd_products.dart`            | Parsear `sales['tax']` y `sales['description']`                 |
| `lib/features/invoices/domain/repositories/invoices_repository.dart`    | Añadir `createProvisionalInvoice` y `checkDuplicateInvoice`     |
| `lib/features/invoices/data/repositories/invoices_repository_impl.dart` | Implementar los dos nuevos métodos                              |
| `lib/features/orders_today/presentation/widgets/orders_table.dart`      | Habilitar menú, añadir callback `onGenerateProvisionalInvoice`  |
| `lib/features/orders_today/presentation/pages/orders_today_page.dart`   | Pasar callback, instanciar cubit, mostrar diálogo               |
| `lib/app/di/modules/invoices_module.dart`                               | Registrar nuevos use cases y cubit                              |
| `lib/app/localization/l10n/app_es.arb`                                  | Añadir claves i18n para diálogos y mensajes                     |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Pasos ordenados

1. **Ampliar `FdProduct` y `GetFdProducts`**
   - Añadir `salesTax` y `salesDescription` a `FdProduct`.
   - Parsear `sales['tax']` y `sales['description']` en `GetFdProducts`.
   - Verificar que no se rompe ningún uso existente de `FdProduct`.

2. **Ampliar `FacturaDirectaApiDataSource`**
   - Añadir `createInvoice` y `getInvoicesByContact` al contrato abstracto.
   - Implementar `_post` en la implementación.
   - Implementar `createInvoice` (usa `_post`).
   - Implementar `getInvoicesByContact` (usa `_get` con query params).

3. **Crear entities de dominio del flujo de factura**
   - `InvoicePreview`, `InvoicePreviewLine` en `invoices/domain/entities/`.
   - Failures específicos en `invoices/domain/`.

4. **Crear use cases**
   - `PrepareInvoicePreview` — validación + consolidación + obtención de datos.
   - `CheckDuplicateInvoice` — consulta GET filtrada.
   - `CreateProvisionalInvoice` — POST a la API.

5. **Ampliar `InvoicesRepository`**
   - Añadir contrato y implementación de `createProvisionalInvoice` y
     `checkDuplicateInvoice`.

6. **Crear `ProvisionalInvoiceCubit` y estados**
   - Estados sealed.
   - Métodos `prepare` y `confirm`.

7. **Crear `ProvisionalInvoiceDialog`**
   - UI del diálogo con todos los estados visuales.

8. **Conectar con `OrdersTable` y `OrdersTodayPage`**
   - Habilitar menú contextual.
   - Añadir callback.
   - Instanciar cubit y mostrar diálogo.

9. **Registrar dependencias en GetIt**
   - Actualizar `invoices_module.dart`.

10. **Añadir claves i18n**
    - Todos los textos visibles al usuario en `app_es.arb`.

### Orden recomendado

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10

Los pasos 1 y 2 son independientes entre sí y pueden hacerse en paralelo. Los
pasos 3-5 forman un bloque de dominio. Los pasos 6-7 son presentación. El paso 8
integra todo. Los pasos 9-10 son transversales que se pueden ir completando
junto con cada paso.

### Dependencias entre pasos

- Paso 4 depende de 1, 2 y 3.
- Paso 5 depende de 2 y 3.
- Paso 6 depende de 4 y 5.
- Paso 7 depende de 6.
- Paso 8 depende de 7.
- Paso 9 depende de 4, 5 y 6.

### Puntos delicados

- **Consolidación de productos:** La lógica de agrupar por `facturaDirectaUuid`
  y sumar cantidades debe ser cuidadosa para no perder precisión numérica. Usar
  `num` (como ya hace `OrderSheet.quantities`).
- **Parsing de tax IDs:** El campo `sales.tax` de la API FD es una lista de
  strings (IDs de impuesto, e.g. `["tax_iva21"]`). Estos IDs se pasan tal cual
  al POST. Para mostrar el porcentaje en la UI, se necesita una heurística o un
  mapeo conocido (e.g. `tax_iva21` → 21%). Si la API no proporciona el
  porcentaje directamente, se puede extraer del nombre con regex o hardcodear
  los valores conocidos del negocio.
- **Error en check de duplicados no debe bloquear:** Si la llamada GET para
  detectar duplicados falla (red, timeout), el flujo debe continuar mostrando el
  preview sin aviso, no bloquearse.
- **Gestión del cubit lifecycle:** El `ProvisionalInvoiceCubit` se crea por cada
  invocación del flujo y se destruye al cerrar el diálogo. Usar
  `registerFactory` en GetIt.

## 7) Estrategia de validación

### Verificación automática (tests unitarios)

| Componente                    | Qué verificar                                                                                                                                                                                                                                                                    |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PrepareInvoicePreview`       | Mock de repos y GetFdProducts. Probar: cliente sin UUID → `ClientNotLinkedFailure`; producto sin UUID → `ProductsNotLinkedFailure`; consolidación de productos duplicados suma correctamente; sin productos qty > 0 → `NoLinesFailure`; cálculos de subtotal/tax/total correctos |
| `CheckDuplicateInvoice`       | Mock de datasource. Probar: lista no vacía → `true`; lista vacía → `false`; error de red → failure propagado                                                                                                                                                                     |
| `CreateProvisionalInvoice`    | Mock de datasource. Probar: body correcto enviado; respuesta parseada; error manejado                                                                                                                                                                                            |
| `ProvisionalInvoiceCubit`     | Mock de use cases. Probar secuencias de estados: prepare → Loading → Preview; prepare con duplicado → Loading → DuplicateWarning; prepare con error → Loading → Error; confirm → Creating → Success; confirm con error → Creating → Error                                        |
| `FdProduct` / `GetFdProducts` | Verificar que salesTax y salesDescription se parsean correctamente                                                                                                                                                                                                               |

### Verificación manual

- Flujo completo: click derecho → menú → preview → confirmar → factura creada en
  FD como provisional.
- Verificar en la web de Factura Directa que la factura aparece como borrador
  con los datos correctos.
- Probar con cliente sin vincular → diálogo de error correcto.
- Probar con productos sin vincular → diálogo con lista correcta.
- Probar con múltiples productos apuntando al mismo FdProduct → una sola línea
  con cantidad sumada.
- Probar cancelar en preview → no se crea nada.
- Probar con factura provisional previa existente → aviso de duplicado.
- Probar sin conexión a internet → error de red.

### Escenarios de edge case a cubrir

- Un solo producto con qty > 0.
- Producto con precio 0 en FD.
- Producto sin impuestos en FD.
- Cantidad fraccionaria (e.g., 0.5).
- Cerrar diálogo con Escape.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                      | Probabilidad | Impacto                                                                                   |
| --------------------------------------------------------------------------- | ------------ | ----------------------------------------------------------------------------------------- |
| Tax IDs de FD no contienen info de porcentaje para la UI                    | Media        | Bajo — se puede mostrar el ID en lugar del porcentaje, o hardcodear los valores conocidos |
| La API de FD cambia el formato de respuesta del POST                        | Baja         | Medio — el parsing fallaría y se mostraría error                                          |
| Performance: obtener todos los FdProducts para buscar precios de unos pocos | Baja         | Bajo — la API ya se usa así y el volumen es limitado                                      |

### Impacto potencial

- **Positivo:** Primera funcionalidad de escritura en FD. Reduce drásticamente
  el tiempo de facturación.
- **Negativo si falla:** Se crearía una factura incorrecta en FD. Mitigado
  porque es siempre provisional (draft) y el usuario puede eliminarla en FD.

### Mitigación

- Draft obligatorio (hardcodeado `true`, nunca configurable).
- Preview con todos los datos calculados antes de confirmar.
- Aviso de duplicado para evitar facturas repetidas.
- Tests unitarios para cálculos y construcción del body.

### Plan de rollback

- Los cambios son aditivos (nuevos ficheros, nuevos métodos). El rollback
  consiste en revertir los commits.
- Si el POST a FD genera problemas, basta con volver a deshabilitar el item del
  menú contextual (`enabled: false`) sin necesidad de revertir el resto del
  código.

## 9) Suposiciones

- El endpoint `GET /{companyId}/invoices` acepta los query params `contact`,
  `minDate`, `maxDate` y `draft` para filtrar. Si no acepta `contact`, se filtra
  client-side sobre los resultados.
- El campo `sales.tax` de la API FD devuelve una lista de strings con IDs de
  impuesto. Si devuelve otra estructura, se adaptará el parsing.
- La respuesta del `POST /{companyId}/invoices` tiene la misma estructura que un
  `GET` individual de factura y se puede parsear con `InvoiceDto.fromJson`.
- El volumen de productos en FD es suficientemente bajo para que `GetFdProducts`
  (que obtiene todos) no tenga problemas de rendimiento.

## 10) Preguntas abiertas

- **PT-01:** ¿El endpoint GET de invoices de FD soporta filtro por `contact`
  como query param? Si no, la detección de duplicados filtrará client-side.
- **PT-02:** ¿Cómo mapear los tax IDs (e.g. `tax_iva21`) a porcentajes para la
  UI? Opciones: (a) extraer con regex del nombre, (b) hardcodear un mapa de IDs
  conocidos, (c) llamar al endpoint GET de taxes si existe. Se recomienda (b)
  como solución pragmática inicial.

## 11) Notas para implementación

- **Restricción fundamental:** El campo `draft` en el body del POST SIEMPRE debe
  ser `true`. Bajo ninguna circunstancia se debe permitir `false`. Hardcodear en
  el use case, no aceptar como parámetro.
- **Serie:** Hardcodear `"B"` en `CreateProvisionalInvoice`. Definir como
  constante para facilitar futura configuración.
- **Moneda:** Hardcodear `"EUR"`.
- **Lifecycle del Cubit:** Registrar como `registerFactory` en GetIt. Crear una
  instancia nueva por cada invocación del diálogo. Cerrar al desmontar.
- **i18n:** Todos los textos visibles al usuario deben usar claves de
  `app_es.arb`. No hardcodear strings en widgets.
- **No romper comportamiento existente:** Los cambios en `FdProduct` deben
  mantener los constructores existentes con valores por defecto para los nuevos
  campos. Los cambios en `FacturaDirectaApiDataSource` son aditivos.
- **El callback en OrdersTable** debe recibir solo el `col` (índice de columna).
  La extracción de datos del `OrderSheet` la realiza la capa superior
  (`_OrdersTodayContentState`) que ya tiene acceso al `OrderSheet`.
- **Estado: Listo para implementación**
