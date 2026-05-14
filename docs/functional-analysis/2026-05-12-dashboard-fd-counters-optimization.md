# Functional Analysis: Optimización de consultas de facturas en el Dashboard

- **Fecha:** 2026-05-12
- **Identificador:** dashboard-fd-counters-optimization
- **Estado:** Ready for technical analysis

## 1) Resumen

Optimizar la carga de datos del dashboard (Home) para que, en lugar de obtener
las últimas 500 facturas de FacturaDirecta y filtrar en memoria, se realicen
consultas acotadas por rango de fechas. Esto reduce el volumen de datos
transferidos, mejora el tiempo de respuesta y garantiza la exactitud de las
comparativas temporales.

## 2) Contexto y objetivo

- **Qué se solicita:** Refactorizar la obtención de datos de facturas en el
  dashboard para usar filtros de fecha (`minDate`/`maxDate`) que ya soporta la
  API de FacturaDirecta, en lugar de descargar un bloque masivo de 500 facturas.

- **Qué problema resuelve:**
  1. **Ineficiencia**: se descargan hasta 500 facturas para mostrar solo las de
     hoy (típicamente unas pocas).
  2. **Inexactitud potencial**: si existen más de 500 facturas, las más antiguas
     se pierden, haciendo que las comparativas del mes anterior o semana
     anterior puedan ser incorrectas o incompletas.
  3. **Ancho de banda y latencia**: se transfieren datos innecesarios a través
     de la Cloud Function proxy, aumentando el tiempo de carga del dashboard.

- **Qué resultado funcional se espera:** El dashboard muestra los mismos
  contadores y comparativas actuales (facturas de hoy, total facturado,
  comparativas vs ayer / mismo día semana pasada / semana / mes), pero
  obteniéndolos con consultas de fecha acotadas, más rápidas y con datos
  completos dentro del rango solicitado.

## 3) Alcance

### En alcance

- Sustituir la petición única `GET /invoices?limit=500&related=state` por
  consultas filtradas por rango de fechas (`minDate`/`maxDate`) al endpoint
  `/invoices` de FacturaDirecta (vía proxy `fdProxy`).
- Calcular los rangos de fecha necesarios según la lógica actual de
  comparativas:
  - Hoy
  - Ayer
  - Mismo día de la semana pasada
  - Semana actual (lunes → hoy) vs semana anterior equivalente
  - Mes actual (día 1 → hoy) vs mes anterior equivalente
- Consolidar los rangos en el mínimo número de peticiones posible (idealmente 2
  peticiones paralelas).
- Mantener el comportamiento funcional idéntico: mismos contadores, mismas
  comparativas, mismos estados (loading, error, loaded, not configured).
- Eliminar el límite arbitrario de 500 que actualmente condiciona la completitud
  de los datos.

### Fuera de alcance

- Modificar la Cloud Function `fdProxy` (ya soporta pasar query parameters
  arbitrarios al endpoint de FacturaDirecta).
- Cambiar la UI del dashboard (cards, comparativas, layout).
- Añadir nuevas métricas o comparativas al dashboard.
- Cachear datos de facturas en el dashboard.
- Modificar el flujo de la pantalla de facturas (`InvoicesPage`), que seguirá
  usando su propia lógica de carga.

## 4) Actores implicados

- **Sistema (dashboard):** Proceso interno que carga y calcula las métricas al
  entrar en la Home.
- **Sistema externo:** API REST de FacturaDirecta (endpoint `GET /invoices` con
  soporte de `minDate`, `maxDate`), invocada a través de la Cloud Function
  `fdProxy`.

## 5) Requisitos funcionales

- **RF-01:** El dashboard debe obtener las facturas de FacturaDirecta usando
  parámetros `minDate` y `maxDate` en lugar de un `limit` fijo.
- **RF-02:** Las peticiones deben cubrir exactamente los rangos de fechas
  necesarios para calcular:
  - Contadores de hoy (número de facturas, total facturado).
  - Comparativa vs ayer.
  - Comparativa vs mismo día de la semana pasada.
  - Comparativa semana actual vs semana anterior (mismo rango de días).
  - Comparativa mes actual vs mes anterior (mismo rango de días).
- **RF-03:** Los rangos de fechas deben consolidarse para minimizar el número de
  peticiones a la API. El número máximo de peticiones debe ser 2:
  - Petición A: rango que cubra desde el inicio del mes actual hasta hoy
    (incluye hoy, ayer, semana actual y eventualmente el día equivalente de la
    semana pasada si cae en el mismo mes).
  - Petición B: rango que cubra desde el inicio del mes anterior hasta el día
    equivalente del mes anterior (incluye semana anterior y día equivalente si
    caen en el mes anterior).
