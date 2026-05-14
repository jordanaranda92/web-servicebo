# Functional Analysis: Auto-creación de pedidos de hoy con animación

- **Fecha:** 2026-05-10
- **Identificador:** auto-create-today-orders
- **Estado:** Ready for technical analysis

## 1) Resumen

Cuando el usuario accede a la pantalla "Pedidos de hoy" y no existe el documento
del día en Firestore, el sistema debe generar automáticamente la plantilla de
pedidos sin intervención del usuario. Durante la generación se muestra una
animación con un mensaje informativo que dura como mínimo 3 segundos,
proporcionando una experiencia de carga intencionada en lugar del estado vacío
actual con botón manual.

## 2) Contexto y objetivo

- **Qué se solicita:** Eliminar la acción manual de pulsar "+ Crear pedido de
  hoy" y sustituirla por una creación automática con feedback visual animado.
- **Qué problema resuelve:** Actualmente, al abrir la pantalla el usuario ve un
  estado vacío ("No hay pedidos para hoy") y debe pulsar un botón para generar
  la plantilla. Esto añade fricción innecesaria: si no hay pedidos de hoy,
  siempre se van a crear, por lo que no tiene sentido requerir confirmación.
- **Resultado funcional esperado:** Al navegar a "Pedidos de hoy", si no hay
  datos del día, la pantilla se genera automáticamente y el usuario ve una
  animación de preparación durante al menos 3 segundos antes de mostrar la tabla
  de pedidos.

## 3) Alcance

### En alcance

- Detección automática de ausencia del documento de pedidos del día al cargar la
  pantalla.
- Generación automática de la plantilla (equivalente a la acción actual
  `CreateTodayFile`).
- Animación/indicador visual con mensaje "Preparando plantilla para pedidos de
  hoy" (o equivalente i18n) durante la creación.
- Duración mínima garantizada de 3 segundos para la animación,
  independientemente de cuánto tarde la operación real en Firestore.
- Transición fluida desde la animación a la tabla de pedidos ya cargada.

### Fuera de alcance

- Cambios en la lógica de creación del documento en Firestore (se reutiliza la
  existente).
- Rediseño visual general de la pantalla de pedidos.
- Modificación del comportamiento cuando el documento ya existe (flujo normal
  sin cambios).
- Gestión de permisos o roles de usuario para decidir si se crea
  automáticamente.
- Eliminación del botón manual de creación en otros contextos fuera de esta
  pantalla.

## 4) Actores implicados

| Actor                     | Rol                                                                   |
| ------------------------- | --------------------------------------------------------------------- |
| Usuario final (operador)  | Navega a la pantalla de pedidos de hoy y espera que estén disponibles |
| Sistema (app + Firestore) | Detecta ausencia, genera la plantilla y notifica la finalización      |

## 5) Requisitos funcionales

- **RF-01:** Al acceder a "Pedidos de hoy", si no existe el documento del día en
  Firestore, el sistema debe iniciar la creación automáticamente sin acción del
  usuario.
- **RF-02:** Durante la creación automática, la pantalla debe mostrar una
  animación visual acompañada de un mensaje informativo (p. ej. "Preparando
  plantilla para pedidos de hoy").
- **RF-03:** La animación debe permanecer visible durante un mínimo de 3
  segundos, incluso si la creación en Firestore finaliza antes.
- **RF-04:** Al completar tanto la creación como el tiempo mínimo de 3 segundos,
  la pantalla debe transicionar automáticamente a la tabla de pedidos cargada.
- **RF-05:** Si la creación falla, se debe mostrar el estado de error existente
  con opción de reintentar (no queda en bucle de animación).
- **RF-06:** El texto del mensaje mostrado durante la animación debe estar
  internacionalizado (i18n), no hardcodeado.
- **RF-07:** Si el usuario sale de la pantalla durante la animación y vuelve, el
  sistema debe comportarse correctamente (no duplicar creaciones, mostrar el
  estado correcto).
- **RF-08:** La auto-creación solo se dispara en la carga inicial de la pantalla
  cuando no existe documento. Si el documento se elimina externamente mientras
  la pantalla está activa, se debe mostrar el estado vacío existente con botón
  manual de creación (no auto-crear de nuevo).

## 6) Criterios de aceptación

- **CA-01:** Dado que el usuario accede a "Pedidos de hoy" y no existe documento
  para la fecha actual, cuando la pantalla se carga, entonces la plantilla se
  crea automáticamente sin que el usuario pulse ningún botón.
- **CA-02:** Dado que se inicia la creación automática, cuando la pantalla está
  en proceso de generación, entonces se muestra una animación con el mensaje
  informativo.
- **CA-03:** Dado que la creación en Firestore tarda menos de 3 segundos, cuando
  la operación completa, entonces la animación permanece visible hasta cumplir
  los 3 segundos y después muestra la tabla.
- **CA-04:** Dado que la creación en Firestore tarda más de 3 segundos, cuando
  la operación completa, entonces la tabla se muestra inmediatamente después de
  que Firestore responda.
- **CA-05:** Dado que la creación falla, cuando el sistema detecta el error,
  entonces se muestra el estado de error con botón de reintento (ya existente).
- **CA-06:** Dado que el usuario accede a "Pedidos de hoy" y ya existe el
  documento, entonces la pantalla se carga normalmente sin animación de
  preparación.
- **CA-07:** Dado que el sistema ya detectó que no hay documento y está en
  proceso de creación, si el método de creación detecta que el documento ya
  existe (creado por otro dispositivo concurrentemente), entonces carga el
  documento existente sin error.

## 7) Flujos y comportamiento esperado

### Flujo principal (no existe documento del día)

1. El usuario navega a la pantalla "Pedidos de hoy".
2. El sistema consulta Firestore para verificar si existe el documento del día.
3. Firestore responde que **no existe**.
4. El sistema inicia simultáneamente:
   - a) La creación de la plantilla en Firestore.
   - b) Un temporizador de 3 segundos.
