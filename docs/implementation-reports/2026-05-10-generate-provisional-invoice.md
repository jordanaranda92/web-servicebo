# Implementation Report: Generación de factura provisional en Factura Directa

- **Fecha:** 2026-05-10
- **Identificador:** generate-provisional-invoice
- **Plan técnico:**
  docs/technical-analysis/2026-05-10-generate-provisional-invoice.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado la funcionalidad completa de generación de factura
provisional en Factura Directa desde el menú contextual de cliente en la tabla
de pedidos del día. El flujo incluye validación de vinculación, consolidación de
productos duplicados, obtención de precios/impuestos de la API de FD, detección
de facturas provisionales duplicadas, preview interactivo y creación de la
factura mediante POST.

`flutter analyze` pasa sin errores. Solo quedan 2 `info` preexistentes en código
no relacionado.

## 2) Alcance ejecutado

- Todas las partes del plan técnico se han implementado.
- Se ha omitido la ampliación de `InvoicesRepository` (ver desviaciones).

## 3) Artefactos tocados

### Creados

- `lib/features/invoices/domain/entities/invoice_preview.dart` — entities
  `InvoicePreview` e `InvoicePreviewLine`
- `lib/features/invoices/domain/invoice_failures.dart` — failures específicos:
  `ClientNotLinkedFailure`, `ProductsNotLinkedFailure`,
  `ProductNotFoundInFdFailure`, `NoLinesFailure`
- `lib/features/invoices/domain/usecases/prepare_invoice_preview.dart` — use
  case de preparación/validación/consolidación
- `lib/features/invoices/domain/usecases/check_duplicate_invoice.dart` — use
  case de detección de duplicados
- `lib/features/invoices/domain/usecases/create_provisional_invoice.dart` — use
  case de creación POST (draft hardcodeado a `true`, serie `"B"`, moneda `EUR`)
- `lib/features/invoices/presentation/bloc/provisional_invoice_state.dart` —
  estados sealed del cubit
- `lib/features/invoices/presentation/bloc/provisional_invoice_cubit.dart` —
  cubit que orquesta el flujo completo
- `lib/features/invoices/presentation/widgets/provisional_invoice_dialog.dart` —
  diálogo con loading, preview, aviso duplicado, creación, éxito y error

### Modificados

- `lib/features/products/domain/entities/fd_product.dart` — añadidos `salesTax`
  (List\<String\>) y `salesDescription` (String?)
- `lib/features/products/domain/usecases/get_fd_products.dart` — parsing de
  `sales['tax']` y `sales['description']`
- `lib/core/data/datasources/factura_directa_api_data_source.dart` — añadidos
  `createInvoice` y `getInvoicesByContact` al contrato abstracto
- `lib/core/data/datasources/factura_directa_api_data_source_impl.dart` —
  implementado `_post`, `createInvoice` y `getInvoicesByContact`
- `lib/features/orders_today/presentation/widgets/orders_table.dart` —
  habilitado menú contextual, añadido callback `onGenerateProvisionalInvoice`
- `lib/features/orders_today/presentation/pages/orders_today_page.dart` — pasado
  callback, instanciación de cubit, apertura de diálogo
- `lib/app/di/modules/invoices_module.dart` — registrados
  `PrepareInvoicePreview`, `CheckDuplicateInvoice`, `CreateProvisionalInvoice` y
  `ProvisionalInvoiceCubit`
- `lib/app/localization/l10n/app_es.arb` — 22 nuevas claves i18n

### Retirados o reemplazados

Ninguno.

## 4) Validación ejecutada

### Automática

- `flutter analyze` — 0 errores, 0 warnings. Solo 2 `info` preexistentes en
  `orders_rtdb_data_source_impl.dart` (código no tocado).
- `flutter gen-l10n` — generación exitosa de archivos de localización.

### Manual

- Pendiente de validación manual: flujo completo con API de FD real.

### Incidencias encontradas

- **`const NoParams()`** en `PrepareInvoicePreview`: `NoParams` no tiene
  constructor `const` (extiende `Equatable` sin `const`). Corregido quitando
  `const`.

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** No se amplió `InvoicesRepository` con métodos
  `createProvisionalInvoice` y `checkDuplicateInvoice`.
  - **Justificación:** Los use cases `CreateProvisionalInvoice` y
    `CheckDuplicateInvoice` acceden directamente a `FacturaDirectaApiDataSource`
    y `SettingsRepository`, siguiendo el mismo patrón ya establecido por
    `GetFdProducts`. Añadir wrappers en `InvoicesRepository` habría sido código
    redundante sin valor.
  - **Impacto:** Ninguno. La arquitectura permanece consistente con los patrones
    existentes.

## 6) Riesgos, incidencias y pendientes

### Riesgos

- **PT-01 del análisis técnico:** No se ha verificado si el endpoint GET de
  invoices de FD soporta el query param `contact`. Si no lo soporta, la
  detección de duplicados podría devolver resultados no filtrados. El flujo
  sigue funcionando (se mostraría aviso aunque no sea para el mismo cliente). Se
  recomienda probar con la API real.
- **PT-02:** El mapeo de tax IDs a porcentajes usa regex para extraer números
  del ID (e.g. `tax_iva21` → 21%). Si FD usa un formato diferente, el porcentaje
  se mostrará como `-` en la UI (sin bloquear el flujo).

### Pendientes

- **Tests unitarios:** No se han creado tests unitarios para los nuevos
  componentes. Se recomienda crearlos para:
  - `PrepareInvoicePreview` (validaciones, consolidación, cálculos)
  - `CheckDuplicateInvoice`
  - `CreateProvisionalInvoice`
  - `ProvisionalInvoiceCubit` (secuencias de estados)
- **Validación manual:** Probar el flujo completo contra la API real de FD.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual con API real de FD + creación de
  tests unitarios