- **RF-04:** Ambas peticiones deben ejecutarse en paralelo para minimizar el
  tiempo total de carga.
- **RF-05:** El resultado funcional (contadores y comparativas mostrados al
  usuario) debe ser idéntico al comportamiento actual, con la diferencia de que
  los datos serán completos y no limitados a 500 registros.
- **RF-06:** No debe aplicarse un `limit` arbitrario. Si se necesita un límite
  como protección, debe ser suficientemente alto para cubrir el volumen real del
  rango (e.g., 5000) y documentarse como supuesto.
- **RF-07:** La gestión de estados (loading, error, loaded, not configured) debe
  permanecer sin cambios funcionales. Un error en cualquiera de las dos
  peticiones debe resultar en estado de error del dashboard.

## 6) Criterios de aceptación

- **CA-01:** Al acceder al dashboard, las peticiones a FacturaDirecta incluyen
  los parámetros `minDate` y `maxDate` correspondientes al mes actual y al mes
  anterior, respectivamente.
- **CA-02:** No se envía una petición con `limit=500` sin filtro de fechas para
  el dashboard.
- **CA-03:** Los contadores de "Facturas" y "Total facturado" del día actual
  muestran los mismos valores que se obtendrían con la implementación anterior
  (dado que los datos están dentro del rango).
- **CA-04:** Las 4 comparativas (vs ayer, vs mismo weekday, vs semana anterior,
  vs mes anterior) muestran valores correctos y completos, incluso si el volumen
  total de facturas supera 500.
- **CA-05:** El tiempo de carga percibido del dashboard se reduce respecto a la
  implementación actual (menos datos transferidos).
- **CA-06:** Si la API devuelve error en alguna de las dos peticiones, el
  dashboard muestra el estado de error sin crash.
- **CA-07:** Si FacturaDirecta no está configurada, el comportamiento es
  idéntico al actual (estado "not configured").

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario accede al dashboard (Home).
2. El sistema calcula los rangos de fechas necesarios a partir de la fecha
   actual:
   - **Rango A (mes actual):** `minDate` = 1er día del mes actual, `maxDate` =
     hoy.
   - **Rango B (mes anterior):** `minDate` = 1er día del mes anterior, `maxDate`
     = día equivalente del mes anterior (mismo número de día, o último día del
     mes si el día actual no existe en el mes anterior).
3. El sistema lanza ambas peticiones en paralelo a la API de FacturaDirecta (vía
   proxy `fdProxy`):
   - `GET /invoices?minDate=YYYY-MM-DD&maxDate=YYYY-MM-DD&related=state`
   - `GET /invoices?minDate=YYYY-MM-DD&maxDate=YYYY-MM-DD&related=state`
4. Ambas respuestas llegan correctamente.
5. El sistema combina las facturas obtenidas y calcula:
   - Facturas de hoy → contadores.
   - Facturas de ayer → comparativa vs ayer.
   - Facturas del mismo día de la semana pasada → comparativa vs weekday.
   - Facturas lunes→hoy (semana actual) vs lunes→mismo día (semana anterior) →
     comparativa semanal.
   - Facturas día 1→hoy (mes actual) vs día 1→equivalente (mes anterior) →
     comparativa mensual.
6. El dashboard muestra los contadores y las comparativas.

### Flujos alternativos

- **FA-01 — Una petición falla:** Si la petición A o B falla (error de red,
  timeout, error del proxy), el dashboard muestra estado de error en los
  contadores de FacturaDirecta. El resto del dashboard no se ve afectado.
- **FA-02 — Rango B cae parcialmente en el mes actual:** Si la semana anterior
  abarca parcialmente el mes actual (e.g., hoy es 3 de mayo, la semana anterior
  empezó el 28 de abril), el rango A (mes actual) no incluirá los días del mes
  anterior. El rango B debe cubrir desde el inicio del mes anterior, lo cual ya
  incluye esos días. La lógica de filtrado en memoria extrae los días correctos
  de la unión de ambos resultados.
- **FA-03 — Primer día del mes:** Si hoy es día 1, el rango A solo contiene un
  día. La comparativa mensual compara ese único día contra el día 1 del mes
  anterior (también contenido en rango B).

### Estados especiales / excepciones

- **Estado vacío:** No hay facturas en ninguno de los rangos solicitados. Los
  contadores muestran 0 y las comparativas muestran diferencias de 0 (tendencia
  neutral).
