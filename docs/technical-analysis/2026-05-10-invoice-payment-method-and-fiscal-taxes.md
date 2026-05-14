# Technical Analysis: Método de pago y posición fiscal en factura provisional

- **Fecha:** 2026-05-10
- **Identificador:** invoice-payment-method-and-fiscal-taxes
- **Fuente:**
  docs/functional-analysis/2026-05-10-invoice-payment-method-and-fiscal-taxes.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Añadir un método `getContactById` al datasource de FD para obtener datos del
  contacto (método de pago y posición fiscal).
- Modificar `PrepareInvoicePreview` para consultar el contacto FD, aplicar
  impuestos de RE cuando `fiscalPositions.sales == 'aut_re'`, y propagar
  `paymentMethod` al `InvoicePreview`.
- Modificar `CreateProvisionalInvoice` para incluir `paymentMethod` en el body
  del POST.
- Adaptar `InvoicePreview` / `InvoicePreviewLine` y el dialog de preview para
  reflejar los impuestos compuestos (IVA + RE).
- **Principales áreas impactadas:** datasource FD, use cases de facturación,
  entidades de preview, dialog de preview.
- **Riesgo general estimado:** bajo — cambios aditivos sobre flujo existente
  funcional.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first, BLoC/Cubit, GetIt DI, fpdart Either.
- El datasource FD (`FacturaDirectaApiDataSource`) expone métodos genéricos que
  devuelven `Map<String, dynamic>` (sin tipado fuerte a nivel de DTO para
  contactos).

### Módulos relevantes

| Artefacto                                                                    | Rol                                               |
| ---------------------------------------------------------------------------- | ------------------------------------------------- |
| `lib/core/data/datasources/factura_directa_api_data_source.dart`             | Contrato abstracto del datasource FD              |
| `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`        | Implementación con Dio                            |
| `lib/features/invoices/domain/usecases/prepare_invoice_preview.dart`         | Construye el preview con precios/impuestos        |
| `lib/features/invoices/domain/usecases/create_provisional_invoice.dart`      | Construye body y hace POST a FD                   |
| `lib/features/invoices/domain/entities/invoice_preview.dart`                 | Entidades `InvoicePreview` / `InvoicePreviewLine` |
| `lib/features/invoices/presentation/widgets/provisional_invoice_dialog.dart` | Dialog UI de preview                              |
| `lib/app/di/modules/invoices_module.dart`                                    | Registro DI                                       |

### Restricciones

- La API key no tiene permisos `settings:read`, por lo que no se puede usar
  `GET /settings/taxes/sales`. Los tax IDs de RE están verificados y se
  hardcodean en el mapeo.
- El datasource FD ya expone `getContacts(companyId)` que lista todos los
  contactos, pero no tiene un método para obtener uno individual.

### Datos verificados en la API de FD

| Dato                        | Valor                                         |
| --------------------------- | --------------------------------------------- |
| Posición fiscal RE          | `fiscalPositions.sales = 'aut_re'`            |
| RE para IVA 21%             | `S_IVA_RE_5.2`                                |
| RE para IVA 10%             | `S_IVA_RE_1.4`                                |
| Campo método de pago        | `main.receivePaymentMethod` → `pam_<uuid-v4>` |
| Contactos con RE            | 76 de 242 (31%)                               |
| Contactos con paymentMethod | 234 de 242 (97%)                              |

## 3) Objetivo técnico

- **Qué debe cambiar:** El flujo de generación de factura provisional debe
  obtener datos del contacto FD para incluir método de pago y aplicar impuestos
  de RE.
- **Resultado:** Las facturas creadas vía API son idénticas a las creadas
  manualmente en FD en cuanto a impuestos y método de pago.
- **Limitaciones:** No se soportan posiciones fiscales distintas a `aut_re`
  (como `emp_ic`) en esta iteración. No se soporta IVA 4% con RE (no existe en
  la cuenta).

## 4) Diseño técnico de la solución

### Enfoque propuesto

Añadir una nueva llamada `GET /{companyId}/contacts/{contactId}` al datasource
FD, e inyectar el datasource FD en `PrepareInvoicePreview` (que ya tiene acceso
a `SettingsRepository` para el token). El use case consulta el contacto, extrae
`receivePaymentMethod` y `fiscalPositions.sales`, y:

1. Si es `aut_re`, aplica el mapeo de tax IDs de RE a cada línea.
2. Propaga `paymentMethod` al `InvoicePreview`.

El `CreateProvisionalInvoice` lee `paymentMethod` del preview e incluye el campo
en el body del POST.

### Componentes / módulos / servicios afectados

