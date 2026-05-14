# Technical Analysis: Vista detalle de factura

- **Fecha:** 2026-05-13
- **Identificador:** invoice-detail-view
- **Fuente:** docs/functional-analysis/2026-05-13-invoice-detail-view.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Implementar navegación listado → detalle de factura siguiendo el patrón ya
  establecido en `ClientDetailPage` (`/clients/:id/detail`)
- Crear un `InvoiceDetailCubit` con estados loading/loaded/error que cargue la
  factura vía un nuevo use case `GetInvoiceById`
- Ampliar la entidad `InvoiceLine` y el DTO para incluir campos fiscales (`tax`,
  `taxPercentage`) que ya existen en el JSON de FD pero no se mapean
- Registrar nueva ruta `/invoices/:id/detail` en el router como sub-ruta de
  `/invoices`
- Principales áreas impactadas: `features/invoices` (domain, data,
  presentation), `app/router`, `app/di/modules/invoices_module.dart`, archivos
  i18n
- Riesgo general estimado: **bajo** — se reutilizan patrones existentes, el
  endpoint ya existe y la estructura del JSON es conocida

## 2) Contexto técnico observado

### Arquitectura y patrones

- **Clean Architecture feature-first** con capas `data/`, `domain/`,
  `presentation/`
- **Estado**: Cubit (flutter_bloc) — el feature invoices usa `InvoicesCubit` y
  `ProvisionalInvoiceCubit`
- **DI**: GetIt (`sl`) con módulos por feature en `app/di/modules/`
- **Routing**: `go_router` con `ShellRoute` para el `SideMenuShell`; sub-rutas
  anidadas (patrón en clientes: `/clients` → `/clients/:id/detail`)
- **Error handling**: `Either<Failure, T>` (fpdart); excepciones en datasource →
  Failure en repository
- **Data source**: Proxy via Cloud Functions (`fdProxy`) —
  `FacturaDirectaApiDataSourceImpl`
- **i18n**: ARB files en `lib/app/localization/l10n/`

### Módulos y capas relevantes

| Capa         | Artefacto existente                                | Rol                            |
| ------------ | -------------------------------------------------- | ------------------------------ |
| Domain       | `Invoice`, `InvoiceLine` (entities)                | Modelo de negocio              |
| Domain       | `InvoicesRepository` (abstract)                    | Contrato de datos              |
| Domain       | `GetInvoices`, `GetInvoicesByDateRange` (usecases) | Casos de uso existentes        |
| Data         | `InvoiceDto`                                       | Parseo JSON → Entity           |
| Data         | `InvoicesRepositoryImpl`                           | Implementación del repositorio |
| Data         | `FacturaDirectaApiDataSource` / impl               | Acceso al proxy FD             |
| Presentation | `InvoicesCubit`, `InvoicesState`                   | Gestión estado listado         |
| Presentation | `InvoicesPage`, `InvoiceCard`                      | UI del listado                 |
| App          | `AppRoutes`, `createRouter()`                      | Rutas                          |
| App          | `invoices_module.dart`                             | Registro DI                    |

### Restricciones relevantes

- La entidad `InvoiceLine` actual solo tiene `description`, `quantity`, `price`,
  `total` — no incluye campos fiscales
- El DTO `InvoiceDto.fromJson` ya parsea `lines` pero ignora campos `tax` del
  JSON de FD
- `getInvoiceById` devuelve `Map<String, dynamic>` (un solo objeto, no lista) —
  se puede parsear con el mismo `InvoiceDto.fromJson`
- El método `InvoiceCard` no tiene `onTap` — la card no es clickable actualmente
- La tabla desktop tiene un `InkWell` con `onTap: () {}` vacío (placeholder)

### Dependencias / integraciones

- `FacturaDirectaApiDataSource.getInvoiceById(String id)` ya implementado
- El JSON de FD para líneas incluye campos: `text`, `quantity`, `unitPrice`,
  `lineTotal`, `tax` (list de UUIDs de impuestos), y posiblemente
  `taxPercentage`
