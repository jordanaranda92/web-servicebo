# Functional Analysis: Vista detalle de factura

- **Fecha:** 2026-05-13
- **Identificador:** invoice-detail-view
- **Estado:** Ready for technical analysis

## 1) Resumen

Al pulsar sobre una factura en el listado de facturas (tanto en vista
desktop/tabla como en vista mobile/cards), se navega a una nueva pantalla de
detalle que muestra toda la información de la factura obtenida de Factura
Directa.

## 2) Contexto y objetivo

- **Qué se solicita:** Una vista detalle de factura accesible al pulsar sobre
  cualquier factura del listado existente (`InvoicesPage`).
- **Qué problema resuelve:** Actualmente el listado de facturas muestra
  información resumida (número, fecha, cliente, estado, subtotal, total) pero no
  permite consultar el desglose completo (líneas de la factura, impuestos,
  etc.). El usuario necesita navegar a Factura Directa externamente para ver
  esos datos.
- **Resultado funcional esperado:** El usuario puede consultar el detalle
  completo de cualquier factura sin salir de la aplicación, con los datos
  cargados desde la API de Factura Directa.

## 3) Alcance

### En alcance

- Navegación desde el listado de facturas (tabla desktop y tarjetas mobile) al
  detalle
- Nueva pantalla de detalle de factura con datos de Factura Directa
- Carga del detalle por ID desde la API de Factura Directa (endpoint
  `getInvoiceById` ya existente)
- Visualización de: datos cabecera (número, fecha, estado, cliente) + líneas de
  factura (descripción, cantidad, precio unitario, total línea) + totales
  (subtotal, impuestos, total)
- Estados de carga (loading), error y contenido
- Botón de retorno al listado
- Soporte responsive (desktop y mobile)

### Fuera de alcance

- Edición de facturas desde el detalle
- Descarga/exportación de PDF de la factura
- Cambio de estado de la factura (marcar como pagada, anular, etc.)
- Envío de factura por email
- Navegación al detalle del cliente desde la factura

## 4) Actores implicados

- **Usuario final (operador/administrador):** consulta el detalle de facturas
  desde el listado
- **Sistema externo (Factura Directa API):** proveedor de los datos de detalle
  de la factura

## 5) Requisitos funcionales

- **RF-01:** Al pulsar sobre una fila de la tabla de facturas (desktop) se
  navega a la vista detalle de esa factura.
- **RF-02:** Al pulsar sobre una tarjeta de factura (mobile) se navega a la
  vista detalle de esa factura.
- **RF-03:** La vista detalle carga los datos completos de la factura desde la
  API de Factura Directa utilizando el ID de la factura.
- **RF-04:** La vista detalle muestra la información de cabecera: número de
  documento, fecha, nombre del cliente, estado (con chip de color como en el
  listado) y moneda.
- **RF-05:** La vista detalle muestra las líneas de la factura con: descripción,
  cantidad, precio unitario, total por línea e información fiscal (tipo de IVA y
  porcentaje por línea).
- **RF-06:** La vista detalle muestra los totales: subtotal, desglose de
  impuestos (base imponible y cuota por tipo de IVA) y total.
- **RF-11:** La información del cliente se limita al nombre; no se muestran
  datos adicionales (dirección, NIF).
- **RF-12:** La vista detalle no incluye botones de acción (descargar PDF,
  cambiar estado, enviar). Es exclusivamente de consulta.
- **RF-07:** La vista detalle muestra un indicador de carga mientras se obtienen
  los datos.
- **RF-08:** La vista detalle muestra un mensaje de error con opción de
  reintentar si la carga falla.
- **RF-09:** El usuario puede volver al listado de facturas mediante un botón de
  retorno o navegación del navegador (back).
- **RF-10:** La ruta de detalle debe seguir el patrón existente en la app (ej:
  `/invoices/:id/detail`), permitiendo acceso directo por URL.

## 6) Criterios de aceptación

- **CA-01:** Dado que el usuario está en el listado de facturas, cuando pulsa
  sobre una factura, entonces se navega a la vista detalle de esa factura.
- **CA-02:** Dado que se navega al detalle, cuando la API responde
  correctamente, entonces se muestran todos los campos de cabecera (número,
  fecha, cliente, estado, moneda).
- **CA-03:** Dado que la factura tiene líneas, cuando se muestra el detalle,
  entonces se ven todas las líneas con descripción, cantidad, precio unitario,
  total de línea y tipo/porcentaje de IVA.
- **CA-09:** Dado que la factura tiene impuestos, cuando se muestra el detalle,
  entonces se ve el desglose de impuestos (base imponible y cuota por tipo de
  IVA) antes del total.
- **CA-04:** Dado que se navega al detalle, cuando la API está respondiendo,
  entonces se muestra un indicador de carga.
- **CA-05:** Dado que la API devuelve un error, cuando se muestra la vista
  detalle, entonces se presenta un mensaje de error con botón de reintentar.
- **CA-06:** Dado que el usuario está en el detalle, cuando pulsa el botón de
  retorno, entonces vuelve al listado de facturas manteniendo el estado previo
  (filtros, scroll).
- **CA-07:** Dado que el usuario accede directamente por URL a
  `/invoices/<id>/detail`, cuando la ruta es válida, entonces se carga y muestra
  el detalle de la factura.
- **CA-08:** Dado que la factura es un borrador (draft), cuando se muestra el
  detalle, entonces el estado se refleja correctamente como "borrador".

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario accede al listado de facturas (`/invoices`).
2. El usuario pulsa sobre una factura (fila en tabla desktop o tarjeta en
   mobile).
3. La app navega a la ruta `/invoices/:id/detail`.
4. Se muestra un indicador de carga.
5. Se solicitan los datos de la factura a la API de Factura Directa mediante
   `getInvoiceById(id)`.