1. **`FacturaDirectaApiDataSource`** (abstracto): nuevo método `getContactById`.
2. **`FacturaDirectaApiDataSourceImpl`**: implementación de `getContactById` con
   `_get('/$companyId/contacts/$contactId')`.
3. **`InvoicePreview`**: nuevo campo `paymentMethod` (String?).
4. **`InvoicePreviewLine`**: el campo `taxPercentage` (double?) se reemplaza por
   `taxDetails` (List de tuplas `{id, label, percentage, amount}`) para soportar
   múltiples impuestos por línea.
5. **`PrepareInvoicePreview`**: inyectar datasource FD, obtener contacto,
   aplicar RE, recalcular impuestos.
6. **`CreateProvisionalInvoice`**: leer `preview.paymentMethod` e incluirlo en
   body.
7. **`ProvisionalInvoiceDialog`**: adaptar columna de impuestos y desglose para
   mostrar múltiples impuestos.
8. **`invoices_module.dart`**: actualizar registro de `PrepareInvoicePreview`
   para inyectar el datasource FD.

### Contratos e interfaces

**Nuevo método en `FacturaDirectaApiDataSource`:**

```dart
Future<Map<String, dynamic>> getContactById(
  String companyId,
  String contactId,
);
```

**Cambio en `InvoicePreview`:**

```dart
class InvoicePreview {
  // ... campos existentes ...
  final String? paymentMethod; // NUEVO
}
```

**Cambio en `InvoicePreviewLine`:** Actualmente `taxPercentage` es un `double?`
que extrae solo el primer impuesto. Para soportar IVA + RE, se necesita
representar múltiples impuestos. Se propone mantener `taxPercentage` como
resumen para compatibilidad del dialog y añadir la lista completa de tax IDs ya
ajustada (con RE si aplica) en el campo `tax` existente. El desglose de
impuestos en `InvoicePreview.taxBreakdown` debe calcularse por cada tax ID
individual, no solo por el porcentaje principal.

### Flujo de datos

```
1. PrepareInvoicePreview.call(params)
   │
   ├─ (existente) Obtener cliente de Firestore → clientFdUuid
   ├─ (existente) Obtener productos de Firestore → fdUuids
   ├─ (existente) Obtener FD products → precios + tax IDs
   │
   ├─ (NUEVO) GET /contacts/{clientFdUuid} → contactData
   │   ├─ receivePaymentMethod → paymentMethod
   │   └─ fiscalPositions.sales → salesFiscalPosition
   │
   ├─ (NUEVO) SI salesFiscalPosition == 'aut_re':
   │   └─ Para cada línea, añadir RE tax ID al array tax
   │       S_IVA_21 → + S_IVA_RE_5.2
   │       S_IVA_10 → + S_IVA_RE_1.4
   │
   ├─ (MODIFICADO) Calcular taxBreakdown con TODOS los tax IDs
   │   (no solo el porcentaje principal)
   │
   └─ return InvoicePreview(
        ..., paymentMethod: paymentMethod
      )

2. CreateProvisionalInvoice.call(preview)
   │
   └─ body.content.main:
       ├─ (existente) contact, currency, date, draft, lines
       └─ (NUEVO) paymentMethod: preview.paymentMethod
```

### Gestión de errores y validaciones

- **Error en GET contacto:** Si la llamada a `getContactById` falla
  (ServerException, NetworkException), se propaga como error al cubit y se
  detiene el flujo. No se intenta crear la factura sin datos del contacto.
- **Contacto sin `fiscalPositions`:** Si el campo no existe o es nulo, se asume
  posición fiscal estándar (no se añade RE). Sin error.
- **`receivePaymentMethod` nulo:** Se acepta y no se incluye `paymentMethod` en
  el body. Sin error.
- **Tax ID de IVA no mapeado para RE:** Si un producto tiene un tax ID distinto
  de `S_IVA_21` o `S_IVA_10`, no se añade RE a esa línea. Sin error.

### Consideraciones de compatibilidad o migración

- No hay migración de datos.
- El campo `paymentMethod` en `InvoicePreview` es nullable, lo que mantiene
  compatibilidad con previews ya construidos.
- La lógica de `_extractTaxPercentage` se debe revisar para que funcione con tax
  IDs reales de FD (formato `S_IVA_10`, `S_IVA_21`, `S_IVA_RE_1.4`,
  `S_IVA_RE_5.2`) en lugar del formato asumido anteriormente.

## 5) Impacto por artefactos

### Artefactos a crear

Ninguno.

### Artefactos a modificar