- La respuesta de `getInvoiceById` incluye `related: 'state'` en el query, por
  lo que devuelve el estado

## 3) Objetivo técnico

- **Qué debe cambiar:** Crear la capa completa (domain → data → presentation)
  para consultar y mostrar el detalle de una factura individual, incluyendo
  información fiscal por línea
- **Resultado técnico:** Una pantalla de detalle accesible por ruta
  `/invoices/:id/detail` que carga los datos desde FD y los presenta con
  cabecera, líneas con IVA y totales
- **Limitaciones:** Solo lectura, sin acciones, sin caché, sin datos adicionales
  del cliente

## 4) Diseño técnico de la solución

### Enfoque propuesto

1. **Ampliar `InvoiceLine`** con campos fiscales opcionales (`tax`,
   `taxPercentage`)
2. **Ampliar `InvoiceDto.fromJson`** para mapear los campos fiscales de las
   líneas
3. **Añadir `getInvoiceById`** al contrato `InvoicesRepository` y su
   implementación
4. **Crear use case `GetInvoiceById`** siguiendo el patrón
   `UseCase<Invoice, String>`
5. **Crear `InvoiceDetailCubit`** con estados `Initial`, `Loading`, `Loaded`,
   `Error`
6. **Crear `InvoiceDetailPage`** responsive (desktop/mobile) con secciones:
   cabecera, líneas, totales
7. **Registrar ruta** `/invoices/:id/detail` como sub-ruta de `/invoices` en el
   router
8. **Conectar navegación** desde `InvoiceCard` (mobile) y la tabla (desktop) al
   detalle
9. **Registrar DI** del nuevo use case y cubit en `invoices_module.dart`
10. **Añadir claves i18n** para los textos de la vista detalle

### Componentes / módulos / servicios afectados

- `features/invoices/domain/entities/invoice.dart` — ampliar `InvoiceLine`
- `features/invoices/domain/repositories/invoices_repository.dart` — nuevo
  método
- `features/invoices/domain/usecases/` — nuevo `GetInvoiceById`
- `features/invoices/data/dto/invoice_dto.dart` — ampliar parseo de líneas
- `features/invoices/data/repositories/invoices_repository_impl.dart` —
  implementar nuevo método
- `features/invoices/presentation/bloc/` — nuevo cubit + state
- `features/invoices/presentation/pages/` — nueva `InvoiceDetailPage`
- `features/invoices/presentation/widgets/invoice_card.dart` — añadir `onTap`
- `features/invoices/presentation/pages/invoices_page.dart` — conectar
  navegación en tabla y cards
- `app/router/router.dart` — nueva ruta
- `app/di/modules/invoices_module.dart` — registrar DI
- `app/localization/l10n/app_es.arb` — claves i18n

### Contratos e interfaces

**Nuevo método en `InvoicesRepository`:**

```dart
Future<Either<Failure, Invoice>> getInvoiceById(String id);
```

**Nuevo use case `GetInvoiceById`:**

```dart
class GetInvoiceById extends UseCase<Invoice, String> {
  final InvoicesRepository _repository;
  GetInvoiceById(this._repository);
  
  @override
  Future<Either<Failure, Invoice>> call(String params) {
    return _repository.getInvoiceById(params);
  }
}
```

**Ampliación de `InvoiceLine`:**

```dart
class InvoiceLine extends Equatable {
  final String? description;
  final double? quantity;
  final double? price;
  final double? total;
  final List<String> tax;        // UUIDs de impuestos de FD
  final double? taxPercentage;   // Porcentaje de IVA

  const InvoiceLine({
    this.description, this.quantity, this.price, this.total,
    this.tax = const [],
    this.taxPercentage,
  });
}
```

### Flujo de datos o de control

