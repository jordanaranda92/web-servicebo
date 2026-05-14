# Functional Analysis: Método de pago y posición fiscal en factura provisional

- **Fecha:** 2026-05-10
- **Identificador:** invoice-payment-method-and-fiscal-taxes
- **Estado:** Ready for technical analysis

## 1) Resumen

Al crear facturas provisionales vía API de Factura Directa, se detectan dos
carencias respecto a la creación manual desde la web de FD:

1. **No se incluye el método de pago** del cliente en la factura. La web de FD
   auto-rellena este campo a partir del `receivePaymentMethod` del contacto,
   pero la API no lo hace; hay que enviarlo explícitamente.
2. **No se aplican los impuestos de Recargo de Equivalencia (RE)** para clientes
   con posición fiscal `aut_re`. La web de FD detecta la posición fiscal del
   contacto y añade automáticamente los tax IDs de RE a cada línea; la API no lo
   hace.

La solución requiere consultar los datos del contacto en FD antes de construir
el body de la factura, y aplicar las reglas de negocio correspondientes.

## 2) Contexto y objetivo

- **Qué se solicita:** Corregir la generación de facturas provisionales para que
  incluyan (a) el método de pago preferido del cliente y (b) los impuestos
  adicionales de Recargo de Equivalencia cuando la posición fiscal del cliente
  lo requiera.
- **Qué problema resuelve:**
  - Las facturas creadas vía API no muestran método de pago, lo que obliga a
    editarlas manualmente en FD para rellenarlo.
  - Los clientes con posición fiscal "Autónomo en régimen de Recargo de
    Equivalencia" reciben facturas con importes incorrectos (faltan los
    impuestos de RE), lo que produce diferencias de importe respecto a las
    facturas creadas manualmente. Ejemplo real: una factura que debería ser
    218,99 € se genera como 215,27 € (faltan 3,72 € de recargos).
- **Resultado funcional esperado:** Las facturas provisionales creadas desde la
  app son idénticas a las que se crean manualmente en la web de FD en cuanto a
  método de pago e impuestos aplicados.

## 3) Alcance

### En alcance

- Consulta del contacto en FD (`GET /{companyId}/contacts/{id}`) para obtener:
  - `main.receivePaymentMethod` (método de cobro preferido)
  - `main.fiscalPositions.sales` (posición fiscal de ventas)
- Inclusión del campo `paymentMethod` en el body del POST de la factura.
- Detección de posición fiscal `aut_re` y adición de los tax IDs de RE
  correspondientes a cada línea de la factura.
- Actualización del cálculo de la preview para reflejar correctamente los
  impuestos de RE (desglose y total).

### Fuera de alcance

- Soporte de otras posiciones fiscales especiales (`emp_ic`, etc.) que no se
  abordan en esta iteración.
- Modificar la configuración de posición fiscal de los contactos en FD.
- Gestión de los métodos de pago (CRUD) desde la app.
- Soporte de `IVA 4%` con RE (`S_IVA_RE_0.5`): no se usa actualmente en la
  cuenta de FD. Se añadirá si aparece en el futuro.

## 4) Actores implicados

- **Usuario final:** Empleado que genera facturas provisionales desde la tabla
  de pedidos del día.
- **Sistema externo:** API de Factura Directa (lectura de contacto y escritura
  de factura).

## 5) Requisitos funcionales

### Método de pago

- **RF-01:** Antes de crear la factura, el sistema debe obtener los datos del
  contacto en FD mediante `GET /{companyId}/contacts/{contactId}`.
- **RF-02:** Del contacto se extrae el campo `main.receivePaymentMethod`
  (formato `pam_<uuid-v4>` o `null`).
- **RF-03:** Si `receivePaymentMethod` no es nulo ni vacío, se incluye como
  campo `paymentMethod` dentro de `content.main` del body del POST de la
  factura.
- **RF-04:** Si `receivePaymentMethod` es nulo o vacío, el campo `paymentMethod`
  no se incluye en el body (la factura se crea sin método de pago, igual que
  ahora).

### Posición fiscal y Recargo de Equivalencia

- **RF-05:** Del contacto se extrae el campo `main.fiscalPositions.sales`.
- **RF-06:** Si `fiscalPositions.sales == 'aut_re'`, el sistema debe añadir a
  cada línea de la factura el tax ID de RE correspondiente según la siguiente
  tabla:

  | IVA base del producto | Tax ID RE a añadir |
  | --------------------- | ------------------ |
  | `S_IVA_21`            | `S_IVA_RE_5.2`     |
  | `S_IVA_10`            | `S_IVA_RE_1.4`     |