5. La pantalla muestra la animación con el mensaje "Preparando plantilla para
   pedidos de hoy".
6. La creación finaliza con éxito.
7. El temporizador de 3 segundos finaliza (o ya ha finalizado).
8. Cuando ambos (creación y temporizador) han completado, la pantalla
   transiciona a la tabla de pedidos cargada.

### Flujos alternativos

- **FA-01 — Documento ya existe:** En el paso 3, Firestore responde que el
  documento ya existe → se carga directamente la tabla sin animación (flujo
  actual sin cambios).
- **FA-02 — Error en creación:** En el paso 6, la creación falla → se muestra el
  estado de error con botón de reintento. Al pulsar reintento, se vuelve al
  paso 2.
- **FA-03 — Creación concurrente:** Otro dispositivo crea el documento mientras
  esta instancia está en proceso → la lógica de `createTodaySheet` ya maneja
  este caso (detecta documento existente y lo carga).
- **FA-04 — Reintento tras error:** El usuario pulsa "Reintentar" desde el
  estado de error → se repite el flujo principal desde el paso 2.

### Estados especiales / excepciones

- **Estado loading/procesando:** Animación con mensaje i18n. Duración mínima 3
  segundos. No muestra spinner genérico, sino una animación específica.
- **Estado error:** Estado de error existente (`OrdersErrorState`) con botón de
  reintento.
- **Firebase no disponible:** Flujo existente sin cambios — se muestra el
  mensaje de "nube no disponible" con enlace a configuración.
- **Estado vacío:** Ya no se mostrará el estado vacío actual
  (`OrdersEmptyState`) al cargar la pantalla. El estado vacío con botón manual
  se elimina de este flujo.

## 8) Edge cases

- **EC-01:** La creación tarda exactamente 3 segundos → la tabla se muestra
  inmediatamente al completar.
- **EC-02:** La creación tarda 0.5 segundos → la animación se mantiene otros 2.5
  segundos antes de mostrar la tabla.
- **EC-03:** La creación tarda 10 segundos → no hay tiempo mínimo que esperar;
  la tabla se muestra al completar la creación.
- **EC-04:** El usuario navega fuera y vuelve durante la creación → al volver,
  si el documento ya existe (creado en la visita anterior), se carga
  directamente. Si no existe aún (creación en curso o fallida), se reinicia el
  flujo.
- **EC-05:** Pérdida de conectividad durante la creación → Firestore falla → se
  muestra estado de error.
- **EC-06:** El documento del día se elimina externamente mientras se muestra la
  tabla → el listener Firestore existente (`watchTodayOrders`) emitirá `null` y
  el BLoC transitará a `OrdersTodayNoFile`. En este caso **no** se dispara
  auto-creación; se muestra un estado informativo indicando que el documento fue
  eliminado, con opción manual de volver a crearlo.

## 9) Impacto funcional

- **Módulos afectados:** Feature `orders_today` — capa de presentación (BLoC +
  UI). La capa de dominio y datos no requiere cambios funcionales.
- **Impacto en usuario:** Reduce fricción al eliminar un paso manual
  innecesario. La animación proporciona feedback positivo y da sensación de
  "preparación inteligente".
- **Impacto en experiencia de usuario:** Mejora percibida — el usuario percibe
  que el sistema trabaja proactivamente para tener todo listo. El mínimo de 3
  segundos evita un flash molesto si la creación es instantánea.
- **Impacto en i18n:** Se requiere una nueva clave de localización para el
  mensaje de la animación.

## 10) Suposiciones

- **S-01:** La creación automática es segura de ejecutar siempre que no exista
  el documento del día. No hay escenarios donde se deba evitar la creación
  automática (p. ej. no hay roles que restrinjan quién puede crear pedidos).
- **S-02:** La lógica existente de `createTodaySheet` ya es idempotente (detecta
  documentos existentes y los carga en lugar de fallar), por lo que es segura
  ante creaciones concurrentes.
- **S-03:** El mínimo de 3 segundos es un requisito de UX, no técnico. Se busca
  que la animación se sienta natural y no un flash instantáneo.
- **S-04:** La animación puede ser un indicador de progreso genérico (tipo
  Lottie, circular, o shimmer) acompañado del texto. No se ha especificado una
  animación concreta.

## 11) Preguntas abiertas

- **PA-01:** ¿Se desea un tipo de animación específica (Lottie, shimmer,
  circular progress con texto) o se deja a criterio de implementación?
- ~~**PA-02:**~~ Resuelto: si el documento se elimina externamente, **no** se
  auto-crea de nuevo. Se muestra el estado vacío con botón manual.

## 12) Notas para análisis técnico

- El BLoC ya tiene el estado `OrdersTodayNoFile` y el evento
  `OrdersTodayCreateFileRequested`. El cambio principal es que al detectar
  `NoFile`, se dispare automáticamente la creación en lugar de esperar input del
  usuario.
- Se necesita un nuevo estado BLoC (o variante de `OrdersTodayLoading`) que
  distinga la carga normal del estado de "preparando plantilla" con animación
  mínima de 3 segundos.
- La lógica de "esperar el mayor entre creación y 3 segundos" puede
  implementarse con `Future.wait` combinando la creación y un `Future.delayed`.
- La protección contra doble creación ya existe en `createTodaySheet` del
  repositorio (verifica existencia antes de crear).
- Se necesita una nueva clave i18n para el mensaje de animación.
- **Estado: Listo para análisis técnico**