```
[UI] tap en factura
  → go_router push '/invoices/<id>/detail'
    → InvoiceDetailPage(invoiceId: id)
      → InvoiceDetailCubit.loadInvoice(id)
        → GetInvoiceById(id)
          → InvoicesRepository.getInvoiceById(id)
            → FacturaDirectaApiDataSource.getInvoiceById(id) [ya existe]
              → Cloud Function fdProxy → FD API
            ← Map<String, dynamic>
          ← InvoiceDto.fromJson(data).toEntity()
        ← Either<Failure, Invoice>
      ← emit InvoiceDetailLoaded(invoice) | InvoiceDetailError(...)
    → UI renderiza cabecera + líneas + totales
```

### Gestión de errores y validaciones

| Escenario            | Excepción en DataSource | Failure en Repository  | Estado en Cubit               |
| -------------------- | ----------------------- | ---------------------- | ----------------------------- |
| Sin red              | `NetworkException`      | `NetworkFailure`       | `InvoiceDetailError(network)` |
| Error servidor / 404 | `ServerException`       | `ServerFailure`        | `InvoiceDetailError(server)`  |
| JSON inválido        | `ParsingException`      | `EntityMappingFailure` | `InvoiceDetailError(unknown)` |

- El cubit expone un método `retry()` que re-invoca `loadInvoice` con el mismo
  ID
- Campos opcionales nulos se manejan en la UI con placeholders ("—")

### Consideraciones de compatibilidad o migración

- La ampliación de `InvoiceLine` con `tax` y `taxPercentage` es
  **retrocompatible** — ambos campos son opcionales con defaults
- Las facturas ya cargadas en el listado (`InvoicesCubit`) ya incluyen `lines`
  con los campos básicos; los nuevos campos fiscales se poblarán al parsear —
  sin impacto en la vista de listado existente
- No se rompe ningún test existente al añadir campos opcionales con default

## 5) Impacto por artefactos

### Artefactos a crear

| Artefacto                                                           | Propósito                                             |
| ------------------------------------------------------------------- | ----------------------------------------------------- |
| `lib/features/invoices/domain/usecases/get_invoice_by_id.dart`      | Use case para obtener una factura por ID              |
| `lib/features/invoices/presentation/bloc/invoice_detail_cubit.dart` | Cubit para gestión de estado del detalle              |
| `lib/features/invoices/presentation/bloc/invoice_detail_state.dart` | Estados del detalle (initial, loading, loaded, error) |
| `lib/features/invoices/presentation/pages/invoice_detail_page.dart` | Página de detalle de factura (responsive)             |

### Artefactos a modificar

| Artefacto                                                               | Cambio esperado                                             |
| ----------------------------------------------------------------------- | ----------------------------------------------------------- |
| `lib/features/invoices/domain/entities/invoice.dart`                    | Añadir `tax` y `taxPercentage` a `InvoiceLine`              |
| `lib/features/invoices/domain/repositories/invoices_repository.dart`    | Añadir método `getInvoiceById(String id)`                   |
| `lib/features/invoices/data/dto/invoice_dto.dart`                       | Parsear `tax` y `taxPercentage` de las líneas del JSON      |
| `lib/features/invoices/data/repositories/invoices_repository_impl.dart` | Implementar `getInvoiceById`                                |
| `lib/features/invoices/presentation/widgets/invoice_card.dart`          | Añadir callback `onTap` para navegación                     |
| `lib/features/invoices/presentation/pages/invoices_page.dart`           | Conectar `onTap` en card y en tabla para navegar al detalle |
| `lib/app/router/router.dart`                                            | Añadir ruta `/invoices/:id/detail` como sub-ruta            |
| `lib/app/di/modules/invoices_module.dart`                               | Registrar `GetInvoiceById` y `InvoiceDetailCubit`           |
| `lib/app/localization/l10n/app_es.arb`                                  | Añadir claves de traducción para la vista detalle           |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

