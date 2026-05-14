# Implementation Report: Vista detalle de factura

- **Fecha:** 2026-05-13
- **Identificador:** invoice-detail-view
- **Plan técnico:** docs/technical-analysis/2026-05-13-invoice-detail-view.md
- **Estado:** Completed

## 1) Resumen

Se ha implementado la vista detalle de factura completa, accesible al pulsar
sobre cualquier factura del listado (tanto en tabla desktop como en tarjetas
mobile). La pantalla carga los datos desde la API de Factura Directa vía el
endpoint `getInvoiceById` ya existente y muestra cabecera, líneas con
información fiscal y totales. La implementación sigue fielmente el plan técnico
sin desviaciones significativas.

## 2) Alcance ejecutado

- Ampliación de `InvoiceLine` con campos fiscales (`tax`, `taxPercentage`)
- Ampliación de `InvoiceDto.fromJson` para parsear campos fiscales de líneas
- Nuevo método `getInvoiceById` en contrato `InvoicesRepository` e
  implementación
- Nuevo use case `GetInvoiceById`
- Nuevo `InvoiceDetailCubit` con estados Initial, Loading, Loaded, Error y
  método `retry()`
- Nueva `InvoiceDetailPage` responsive (desktop/mobile) con cabecera, tabla de
  líneas y totales
- Ruta `/invoices/:id/detail` registrada como sub-ruta en el router
- Navegación conectada desde `InvoiceCard` (mobile) y tabla (desktop) al detalle
- Registro DI de `GetInvoiceById` y `InvoiceDetailCubit`
- 16 claves i18n añadidas para la vista detalle

## 3) Artefactos tocados

### Creados

- `lib/features/invoices/domain/usecases/get_invoice_by_id.dart`
- `lib/features/invoices/presentation/bloc/invoice_detail_cubit.dart`
- `lib/features/invoices/presentation/bloc/invoice_detail_state.dart`
- `lib/features/invoices/presentation/pages/invoice_detail_page.dart`

### Modificados

- `lib/features/invoices/domain/entities/invoice.dart` — campos `tax` y
  `taxPercentage` en `InvoiceLine`
- `lib/features/invoices/domain/repositories/invoices_repository.dart` — nuevo
  método `getInvoiceById`
- `lib/features/invoices/data/dto/invoice_dto.dart` — parseo de `tax` y
  `taxPercentage`
- `lib/features/invoices/data/repositories/invoices_repository_impl.dart` —
  implementación de `getInvoiceById`
- `lib/features/invoices/presentation/widgets/invoice_card.dart` — callback
  `onTap` + `InkWell`
- `lib/features/invoices/presentation/pages/invoices_page.dart` — navegación en
  card list y tabla
- `lib/app/router/router.dart` — ruta `invoiceDetail`, import, sub-ruta
- `lib/app/di/modules/invoices_module.dart` — registro `GetInvoiceById` y
  `InvoiceDetailCubit`
- `lib/app/localization/l10n/app_es.arb` — 16 claves i18n para detalle

### Retirados o reemplazados

- Ninguno

## 4) Validación ejecutada

- **`dart analyze`** sobre todos los archivos modificados/creados: 0 issues
- **`dart format`** sobre archivos de presentación: formateado correcto
- **`flutter test`**: 32/32 tests pasan — ningún test existente roto
- **`flutter gen-l10n`**: generación exitosa de clases de localización

## 5) Desviaciones respecto al análisis técnico

- **Desviación 1:** El campo `taxPercentage` se parsea directamente del JSON de
  FD (`lineMap['taxPercentage']`). Si FD no lo incluye en la respuesta, se
  mostrará "—" en la columna de IVA de la tabla de líneas. Esto es coherente con
  la suposición S-04 del análisis funcional y el riesgo identificado en el
  análisis técnico.
- **Justificación:** Tratamiento gracioso de datos opcionales sin impacto
  funcional.
- **Impacto:** Ninguno — el campo es opcional y la UI maneja el null
  correctamente.

## 6) Riesgos, incidencias y pendientes

- **Riesgo conocido:** Si la API de FD no devuelve `taxPercentage` en las líneas
  de la factura, la columna de IVA mostrará "—" para todas las líneas. Se
  recomienda validar con datos reales que el campo esté presente. Si no lo está,
  se podría calcular a partir de los UUIDs de impuestos (`tax`) en una iteración
  posterior.
- **Pendiente:** Tests unitarios para `GetInvoiceById`, `InvoiceDetailCubit` e
  `InvoicesRepositoryImpl.getInvoiceById` (recomendados en el análisis técnico
  pero no incluidos en el alcance de implementación solicitado).

## 7) Resultado final

- Estado final: ✅ Completado
- Siguiente paso recomendado: validación manual con datos reales en entorno
  local, seguido de escritura de tests unitarios para las capas domain y
  presentation del detalle.