| Artefacto                                                                    | Cambio esperado                                                                                     |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `lib/core/data/datasources/factura_directa_api_data_source.dart`             | Añadir método `getContactById`                                                                      |
| `lib/core/data/datasources/factura_directa_api_data_source_impl.dart`        | Implementar `getContactById`                                                                        |
| `lib/features/invoices/domain/entities/invoice_preview.dart`                 | Añadir campo `paymentMethod` a `InvoicePreview`                                                     |
| `lib/features/invoices/domain/usecases/prepare_invoice_preview.dart`         | Inyectar datasource FD, obtener contacto, aplicar RE, mapear paymentMethod, recalcular taxBreakdown |
| `lib/features/invoices/domain/usecases/create_provisional_invoice.dart`      | Incluir `paymentMethod` en body del POST                                                            |
| `lib/features/invoices/presentation/widgets/provisional_invoice_dialog.dart` | Adaptar columna de impuestos y desglose para múltiples tax IDs                                      |
| `lib/app/di/modules/invoices_module.dart`                                    | Pasar datasource FD a `PrepareInvoicePreview`                                                       |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Pasos

1. **Ampliar datasource FD:** Añadir `getContactById` al abstracto e
   implementación.

2. **Ampliar `InvoicePreview`:** Añadir campo `paymentMethod` (String?).

3. **Modificar `PrepareInvoicePreview`:**
   - Añadir dependencia del datasource FD.
   - Tras obtener los FD products, hacer
     `getContactById(companyId, clientFdUuid)`.
   - Extraer `receivePaymentMethod` y `fiscalPositions.sales`.
   - Si `aut_re`, aplicar mapeo de RE a cada línea (modificar el array `tax` de
     cada `InvoicePreviewLine`).
   - Recalcular `taxBreakdown` iterando por cada tax ID de cada línea con un
     mapeo de porcentajes conocidos.
   - Pasar `paymentMethod` al `InvoicePreview`.

4. **Modificar `CreateProvisionalInvoice`:**
   - Leer `preview.paymentMethod`.
   - Si no es nulo, incluir `'paymentMethod': preview.paymentMethod` en
     `content.main` del body.

5. **Adaptar dialog de preview:**
   - La columna "Impuesto" de cada línea debe mostrar los impuestos aplicados
     (ej: "10% + RE 1,4%").
   - El desglose de impuestos (`taxBreakdown`) ya contendrá las entradas
     separadas para IVA y RE, que se renderizarán como líneas individuales.

6. **Actualizar DI:**
   - Actualizar registro de `PrepareInvoicePreview` para inyectar el datasource
     FD como dependencia adicional.

### Orden recomendado

1 → 2 → 3 → 6 → 4 → 5

### Dependencias entre pasos

- Paso 3 depende de 1 y 2.
- Paso 6 depende de 3.
- Paso 4 depende de 2.
- Paso 5 depende de 3 (necesita los datos de taxBreakdown correctos).

### Puntos delicados

- **Cálculo de porcentajes de RE:** Los tax IDs de RE tienen formato
  `S_IVA_RE_5.2` y `S_IVA_RE_1.4`. Se necesita un mapeo estático de tax ID a
  porcentaje para calcular los importes de impuestos en la preview. Este mapeo
  ya se puede hardcodear con los valores verificados:

  ```
  S_IVA_21 → 21.0%
  S_IVA_10 → 10.0%
  S_IVA_RE_5.2 → 5.2%
  S_IVA_RE_1.4 → 1.4%
  ```

- **Reemplazo de `_extractTaxPercentage`:** La función actual extrae un solo
  porcentaje del primer tax ID. Debe reemplazarse por una lógica que itere por
  todos los tax IDs de la línea y calcule el importe de cada impuesto
  individualmente para el `taxBreakdown`.

- **Columna "Impuesto" del dialog:** Actualmente muestra un solo porcentaje. Con
  RE, una línea puede tener dos impuestos. Se sugiere mostrar el resumen como
  "10% + RE" o "21% + RE" para mantener la columna compacta.

- **`setApiToken` en `PrepareInvoicePreview`:** El use case necesita configurar
  el token del datasource FD antes de hacer la llamada. Esto ya se hace en
  `GetFdProducts` (que ya se invoca en el mismo flujo), por lo que el token ya
  estará configurado cuando se llame a `getContactById`.

## 7) Estrategia de validación

### Verificación automática

- `flutter analyze` sin errores.
- Verificar que las facturas creadas incluyen el campo `paymentMethod`.
- Verificar que las líneas de facturas para clientes `aut_re` incluyen los tax
  IDs de RE.

### Validación manual