- **RF-07:** La adición de RE se realiza añadiendo el tax ID al array `tax` de
  la línea, junto al IVA base. Ejemplo: un producto con `tax: ['S_IVA_10']` pasa
  a `tax: ['S_IVA_10', 'S_IVA_RE_1.4']`.
- **RF-08:** Si la posición fiscal no es `aut_re`, los impuestos de la línea no
  se modifican (se envían tal como vienen del producto de FD).
- **RF-09:** La preview de la factura debe reflejar los impuestos de RE cuando
  apliquen:
  - Cada línea muestra los impuestos aplicados (incluyendo RE si corresponde).
  - El desglose de impuestos incluye los RE como líneas separadas.
  - El total incluye los importes de RE.

## 6) Criterios de aceptación

- **CA-01:** Dado un cliente con `receivePaymentMethod = 'pam_xxx'`, cuando se
  genera una factura provisional, entonces la factura creada en FD tiene el
  campo `paymentMethod` con valor `pam_xxx`.
- **CA-02:** Dado un cliente sin `receivePaymentMethod` (nulo), cuando se genera
  una factura provisional, la factura se crea sin el campo `paymentMethod` (sin
  error).
- **CA-03:** Dado un cliente con `fiscalPositions.sales = 'aut_re'` y productos
  con IVA 10%, cuando se genera la factura, cada línea incluye
  `['S_IVA_10', 'S_IVA_RE_1.4']` en su array de impuestos.
- **CA-04:** Dado un cliente con `fiscalPositions.sales = 'aut_re'` y productos
  con IVA 21%, cuando se genera la factura, cada línea incluye
  `['S_IVA_21', 'S_IVA_RE_5.2']` en su array de impuestos.
- **CA-05:** Dado un cliente con `fiscalPositions.sales = 'aut_re'` y una
  factura con productos de IVA 10% y IVA 21%, el desglose de impuestos en la
  preview muestra 4 líneas: IVA 10%, IVA RE 1,40%, IVA 21%, IVA RE 5,20%.
- **CA-06:** El total de la factura para un cliente `aut_re` coincide con el
  total que genera la web de FD para los mismos productos y cantidades.
- **CA-07:** Dado un cliente con `fiscalPositions.sales = 'emp'` (empresa
  normal), los impuestos no se modifican y la factura se genera igual que antes.
- **CA-08:** La llamada `GET /{companyId}/contacts/{id}` se realiza una sola vez
  por flujo de generación de factura.

## 7) Flujos y comportamiento esperado

### Flujo principal (modificado respecto a la feature original)

Los pasos 1-7 del flujo original no cambian. Se insertan pasos nuevos entre la
obtención de datos de productos (paso 8) y la comprobación de duplicados (paso
9):

8. _(existente)_ El sistema obtiene precios e impuestos de los productos desde
   la API de FD.
9. **(NUEVO)** El sistema obtiene los datos del contacto en FD:
   `GET /{companyId}/contacts/{contactId}`.
10. **(NUEVO)** Del contacto se extrae `receivePaymentMethod` y
    `fiscalPositions.sales`.
11. **(NUEVO)** Si `fiscalPositions.sales == 'aut_re'`:
    - Para cada línea cuyo IVA base sea `S_IVA_21`, se añade `S_IVA_RE_5.2`.
    - Para cada línea cuyo IVA base sea `S_IVA_10`, se añade `S_IVA_RE_1.4`.
12. **(NUEVO)** Se recalcula el desglose de impuestos y el total incluyendo los
    recargos de equivalencia.
13. _(existente, renumerado)_ Se comprueba si ya existe una factura provisional
    para ese cliente y fecha.
14. Se muestra la preview con los datos completos (incluyendo RE si aplica y
    método de pago informativo si se desea).
15. El usuario confirma.
16. **(MODIFICADO)** El sistema envía `POST /{companyId}/invoices` con:
    - `draft: true`
    - `paymentMethod: receivePaymentMethod` (si existe)
    - Líneas con los tax IDs de RE incluidos (si aplica)

### Flujos alternativos

- **Error al obtener contacto de FD:** Si la llamada
  `GET /{companyId}/contacts/{id}` falla, se muestra un error y se detiene el
  flujo. No se intenta crear la factura sin estos datos.
