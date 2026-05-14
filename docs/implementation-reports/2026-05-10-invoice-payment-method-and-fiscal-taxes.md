# Implementation Report: Método de pago y Recargo de Equivalencia en factura provisional

- **Fecha:** 2026-05-10
- **Identificador:** invoice-payment-method-and-fiscal-taxes
- **Plan técnico:**
  docs/technical-analysis/2026-05-10-invoice-payment-method-and-fiscal-taxes.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado la obtención de datos del contacto FD (método de pago y
posición fiscal) durante la preparación de la factura provisional. Las facturas
ahora incluyen el `paymentMethod` del contacto y aplican automáticamente los
impuestos de Recargo de Equivalencia (RE) para clientes con posición fiscal
`aut_re`.

## 2) Alcance ejecutado

- ✅ Nuevo método `getContactById` en el datasource FD (abstracto + impl)
- ✅ Campo `paymentMethod` añadido a `InvoicePreview`
- ✅ `PrepareInvoicePreview` modificado para obtener contacto FD, aplicar mapeo
  RE y propagar paymentMethod
- ✅ `CreateProvisionalInvoice` modificado para incluir `paymentMethod` en el
  body del POST
- ✅ Dialog de preview adaptado para mostrar impuestos compuestos (IVA + RE)
- ✅ DI actualizado para inyectar datasource FD en `PrepareInvoicePreview`

Todas las partes del plan se han implementado.

## 3) Artefactos tocados

### Creados

Ninguno.

### Modificados

- `lib/core/data/datasources/factura_directa_api_data_source.dart` — Añadido
  método `getContactById(companyId, contactId)`
- `lib/core/data/datasources/factura_directa_api_data_source_impl.dart` —
  Implementación de `getContactById` con
  `_get('/$companyId/contacts/$contactId')`
- `lib/features/invoices/domain/entities/invoice_preview.dart` — Añadido campo
  `paymentMethod` (String?) a `InvoicePreview`
- `lib/features/invoices/domain/usecases/prepare_invoice_preview.dart` —
  Inyectada dependencia `FacturaDirectaApiDataSource`, añadidos mapeos
  `_reMapping` y `_taxPercentages`, lógica de consulta de contacto, aplicación
  de RE, recálculo de taxBreakdown por tax ID individual, eliminada función
  `_extractTaxPercentage`
- `lib/features/invoices/domain/usecases/create_provisional_invoice.dart` —
  Incluido `paymentMethod` condicionalmente en `content.main` del body POST
- `lib/features/invoices/presentation/widgets/provisional_invoice_dialog.dart` —
  Columna de impuestos usa `_formatTaxLabel(line.tax)` que muestra "21% + RE" o
  "10% + RE" para líneas con recargo; añadido método `_formatTaxLabel`
- `lib/app/di/modules/invoices_module.dart` — `PrepareInvoicePreview` ahora
  recibe 5 dependencias (`sl(), sl(), sl(), sl(), sl()`)

### Retirados o reemplazados

- Eliminado método `_extractTaxPercentage` de `PrepareInvoicePreview`
  (reemplazado por mapeo estático `_taxPercentages`)

## 4) Validación ejecutada

### Automática

- `flutter analyze`: 0 errores, 0 warnings. Solo 2 infos preexistentes no
  relacionados (en `orders_rtdb_data_source_impl.dart`).

### Manual

Pendiente:

- Crear factura provisional para cliente `aut_re` y verificar en FD web que
  aparecen impuestos RE y método de pago.
- Crear factura para cliente `emp` y verificar que no se añaden impuestos RE.

## 5) Desviaciones respecto al análisis técnico

- **Columna de impuestos del dialog:** El análisis técnico sugería adaptar
  `InvoicePreviewLine` con un campo `taxDetails` (lista de tuplas). En su lugar,
  se mantuvo el campo `taxPercentage` como suma total y se creó un helper
  `_formatTaxLabel` en el dialog que inspecciona los tax IDs directamente para
  mostrar "21% + RE" o "10% + RE". Esto es más simple y evita modificar la
  entidad más allá de lo necesario.
  - **Justificación:** Cambio mínimo, misma funcionalidad visual, sin impacto en
    el cálculo.
  - **Impacto:** Ninguno.

- **Cálculo de taxBreakdown:** Se usa un `label` con formato "RE 5.2%" / "RE
  1.4%" para las entradas de RE, y "21%" / "10%" para IVA, en lugar del formato
  genérico original. Esto hace que el desglose en el dialog sea más legible.
  - **Justificación:** Mejora la legibilidad sin cambiar la lógica de cálculo.
  - **Impacto:** Ninguno.

## 6) Riesgos, incidencias y pendientes

- **Pendiente:** Validación manual con la API real (crear factura para cliente
  `aut_re` y para cliente `emp`).
- **Riesgo bajo:** Los tax IDs de RE están hardcodeados. Si FD cambiara su
  catálogo fiscal, habría que actualizar los mapas `_reMapping` y
  `_taxPercentages`.
- **Sin incidencias** durante la implementación.

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: Validación manual creando facturas provisionales
  para clientes con y sin RE.
