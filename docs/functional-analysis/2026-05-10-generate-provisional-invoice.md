# Functional Analysis: Generación de factura provisional en Factura Directa

- **Fecha:** 2026-05-10
- **Identificador:** generate-provisional-invoice
- **Estado:** Ready for technical analysis

## 1) Resumen

Implementar la funcionalidad del botón «Generar factura provisional» del menú
contextual de cliente en la tabla de pedidos del día. Al pulsar esta opción, el
sistema valida que todos los productos del pedido estén vinculados a Factura
Directa, obtiene los datos necesarios (precios, impuestos) desde la API de FD,
presenta al usuario una preview de la factura con todos los detalles calculados
y, tras su confirmación, crea la factura como **provisional (draft)** en Factura
Directa mediante `POST /{companyId}/invoices`.

## 2) Contexto y objetivo

- **Qué se solicita:** Activar la opción «Generar factura provisional»
  (actualmente deshabilitada como placeholder con `enabled: false`) en el menú
  contextual que aparece al hacer click derecho sobre un cliente en la cabecera
  de la tabla de pedidos del día. El flujo incluye validación de vinculación de
  productos, preview de la factura y creación en Factura Directa.
- **Qué problema resuelve:** El proceso actual de generación de facturas
  requiere entrar manualmente en Factura Directa, buscar al cliente, añadir cada
  línea de producto con su cantidad, y verificar precios e impuestos. Es un
  proceso manual, lento y propenso a errores, especialmente cuando hay muchos
  productos en un pedido. Esta funcionalidad automatiza la creación de la
  factura directamente desde los datos del pedido del día.
- **Resultado funcional esperado:** El usuario puede generar una factura
  provisional en Factura Directa con un solo flujo de click derecho → validación
  → preview → confirmación, sin salir de la aplicación. La factura se crea como
  **provisional** (borrador) en FD, lo que permite revisarla y convertirla en
  definitiva desde la propia plataforma de Factura Directa.

## 3) Alcance

### En alcance

- Validación de que el cliente tiene un UUID de Factura Directa vinculado.
- Validación de que todos los productos con cantidad > 0 para ese cliente están
  vinculados a Factura Directa.
- Obtención de precios de venta e impuestos de los productos desde la API de
  Factura Directa (endpoint GET ya existente).
- Diálogo de preview con los datos calculados de la factura antes de enviarla.
- Creación de la factura como **siempre provisional** (`draft: true`) mediante
  `POST /{companyId}/invoices`.
- Diálogo de error informativo cuando hay productos o cliente sin vincular.
- Feedback de éxito o error tras la creación.

### Fuera de alcance

- Creación de facturas definitivas (nunca se envía `draft: false`).
- Cualquier otra llamada POST a la API de Factura Directa (no se crean
  contactos, productos, albaranes ni ningún otro recurso).
- Edición de la factura una vez creada en FD.
- Configuración de la serie de facturación desde la aplicación (se usa el valor
  hardcodeado `"B"` de momento).
- Envío de la factura por email desde la aplicación.
- Descarga/generación del PDF de la factura desde la aplicación.
- Gestión del mapeo multi-línea de productos (un producto local → múltiples
  líneas en factura). Se trata como mejora futura.

## 4) Actores implicados

- **Usuario final:** Empleado que gestiona los pedidos del día y necesita
  generar facturas provisionales para los clientes.
- **Sistema externo:** API de Factura Directa (lectura de productos para precios
  e impuestos; escritura de la factura provisional).

## 5) Requisitos funcionales

- **RF-01:** La opción «Generar factura provisional» del menú contextual de
  cliente debe estar habilitada (actualmente `enabled: false`).
- **RF-02:** Al seleccionar la opción, el sistema debe verificar que el cliente
  (columna seleccionada) tiene un `facturaDirectaUuid` válido (no vacío). Si no
  lo tiene, se muestra un error informando que el cliente no está vinculado a
  Factura Directa.
- **RF-03:** El sistema debe identificar todos los productos cuya cantidad para
  ese cliente sea > 0 en el pedido del día.
- **RF-04:** Para cada producto con cantidad > 0, el sistema debe verificar que
  tiene un `facturaDirectaUuid` válido (no vacío). Si uno o más productos no
  están vinculados, se muestra un diálogo listando los nombres de los productos
  no vinculados, indicando que deben vincularse desde la sección Productos antes
  de poder generar la factura.
- **RF-04b:** Si varios productos locales (de Firebase) apuntan al mismo
  `facturaDirectaUuid`, sus cantidades se suman y se genera una única línea en
  la factura con la cantidad total acumulada.