- **Contacto sin `fiscalPositions`:** Si el campo no existe o
  `fiscalPositions.sales` es nulo, se asume posición fiscal estándar (no se
  añade RE).
- **Tax ID de IVA no reconocido para mapeo de RE:** Si un producto tiene un tax
  ID que no es `S_IVA_21` ni `S_IVA_10` (por ejemplo, exento o con otro
  impuesto), no se añade ningún RE a esa línea.

### Estados especiales / excepciones

- **Estado loading:** Se muestra durante la obtención de datos del contacto
  (además de los estados loading ya existentes para productos y duplicados).
- **Estado error:** Si la llamada al contacto falla (timeout, 404, etc.), se
  muestra error informativo y no se continúa.

## 8) Edge cases

- **EC-01:** Cliente con `aut_re` pero un producto exento de IVA (sin tax ID
  conocido) → no se añade RE a esa línea.
- **EC-02:** Cliente con `receivePaymentMethod` que apunte a un método de pago
  eliminado → FD puede devolver error al crear la factura; se gestiona con el
  manejo de errores existente.
- **EC-03:** La posición fiscal del contacto cambia entre la consulta GET y la
  creación POST → riesgo mínimo (operación de segundos); aceptable.
- **EC-04:** Productos con múltiples tax IDs (ej: `['S_IVA_21', 'S_IRPF_15']`) →
  el mapeo de RE solo busca `S_IVA_21` o `S_IVA_10` en el array y añade el RE
  correspondiente sin eliminar ningún tax ID existente.

## 9) Impacto funcional

- **Módulos afectados:**
  - `CreateProvisionalInvoice` (use case): modificar body de la factura.
  - `PrepareInvoicePreview` (use case): incluir datos del contacto y recalcular
    impuestos con RE.
  - `FacturaDirectaApiDataSource`: nuevo método `getContactById`.
  - `ProvisionalInvoiceCubit`: orquestar la llamada adicional al contacto.
  - `ProvisionalInvoiceDialog`: reflejar el desglose de RE en la preview.
- **Impacto en usuario:** Facturas correctas sin intervención manual. Los
  clientes `aut_re` reciben facturas con los importes correctos. Todos los
  clientes reciben facturas con su método de pago.
- **Impacto en negocio:** Eliminación del riesgo de facturación incorrecta para
  ~76 clientes con RE (31% de la cartera). Eliminación del trabajo manual de
  editar facturas para añadir método de pago.

## 10) Suposiciones

- Los tax IDs de RE existentes en la cuenta son `S_IVA_RE_5.2` (para IVA 21%) y
  `S_IVA_RE_1.4` (para IVA 10%). **Verificado con datos reales de la API.**
- La posición fiscal `aut_re` es el único valor de `fiscalPositions.sales` que
  requiere adición de RE. **Verificado: los otros valores son `emp`, `aut`,
  `emp_ic`, `none`.**
- El campo `receivePaymentMethod` del contacto siempre contiene un `pam_xxx`
  válido o es nulo. **Verificado: 234 de 242 contactos lo tienen.**
- No existen productos con IVA 4% (`S_IVA_4`) en la cuenta actualmente.
  **Verificado con las facturas existentes.**
- La API key tiene permisos `contacts:read` (confirmado por las llamadas de
  verificación realizadas).

## 11) Preguntas abiertas

- Ninguna. Todos los datos necesarios han sido verificados directamente contra
  la API de FD.

## 12) Notas para análisis técnico

- **Datos verificados en la API de FD:**
  - `fiscalPositions.sales = 'aut_re'` → Recargo de Equivalencia
  - Mapeo: `S_IVA_21 → S_IVA_RE_5.2`, `S_IVA_10 → S_IVA_RE_1.4`
  - `receivePaymentMethod` → formato `pam_<uuid-v4>`
- **Nuevo endpoint necesario:** `GET /{companyId}/contacts/{id}` (solo lectura,
  ya disponible en la API).
- **No se necesita** `GET /{companyId}/settings/taxes/sales` (la API key no
  tiene permisos `settings:read` y no es necesario porque los tax IDs de RE
  están hardcodeados en el mapeo).
- El cambio afecta tanto al cálculo de la preview como a la construcción del
  body del POST.
- La preview debe poder mostrar múltiples impuestos por línea (IVA + RE).
- **Referencia:**
  `docs/functional-analysis/2026-05-10-generate-provisional-invoice.md`
- **Estado: Listo para análisis técnico**