6. Se reciben los datos y se muestra la vista detalle con cabecera, líneas y
   totales.

### Flujos alternativos

- **FA-01 — Acceso directo por URL:** El usuario introduce o comparte la URL
  `/invoices/<id>/detail`. Se carga el detalle directamente sin pasar por el
  listado.
- **FA-02 — Retorno al listado:** El usuario pulsa el botón de retorno. Se
  navega de vuelta a `/invoices` conservando el estado del listado (filtros
  activos, posición de scroll si es posible).
- **FA-03 — Factura sin líneas:** La factura no tiene líneas de detalle. Se
  muestra la cabecera y totales, y en la sección de líneas se indica que no hay
  líneas disponibles.

### Estados especiales / excepciones

- **Estado loading:** Indicador de carga centrado mientras se obtienen los datos
  de FD.
- **Estado error — red:** Fallo de conectividad. Mostrar mensaje de error de red
  con botón de reintentar.
- **Estado error — servidor:** La API de FD devuelve un error. Mostrar mensaje
  de error del servidor con botón de reintentar.
- **Estado error — factura no encontrada:** El ID proporcionado no corresponde a
  ninguna factura. Mostrar mensaje indicando que la factura no existe.
- **Estado error — parsing:** Los datos devueltos no pueden parsearse. Mostrar
  error genérico.

## 8) Edge cases

- **EC-01:** El ID de la factura en la URL es inválido o no existe en Factura
  Directa → mostrar error de factura no encontrada.
- **EC-02:** La factura tiene un gran número de líneas (>50) → la vista debe ser
  scrollable y renderizar correctamente.
- **EC-03:** Campos opcionales nulos (contactName, currency, subtotal) → mostrar
  placeholders o guiones ("—") en lugar de vacío.
- **EC-04:** El usuario navega al detalle y luego pierde la sesión (token
  expirado) → el guard de autenticación existente redirige al login.
- **EC-05:** El usuario navega al detalle mientras la carga del listado aún no
  terminó (acceso directo por URL) → el detalle debe funcionar
  independientemente del listado.
- **EC-06:** La factura está anulada (voided) → el estado se muestra
  correctamente y no cambia el comportamiento de visualización.

## 9) Impacto funcional

- **Módulos afectados:**
  - `features/invoices`: nueva pantalla, nuevo cubit/estado para el detalle,
    posible nuevo use case.
  - `app/router`: nueva ruta `/invoices/:id/detail`.
  - `InvoiceCard` / tabla de facturas: añadir handler de tap para navegar.
- **Impacto en usuario:** Mejora significativa de productividad — el usuario ya
  no necesita consultar Factura Directa externamente para ver el desglose de una
  factura.
- **Impacto en UX:** Consistente con el patrón existente de listado → detalle ya
  implementado en clientes (`/clients/:id/detail`).

## 10) Suposiciones

- **S-01:** El endpoint `getInvoiceById(id)` del proxy de Factura Directa
  devuelve la misma estructura JSON que ya parsea `InvoiceDto.fromJson`,
  incluyendo las líneas de la factura.
- **S-02:** Los datos devueltos por `getInvoiceById` son suficientes para
  mostrar un detalle completo (no se requiere llamar a endpoints adicionales).
- **S-03:** No se requiere persistencia local (caché) del detalle de factura; se
  carga siempre desde la API.
- **S-04:** La información fiscal detallada (tipo de impuesto, porcentaje por
  línea) puede obtenerse del mismo endpoint `getInvoiceById`. Si la respuesta no
  incluye estos datos, se deberá investigar endpoints adicionales o campos
  alternativos del JSON de FD.
- **S-05:** El patrón de navegación sigue el estándar `go_router` ya utilizado
  en la app (como `ClientDetailPage`).

## 11) Preguntas abiertas

- Ninguna — todas las preguntas resueltas.

### Preguntas resueltas

- **PA-01 (resuelta):** Sí, mostrar información fiscal detallada (tipo de IVA
  por línea y desglose de impuestos). → Incorporado en RF-05, RF-06, CA-03,
  CA-09.
- **PA-02 (resuelta):** De momento no se prevén acciones sobre la factura. Vista
  exclusivamente de consulta. → Incorporado en RF-12.
- **PA-03 (resuelta):** Solo el nombre del cliente, sin datos adicionales
  (dirección, NIF). → Incorporado en RF-11.

## 12) Notas para análisis técnico

- Ya existe `getInvoiceById(String id)` en `FacturaDirectaApiDataSource`
  (abstract e impl) que devuelve `Map<String, dynamic>`.
- `InvoiceDto.fromJson` ya parsea las líneas de factura (`lines`) con campos
  `text`, `quantity`, `unitPrice`, `lineTotal`.
- La entidad `Invoice` ya incluye `List<InvoiceLine> lines` con `description`,
  `quantity`, `price`, `total`.
- El router usa `go_router` con `ShellRoute` para el `SideMenuShell`. El patrón
  de detalle anidado ya existe en clientes (`/clients/:id/detail`).
- Se necesitará: un nuevo `GetInvoiceById` use case, un `InvoiceDetailCubit` con
  estados (initial, loading, loaded, error), una `InvoiceDetailPage`, y la ruta
  en el router.
- Evaluar si la respuesta de `getInvoiceById` contiene los campos fiscales
  necesarios (impuesto por línea con tipo y porcentaje, desglose total de
  impuestos). Si no, investigar cómo obtenerlos del API de FD.
- La vista es solo de consulta — no se necesitan acciones ni mutaciones.
- Solo mostrar nombre del cliente; no se requiere cargar datos adicionales del
  contacto.
- **Estado: Listo para análisis técnico**