- **RF-05:** Si todas las validaciones pasan, el sistema debe obtener de la API
  de Factura Directa los datos de precio de venta (`salesPrice`) e impuestos
  (`sales.tax`) de cada producto vinculado. Para ello se reutilizará el endpoint
  `GET /{companyId}/products` ya implementado.
- **RF-06:** Con los datos obtenidos, el sistema debe presentar un diálogo de
  preview de la factura mostrando:
  - Nombre del cliente.
  - Fecha del pedido.
  - Tabla de líneas con: nombre del producto, cantidad, precio unitario,
    impuesto (%) y total de línea.
  - Subtotal (suma de totales de línea antes de impuestos).
  - Desglose de impuestos por tipo (e.g., IVA 21%).
  - Total final.
  - Indicación clara de que es una factura **provisional**.
- **RF-07:** El diálogo de preview debe ofrecer dos acciones: «Cancelar» y
  «Generar factura provisional».
- **RF-08:** Al confirmar, el sistema debe llamar a `POST /{companyId}/invoices`
  con los datos correspondientes y el campo `draft: true` (siempre). No se debe
  realizar ninguna otra llamada POST a la API de Factura Directa.
- **RF-09:** Tras la creación exitosa, se debe mostrar un feedback de éxito al
  usuario (e.g., snackbar o diálogo) indicando que la factura provisional ha
  sido creada con su número de documento.
- **RF-10:** Si la creación falla, se debe mostrar un mensaje de error
  descriptivo al usuario.
- **RF-11:** Antes de iniciar el flujo de preview, el sistema debe comprobar si
  ya existe una factura provisional en FD para el mismo cliente y la misma
  fecha. Si existe, se muestra un aviso al usuario informando de la factura
  provisional existente. El usuario puede decidir continuar igualmente o
  cancelar.

## 6) Criterios de aceptación

- **CA-01:** Dado un cliente con `facturaDirectaUuid` vacío, cuando el usuario
  selecciona «Generar factura provisional», entonces se muestra un diálogo de
  error indicando que el cliente no está vinculado.
- **CA-02:** Dados productos con cantidad > 0 para un cliente donde al menos uno
  tiene `facturaDirectaUuid` vacío, cuando el usuario selecciona «Generar
  factura provisional», entonces se muestra un diálogo listando los nombres de
  los productos no vinculados.
- **CA-03:** Dados todos los productos vinculados y el cliente vinculado, cuando
  el usuario selecciona «Generar factura provisional», entonces se muestra el
  diálogo de preview con las líneas calculadas correctamente (cantidad × precio
  = total de línea).
- **CA-04:** En el diálogo de preview, los precios mostrados corresponden a los
  precios de venta configurados en Factura Directa para cada producto, no a
  valores locales.
- **CA-05:** En el diálogo de preview, los impuestos mostrados corresponden a
  los impuestos de venta configurados en Factura Directa para cada producto.
- **CA-06:** Al confirmar en el diálogo de preview, la factura se crea en
  Factura Directa con `draft: true` (provisional).
- **CA-07:** La factura creada en FD contiene el contacto correcto (UUID del
  cliente en FD), la fecha del pedido, la moneda `EUR` y las líneas con
  cantidad, precio unitario, impuestos y descripción correctos.
- **CA-08:** Tras la creación exitosa, el usuario recibe feedback visual
  confirmando la operación.
- **CA-09:** Si la API de FD devuelve un error, el usuario recibe un mensaje de
  error descriptivo.
- **CA-10:** Si no hay productos con cantidad > 0 para el cliente, el sistema
  informa de que no hay líneas para facturar.
- **CA-11:** No se ejecuta ninguna llamada POST a la API de FD que no sea
  `POST /{companyId}/invoices` para crear la factura.
- **CA-12:** Si dos productos locales apuntan al mismo producto de FD (mismo
  `facturaDirectaUuid`), la preview muestra una sola línea con la cantidad
  sumada y el mismo precio unitario.
- **CA-13:** Si ya existe una factura provisional para ese cliente y fecha, se
  muestra un aviso antes de la preview.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario hace click derecho sobre la cabecera de un cliente en la tabla de
   pedidos del día.
2. Aparece el menú contextual con la opción «Generar factura provisional».
3. El usuario selecciona la opción.
4. El sistema verifica que el cliente tiene `facturaDirectaUuid` no vacío.
5. El sistema identifica los productos con cantidad > 0 para ese cliente.
6. El sistema verifica que todos esos productos tienen `facturaDirectaUuid` no
   vacío.
7. El sistema consolida productos que apuntan al mismo `facturaDirectaUuid` de
   FD, sumando sus cantidades.
8. El sistema obtiene los precios e impuestos de los productos desde la API de
   FD (usando el endpoint GET ya implementado).