- **Estado loading:** Mientras las peticiones están en curso, los contadores y
  las comparativas muestran skeleton/loading (comportamiento actual).
- **Estado error:** Error en la comunicación con el proxy o FacturaDirecta. Se
  muestra estado de error en las cards de FacturaDirecta sin afectar al resto.
- **No configurado:** Si la cuenta de FacturaDirecta no está configurada, no se
  realizan peticiones y se muestra estado "not configured" (comportamiento
  actual).

## 8) Edge cases

- **EC-01 — Cambio de mes al límite:** Si hoy es el 31 de marzo y el mes
  anterior (febrero) tiene 28/29 días, el día equivalente del mes anterior debe
  ser el 28 (o 29 en bisiesto), no el 31.
- **EC-02 — Lunes como primer día:** Si hoy es lunes, la "semana actual" solo
  tiene un día (hoy). La semana anterior equivalente es el lunes anterior (un
  solo día también).
- **EC-03 — Año cruzado:** Si hoy es enero, el "mes anterior" es diciembre del
  año anterior. Los rangos deben calcularse correctamente con año y mes.
- **EC-04 — Volumen alto dentro del rango:** Si el rango de un mes contiene
  cientos o miles de facturas, la petición debe devolverlas todas (sin truncar
  por un limit de 500). Se debe usar un limit suficientemente alto o no
  especificar limit si la API lo permite.

## 9) Impacto funcional

- **Módulos afectados:**
  - Feature Home: `FdCountersCubit` (lógica de carga y cálculo).
  - Feature Invoices: puede necesitar un nuevo use case o ampliación del
    existente para soportar parámetros de fecha.
  - Core datasource: `FacturaDirectaApiDataSource` necesita un método de
    consulta de facturas por rango sin requerir `contactUuid`.
- **Impacto en usuario:** Mejora de rendimiento percibido (dashboard carga más
  rápido). Datos de comparativas más fiables al no estar limitados a 500
  registros.
- **Impacto en costes:** Menor consumo de la Cloud Function (menos datos
  procesados por invocación). Menor ancho de banda.
- **Sin cambios en UX:** La interfaz del dashboard permanece idéntica.

## 10) Suposiciones

- **S-01:** La API de FacturaDirecta soporta los parámetros `minDate` y
  `maxDate` en el endpoint `GET /invoices` sin requerir `contact`. Esto se
  sustenta en que el método `getInvoicesByContact` ya los usa, pero se asume que
  también funcionan sin el parámetro `contact`.
- **S-02:** La API de FacturaDirecta devuelve todas las facturas dentro del
  rango sin necesidad de paginación si no se especifica `limit`, o acepta un
  `limit` alto suficiente. En caso contrario, se deberá implementar paginación
  (fuera de alcance de este análisis).
- **S-03:** El proxy `fdProxy` no impone restricciones adicionales sobre los
  query parameters enviados.
- **S-04:** Los rangos de un mes (máximo ~31 días) producen un volumen de
  facturas manejable en una sola respuesta (estimación: decenas a cientos, no
  miles).

## 11) Preguntas abiertas

- **PA-01:** ¿La API de FacturaDirecta permite `minDate`/`maxDate` sin el
  parámetro `contact` obligatorio? Verificar con la documentación de la API o
  con una prueba directa.
- **PA-02:** ¿Existe un límite máximo de registros por respuesta en la API de
  FacturaDirecta? Si sí, ¿es configurable o requiere paginación?

## 12) Notas para análisis técnico

- La interfaz `FacturaDirectaApiDataSource` ya tiene `getInvoicesByContact` con
  `minDate`/`maxDate`. Se necesita un método similar pero sin `contactUuid`
  obligatorio (e.g., `getInvoicesByDateRange`).
- El `FdCountersCubit` actualmente depende del use case `GetInvoices` (sin
  parámetros). Se necesitará un nuevo use case (e.g.,
  `GetInvoicesByDateRange(minDate, maxDate)`) o parametrizar el existente.
- Las dos peticiones se pueden lanzar con `Future.wait` para paralelismo.
- La lógica de cálculo de comparativas en el cubit se simplifica: en lugar de
  filtrar una lista enorme en memoria, se filtran listas ya acotadas por rango.
- Los edge cases de cambio de mes/año (EC-01, EC-03) ya están manejados en la
  lógica actual del cubit y deben preservarse.
- **Fuente:** docs/functional-analysis/2026-05-08-dashboard-fd-counters.md
  (análisis original de los contadores del dashboard).
- **Estado: Listo para análisis técnico**