1. **Paso 1 — Domain: Ampliar entidad y contrato**
   - Añadir `tax` y `taxPercentage` a `InvoiceLine`
   - Añadir `getInvoiceById(String id)` a `InvoicesRepository`
   - Crear `GetInvoiceById` use case

2. **Paso 2 — Data: Ampliar DTO y repository**
   - Actualizar `InvoiceDto.fromJson` para parsear campos fiscales de líneas
   - Implementar `getInvoiceById` en `InvoicesRepositoryImpl`

3. **Paso 3 — Presentation: Cubit + State**
   - Crear `InvoiceDetailState` (sealed class con Initial, Loading, Loaded,
     Error)
   - Crear `InvoiceDetailCubit` con `loadInvoice(String id)` y `retry()`

4. **Paso 4 — DI + Routing**
   - Registrar `GetInvoiceById` y `InvoiceDetailCubit` en `invoices_module.dart`
   - Añadir ruta `/invoices/:id/detail` en `router.dart` como sub-ruta de
     `/invoices`
   - Añadir constante `invoiceDetail` en `AppRoutes`

5. **Paso 5 — i18n**
   - Añadir claves de traducción en `app_es.arb` para la vista detalle

6. **Paso 6 — Presentation: Page + navegación**
   - Crear `InvoiceDetailPage` (responsive: desktop y mobile)
   - Añadir `onTap` callback a `InvoiceCard`
   - Conectar navegación en `InvoicesPage` (tabla desktop + card mobile)

### Orden recomendado

Paso 1 → Paso 2 → Paso 3 → Paso 4 → Paso 5 → Paso 6

### Dependencias entre pasos

- Paso 2 depende de Paso 1 (contrato del repository)
- Paso 3 depende de Paso 1 (use case)
- Paso 4 depende de Paso 3 (cubit para registrar)
- Paso 6 depende de Paso 3, 4 y 5 (cubit, ruta, traducciones)

### Puntos delicados

- **Campos fiscales en JSON de FD:** Verificar que la respuesta de
  `getInvoiceById` incluye `tax` (lista de UUIDs) y algún campo de porcentaje en
  las líneas. Si el porcentaje no está directamente en la línea, podría ser
  necesario calcularlo o mapearlo desde la lista de impuestos de FD. Esto debe
  validarse durante la implementación; si no está disponible, la columna de
  porcentaje se omite graciosamente.
- **Estructura de respuesta de `getInvoiceById`:** El método devuelve el objeto
  directamente (no envuelto en `items[]`), a diferencia de los endpoints de
  lista. El `InvoiceDto.fromJson` ya maneja esta estructura (`content.main`),
  por lo que debería funcionar directamente.
- **Sub-ruta dentro de ShellRoute:** La ruta de detalle debe ser sub-ruta de
  `/invoices` para mantener el `SideMenuShell` visible (mismo patrón que
  `clients/:id/detail`).

## 7) Estrategia de validación

### Verificación automática (tests recomendados)

- **Unit test `GetInvoiceById`:** Verificar que delega al repository y devuelve
  `Either` correctamente
- **Unit test `InvoiceDetailCubit`:** Verificar transiciones de estado
  `Initial → Loading → Loaded` y `Initial → Loading → Error` (con `bloc_test`)
- **Unit test `InvoicesRepositoryImpl.getInvoiceById`:** Verificar parseo
  correcto y mapeo de excepciones a Failures
- **Unit test `InvoiceDto.fromJson`:** Verificar que los campos fiscales se
  mapean correctamente cuando están presentes y que los defaults se usan cuando
  no están

### Validación manual

- Navegar desde el listado (tabla desktop) al detalle y verificar datos
- Navegar desde el listado (cards mobile) al detalle y verificar responsive
- Acceder directamente por URL `/invoices/<id>/detail` y verificar carga
- Verificar retorno al listado con filtros preservados
- Verificar estados de error (desconectar red, usar ID inválido)
- Verificar factura borrador (draft) muestra estado correcto
- Verificar factura con muchas líneas (scroll correcto)
- Verificar campos nulos se muestran como "—"