9. El sistema comprueba si ya existe una factura provisional para el mismo
   cliente y fecha en FD (usando el endpoint GET de facturas filtrado por
   `contact`, `minDate`, `maxDate` y `draft=only`). Si existe, muestra un aviso
   al usuario. El usuario puede continuar o cancelar.
10. El sistema calcula subtotales, impuestos y total.
11. Se muestra el diálogo de preview con todos los datos.
12. El usuario revisa la preview y pulsa «Generar factura provisional».
13. El sistema envía `POST /{companyId}/invoices` con `draft: true`.
14. FD responde con éxito (200) y devuelve la factura creada.
15. Se muestra feedback de éxito con el número de documento asignado por FD.

### Flujos alternativos

- **FA-01 — Cliente no vinculado (paso 4):** Se muestra un diálogo de error
  indicando que el cliente no está vinculado a Factura Directa. Se sugiere al
  usuario vincularlo desde la sección Clientes. Fin del flujo.
- **FA-02 — Productos no vinculados (paso 6):** Se muestra un diálogo de error
  con la lista de nombres de productos no vinculados. Se sugiere al usuario
  vincularlos desde la sección Productos. Fin del flujo.
- **FA-03 — Factura provisional duplicada (paso 9):** Se muestra un aviso
  indicando que ya existe una factura provisional para ese cliente y fecha. El
  usuario decide continuar o cancelar. Si cancela, fin del flujo.
- **FA-04 — Usuario cancela en preview (paso 12):** El usuario pulsa «Cancelar»
  en el diálogo de preview. No se realiza ninguna llamada a la API. Fin del
  flujo.
- **FA-05 — Error de API al crear (paso 14):** FD responde con error (4xx/5xx).
  Se muestra un diálogo de error con descripción. Fin del flujo.
- **FA-06 — Sin configuración de FD:** Si no existe configuración de Factura
  Directa guardada (companyId / apiToken), se muestra error indicando que debe
  configurar FD en Ajustes. Fin del flujo.

### Estados especiales / excepciones

- **Sin productos con cantidad > 0:** El cliente no tiene ningún producto con
  cantidad en el pedido del día. Se muestra un mensaje indicando que no hay
  líneas para facturar. No se genera factura.
- **Estado loading:** Mientras se obtienen los datos de FD y mientras se espera
  la respuesta del POST, el diálogo de preview muestra un indicador de carga y
  desactiva el botón de confirmación para evitar doble envío.
- **Error de red:** Si la API de FD no está accesible (timeout, sin conexión),
  se muestra un error de conectividad al usuario.
- **Credenciales inválidas:** Si el apiToken es inválido o ha expirado
  (401/403), se muestra un error indicando que las credenciales de FD son
  inválidas.

## 8) Edge cases

- **EC-01:** El cliente tiene un solo producto con cantidad > 0 — la factura
  tiene una sola línea. Debe funcionar correctamente.
- **EC-02:** Un producto tiene cantidad fraccionaria (e.g., 0.5) — la cantidad
  se pasa tal cual a la API de FD. La preview debe mostrar el valor
  fraccionario.
- **EC-03:** Un producto vinculado a FD ya no existe en la API de FD (fue
  eliminado) — el sistema no encuentra el `FdProduct` correspondiente. Se trata
  como si el producto no tuviera precio disponible y se muestra un error
  indicando el producto afectado.
- **EC-04:** El precio de un producto en FD es `null` o 0 — la línea se incluye
  con precio 0. Se muestra en la preview para que el usuario lo vea antes de
  confirmar.
- **EC-05:** Un producto en FD no tiene impuestos configurados (`sales.tax`
  vacío) — la línea se incluye sin impuestos. Se refleja en la preview.
- **EC-06:** Múltiples productos comparten el mismo impuesto — el desglose de
  impuestos agrupa por tipo (una sola línea para IVA 21%, por ejemplo).
- **EC-07:** La respuesta de la API de FD es lenta — el loading se muestra
  correctamente y no se permite doble pulsación del botón.
- **EC-08:** El usuario cierra el diálogo de preview sin pulsar ningún botón
  (e.g., pulsando fuera, tecla Escape) — equivale a «Cancelar», no se genera
  factura.
- **EC-09:** Dos o más productos locales apuntan al mismo producto de FD — sus
  cantidades se suman y se genera una sola línea en la factura. La preview
  refleja esta consolidación mostrando la cantidad total.
- **EC-10:** El usuario intenta generar una segunda factura provisional para el
  mismo cliente y fecha — se muestra el aviso de duplicado pero se permite
  continuar si el usuario lo desea.

## 9) Impacto funcional