- Crear una factura provisional para un cliente con `aut_re` y verificar en la
  web de FD que:
  - El método de pago aparece.
  - Los impuestos de RE aparecen en cada línea.
  - El total coincide con el que genera la web de FD para los mismos
    productos/cantidades.
- Crear una factura para un cliente `emp` (sin RE) y verificar que no se añaden
  impuestos de RE y que el método de pago aparece.
- Crear una factura para un cliente sin `receivePaymentMethod` y verificar que
  la factura se crea correctamente sin método de pago.

### Escenarios a cubrir

| Escenario                                 | Resultado esperado                        |
| ----------------------------------------- | ----------------------------------------- |
| Cliente `aut_re` con productos IVA 10%    | Líneas con `['S_IVA_10', 'S_IVA_RE_1.4']` |
| Cliente `aut_re` con productos IVA 21%    | Líneas con `['S_IVA_21', 'S_IVA_RE_5.2']` |
| Cliente `aut_re` con mezcla IVA 10% y 21% | Cada línea con su RE correspondiente      |
| Cliente `emp` (sin RE)                    | Líneas sin tax IDs de RE                  |
| Cliente con `receivePaymentMethod`        | Factura con `paymentMethod`               |
| Cliente sin `receivePaymentMethod`        | Factura sin `paymentMethod`               |
| Error en GET contacto                     | Error en cubit, flujo detenido            |

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **Bajo:** Tax IDs de RE hardcodeados podrían cambiar si FD actualiza su
  catálogo fiscal. Probabilidad muy baja.
- **Bajo:** La llamada adicional GET al contacto añade latencia (~100-200ms).
  Impacto negligible.

### Impacto potencial

- Las facturas para clientes `aut_re` tendrán importes correctos (mayores que
  antes, por los recargos de RE). Esto es el comportamiento **correcto**.
- Todas las facturas incluirán método de pago (si el contacto lo tiene
  configurado).

### Mitigación

- El mapeo de RE es un `Map<String, String>` constante fácil de ampliar si se
  añaden nuevos tipos de IVA/RE.
- Si la llamada al contacto falla, el flujo se detiene con error informativo (no
  se crea factura incorrecta).

### Plan de rollback

- Revertir los cambios en los 7 archivos modificados. No hay migración de datos
  ni cambios de estado en FD.

## 9) Suposiciones

- Los tax IDs `S_IVA_RE_5.2` y `S_IVA_RE_1.4` son estables y no cambian.
- El token de la API ya está configurado en el datasource cuando se invoca
  `getContactById` (porque `GetFdProducts` ya se ha ejecutado antes en el mismo
  flujo de `PrepareInvoicePreview`).
- `fiscalPositions.sales` es el único campo relevante para determinar si se
  aplica RE (no se necesita consultar `fiscalPositions.purchases`).
- La API FD acepta el campo `paymentMethod` en el POST de creación de factura
  (verificado en el OpenAPI spec: `InvoiceWrite.main.paymentMethod` es
  `string, nullable`).

## 10) Preguntas abiertas

Ninguna. Todos los datos han sido verificados directamente contra la API.

## 11) Notas para implementación

- **Mapeo constante de RE:**
  ```dart
  static const _reMapping = {
    'S_IVA_21': 'S_IVA_RE_5.2',
    'S_IVA_10': 'S_IVA_RE_1.4',
  };
  ```

- **Mapeo de tax ID a porcentaje para el cálculo del taxBreakdown:**
  ```dart
  static const _taxPercentages = {
    'S_IVA_21': 21.0,
    'S_IVA_10': 10.0,
    'S_IVA_4': 4.0,
    'S_IVA_RE_5.2': 5.2,
    'S_IVA_RE_1.4': 1.4,
    'S_IVA_RE_0.5': 0.5,
  };
  ```

- **Extracción de datos del contacto:**
  ```dart
  final contactData = response['content']['main'];
  final paymentMethod = contactData['receivePaymentMethod'] as String?;
  final fiscalPosition = (contactData['fiscalPositions']
      as Map<String, dynamic>?)?['sales'] as String?;
  ```

- No olvidar que `_extractTaxPercentage` se usa actualmente para la columna
  "Impuesto" del dialog. Al tener múltiples impuestos, la lógica de display debe
  adaptarse.

- El token del datasource FD ya estará configurado por el flujo de
  `GetFdProducts`, que se ejecuta antes en `PrepareInvoicePreview`. No es
  necesario volver a llamar a `setApiToken`.

- Respetar el orden de parámetros del constructor de `PrepareInvoicePreview` al
  añadir el nuevo parámetro del datasource FD, y actualizar consistentemente el
  registro en `invoices_module.dart`.

- **Estado: Listo para implementación**