### Escenarios a cubrir

- Factura con líneas e impuestos → se muestra desglose completo
- Factura sin líneas → sección vacía con mensaje
- Factura borrador → estado "draft" visible
- Factura anulada → estado "voided" visible
- Error de red → mensaje con reintentar
- ID inexistente → error con mensaje descriptivo
- Acceso directo por URL → carga independiente del listado

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                              | Probabilidad | Impacto                                                           |
| ------------------------------------------------------------------- | ------------ | ----------------------------------------------------------------- |
| El JSON de FD no incluye porcentaje de IVA por línea                | Media        | Bajo — se omite el campo, se muestra solo el UUID o se deja vacío |
| La estructura del JSON de `getInvoiceById` difiere de `getInvoices` | Baja         | Medio — requeriría un DTO específico para detalle                 |

### Impacto potencial

- **Positivo:** Los usuarios pueden consultar facturas completas sin salir de la
  app
- **Negativo mínimo:** Los cambios en `InvoiceLine` son retrocompatibles (campos
  opcionales con default)
- **Sin impacto en funcionalidad existente:** El listado, la creación de
  facturas provisionales y el dashboard no se ven afectados

### Mitigación

- Validar la estructura del JSON de `getInvoiceById` al inicio de la
  implementación (loguear la respuesta cruda)
- Los campos fiscales son opcionales en la entidad — si no están disponibles, la
  UI los maneja graciosamente
- Mantener `InvoiceDto.fromJson` compatible con ambas estructuras (lista e
  individual)

### Plan de rollback

- Los cambios son aditivos (nuevos archivos + campos opcionales) — revertir es
  simplemente eliminar los archivos nuevos y los campos añadidos
- No hay migraciones de datos ni cambios destructivos
- El `onTap` vacío en la tabla se puede restaurar trivialmente

## 9) Suposiciones

- El JSON de FD devuelve `tax` como lista en cada línea de factura (coherente
  con `InvoicePreviewLine` que ya usa `List<String> tax`)
- La respuesta de `getInvoiceById` usa la misma estructura `content.main` que
  las facturas del listado
- No se necesita un DTO separado para el detalle — `InvoiceDto` se reutiliza
- El `SideMenuShell` debe permanecer visible en la vista de detalle (como en
  `ClientDetailPage`)

## 10) Preguntas abiertas

- Ninguna — el contexto técnico es suficiente para implementar. El único punto a
  validar durante implementación es la disponibilidad exacta del campo
  `taxPercentage` en el JSON de líneas de FD.

## 11) Notas para implementación

- **Patrón a seguir:** Replicar el patrón de `ClientDetailPage` para la
  estructura de la página y la navegación
- **`InvoiceCard`:** Añadir parámetro `onTap` como `VoidCallback?` — no navegar
  directamente desde el widget para mantener la separación
- **Tabla desktop:** El `InkWell` con `onTap: () {}` ya existe en la línea 567
  de `invoices_page.dart` — solo reemplazar el body vacío
- **Cubit como factory:** Registrar `InvoiceDetailCubit` como `registerFactory`
  (no singleton) para que cada navegación tenga su propia instancia
- **Sub-ruta:** Seguir exactamente el patrón de `clients` → `:id/detail` en el
  router
- **Imports del router:** Añadir el import de `InvoiceDetailPage` en
  `router.dart`
- **i18n:** Todas las cadenas visibles al usuario deben usar claves de
  `AppLocalizations`, nunca hardcodear textos
- **Design tokens:** Usar exclusivamente `AppSpacing`, `AppRadii`,
  `AppIconSizes`, `AppElevation`, etc. del tema — no hardcodear valores
- **Widget `InvoiceStatusChip`:** Reutilizar el existente en la cabecera del
  detalle
- **Estado: Listo para implementación**