- **Módulos afectados:**
  - **Orders Today** — Se habilita el item del menú contextual y se añade el
    callback para lanzar el flujo.
  - **Invoices** — Se crean use cases, entities y widgets nuevos para la preview
    y la creación.
  - **Products** — Se amplía la entidad `FdProduct` para incluir impuestos de
    venta; se modifica el parsing del use case `GetFdProducts`.
  - **Settings** — Se lee la configuración de FD (sin cambios funcionales).
  - **Core** — Se añade un método POST al `FacturaDirectaApiDataSource`.

- **Impacto en el usuario:** Reducción significativa del tiempo y esfuerzo para
  crear facturas. El flujo pasa de ser completamente manual en la web de FD a
  ser un proceso de 3 clicks desde la propia aplicación.

- **Impacto en experiencia de usuario:** El diálogo de preview permite al
  usuario verificar los datos antes de crear la factura, evitando errores. Los
  mensajes de validación guían al usuario para resolver problemas de vinculación
  antes de intentar generar la factura.

## 10) Suposiciones

- **S-01:** La serie de facturación (`docNumber.series`) se hardcodea a `"B"` de
  momento. En el futuro podría moverse a un campo configurable en Ajustes.
- **S-02:** La moneda siempre es `EUR` para todas las facturas, ya que el
  negocio opera en España.
- **S-03:** Los precios e impuestos mostrados en la preview son los configurados
  en Factura Directa para cada producto, no valores almacenados localmente.
- **S-04:** No existe un mapeo multi-línea de productos (un producto local →
  múltiples líneas en factura). Sin embargo, cuando varios productos locales
  apuntan al mismo `facturaDirectaUuid`, sus cantidades se consolidan en una
  única línea de factura. El mapeo explícito multi-línea se trata como mejora
  futura.
- **S-05:** Los `facturaDirectaUuid` almacenados en `Client` y `Product` ya
  incluyen los prefijos que requiere la API (`con_` para contactos, `pro_` para
  productos). Se usan tal cual sin transformación.
- **S-06:** Solo se creará UNA factura provisional por acción. No se contempla
  la generación masiva de facturas para múltiples clientes a la vez.

## 11) Preguntas abiertas

Todas las preguntas han sido resueltas:

- ~~**PA-01:**~~ Resuelto → Serie hardcodeada a `"B"` de momento.
- ~~**PA-02:**~~ Resuelto → Los UUID ya incluyen los prefijos (`con_`, `pro_`).
- ~~**PA-03:**~~ Resuelto → Mejora futura. De momento, si varios productos
  locales apuntan al mismo producto FD se consolidan sumando cantidades.
- ~~**PA-04:**~~ Resuelto → Se avisa al usuario si ya existe una factura
  provisional para el mismo cliente y fecha.

## 12) Notas para análisis técnico

- La opción de menú contextual ya existe como placeholder deshabilitado en
  `orders_table.dart` con el valor `'generate_provisional_invoice'`.
- Los datos del pedido están disponibles en `OrderSheet`: `clientIds[col]`,
  `productIds`, `quantities[productIdx][col]`.
- Los datos de FD del cliente están en `Client.facturaDirectaUuid` (Firestore).
- Los datos de FD del producto están en `Product.facturaDirectaUuid`
  (Firestore).
- El endpoint `GET /{companyId}/products` ya está implementado en
  `FacturaDirectaApiDataSource` y el use case `GetFdProducts` ya parsea
  `salesPrice`. Falta parsear `sales.tax` y `sales.description`.
- El endpoint `POST /{companyId}/invoices` NO existe en el data source actual.
  Debe añadirse al `FacturaDirectaApiDataSource`.
- La factura debe crearse SIEMPRE con `draft: true`. No se debe permitir nunca
  `draft: false` desde esta funcionalidad.
- No se debe realizar ninguna llamada POST a la API de FD que no sea la creación
  de la factura (`POST /{companyId}/invoices`).
- El body mínimo requerido por la API para crear la factura:
  ```json
  {
    "content": {
      "type": "invoice",
      "main": {
        "docNumber": { "series": "B" },
        "contact": "<con_uuid (ya incluye prefijo)>",
        "currency": "EUR",
        "date": "<YYYY-MM-DD>",
        "draft": true,
        "lines": [
          {
            "quantity": <num>,
            "unitPrice": <num>,
            "tax": ["<tax_id>"],
            "text": "<descripción>",
            "document": "<pro_uuid>"
          }
        ]
      }
    }
  }
  ```
- Restricción: `lines[].quantity`, `lines[].unitPrice` y `lines[].tax` son
  obligatorios según el schema `InvoiceMainLineWrite`.
- **Estado: Listo para análisis técnico**
