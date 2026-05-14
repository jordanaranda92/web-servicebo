# Functional Analysis: Dashboard de inicio con contadores y comparativas

- **Fecha:** 2026-05-06
- **Identificador:** home-dashboard
- **Estado:** Ready for technical analysis

## 1) Resumen

Transformar la pantalla de inicio (Home) — actualmente un placeholder con icono
y mensaje de bienvenida — en un **dashboard operativo** que muestre contadores
estadísticos del día y comparativas temporales contra periodos anteriores,
proporcionando al usuario una visión inmediata del estado de su negocio al abrir
la aplicación.

## 2) Contexto y objetivo

### Qué se solicita

Implementar una vista de inicio que presente:

1. **Contadores resumen del día**: métricas clave extraídas de los pedidos de
   hoy.
2. **Comparativas temporales**: variación de pedidos hoy frente a ayer, hoy
   frente al mismo día de la semana anterior, y semana actual frente a semana
   anterior.

### Qué problema resuelve

Actualmente el usuario abre la aplicación y ve una pantalla vacía sin
información útil. Debe navegar a "Pedidos de hoy" para tener contexto de su
actividad. El dashboard permite una lectura rápida del estado del negocio sin
navegación adicional.

### Qué resultado funcional se espera

Al acceder a la pantalla de inicio, el usuario visualiza de un vistazo:

- Cuántos clientes tienen pedido hoy
- Cuántos productos están activos
- El volumen total de unidades pedidas
- Cuál es el producto más pedido
- Cómo se comparan estos datos con ayer, con el mismo día de la semana pasada, y
  con la semana anterior completa

## 3) Alcance

### En alcance

- Contadores del día actual: clientes, productos activos, total unidades,
  producto estrella
- Comparativa hoy vs. ayer (día laborable anterior con datos)
- Comparativa hoy vs. mismo día de la semana anterior
- Comparativa semana actual (lunes a hoy) vs. mismos días de la semana anterior
- Indicadores visuales de tendencia (subida, bajada, sin cambio)
- Estado cuando no hay carpeta de trabajo configurada
- Estado cuando no hay datos para el día actual
- Estado cuando no existen datos históricos para una comparativa
- Estado de carga mientras se leen los archivos
- Estado de error si falla la lectura

### Fuera de alcance

- Gráficas o charts (solo contadores numéricos y porcentajes)
- Exportación o impresión del dashboard
- Personalización de qué contadores mostrar
- Comparativas con periodos superiores a una semana (mensual, anual)
- Comparativas por cliente individual o por producto individual
- Datos en tiempo real o auto-refresco automático periódico
- Navegación directa desde el dashboard a un pedido específico

## 4) Actores implicados

- **Usuario final**: único actor. Abre la aplicación y consulta la pantalla de
  inicio para obtener un resumen rápido de la actividad.

## 5) Requisitos funcionales

### Contadores del día

- **RF-01**: El sistema debe mostrar el número de clientes con pedido registrado
  hoy (filas en el archivo Excel del día).
- **RF-02**: El sistema debe mostrar el número de productos activos hoy
  (columnas de producto en el archivo Excel del día).
- **RF-03**: El sistema debe mostrar el total de unidades pedidas hoy (suma de
  todas las cantidades de todas las filas y columnas de producto).
- **RF-04**: El sistema debe mostrar el producto con mayor volumen de pedidos
  del día (producto cuya suma de cantidades en todas las filas es la más alta).
  Si hay empate, mostrar cualquiera de los empatados.

### Comparativas

- **RF-05**: El sistema debe comparar el total de unidades de hoy con el total
  de unidades de ayer. Mostrar la diferencia absoluta y porcentual.
- **RF-06**: El sistema debe comparar el número de clientes de hoy con el número
  de clientes de ayer. Mostrar la diferencia absoluta.
- **RF-07**: El sistema debe comparar el total de unidades de hoy con el total
  del mismo día de la semana anterior (hoy - 7 días). Mostrar diferencia
  absoluta y porcentual.
- **RF-08**: El sistema debe comparar el número de clientes de hoy con el número
  de clientes del mismo día de la semana anterior. Mostrar diferencia absoluta.
- **RF-09**: El sistema debe comparar el acumulado de unidades de la semana
  actual (desde el lunes hasta hoy inclusive) con el acumulado de los mismos
  días de la semana anterior. Mostrar diferencia absoluta y porcentual.
- **RF-10**: El sistema debe comparar el total de clientes únicos de la semana
  actual con los de los mismos días de la semana anterior. Mostrar diferencia
  absoluta.

### Indicadores visuales

- **RF-11**: Cada comparativa debe incluir un indicador de tendencia:
  - **Positivo** (más pedidos/clientes que el periodo de referencia): indicador
    verde con flecha ascendente.
  - **Negativo** (menos pedidos/clientes): indicador rojo con flecha
    descendente.
  - **Neutro** (sin cambio): indicador gris, sin flecha.

### Estados especiales

- **RF-12**: Si la carpeta de trabajo no está configurada, el dashboard debe
  mostrar un mensaje orientativo indicando que debe configurar la carpeta en
  Ajustes. No se muestran contadores.
- **RF-13**: Si no existe archivo de pedidos para hoy, los contadores del día
  muestran 0 (cero clientes, cero unidades, sin producto estrella). Las
  comparativas se calculan igualmente (hoy = 0 vs. el dato histórico que
  exista).
- **RF-14**: Si no existe archivo histórico para una fecha de comparación (ayer,
  hace 7 días, o algún día de las semanas comparadas), esa comparativa
  individual debe mostrar "Sin datos" en lugar de valores numéricos, sin afectar
  al resto de comparativas.
- **RF-15**: El dashboard debe mostrar un indicador de carga mientras se leen y
  procesan los archivos Excel.
- **RF-16**: Si ocurre un error de lectura de archivos, mostrar un estado de
  error con opción de reintentar.

## 6) Criterios de aceptación

- **CA-01**: Al abrir la app con carpeta configurada y archivo del día
  existente, se muestran los 4 contadores (clientes, productos, unidades,
  producto estrella) con valores correctos según el contenido del Excel.
- **CA-02**: Si hoy hay 15 unidades y ayer hubo 10, la comparativa muestra "+5
  (+50%)" con indicador verde.
- **CA-03**: Si hoy hay 8 unidades y ayer hubo 12, la comparativa muestra "-4
  (-33%)" con indicador rojo.
- **CA-04**: Si hoy y ayer tienen las mismas unidades, la comparativa muestra "0
  (0%)" con indicador neutro.
- **CA-05**: Si no existe el archivo de ayer, la comparativa "hoy vs. ayer"
  muestra "Sin datos".
- **CA-06**: Si hoy es miércoles 6 de mayo, la comparativa semanal equivalente
  toma el miércoles 29 de abril como referencia.
- **CA-07**: La comparativa semanal acumula de lunes a hoy (no de lunes a
  domingo). Si hoy es miércoles, compara lun+mar+mié de esta semana con
  lun+mar+mié de la anterior.
- **CA-08**: Si no hay carpeta de trabajo configurada, se muestra un mensaje
  orientativo sin contadores ni comparativas.
- **CA-09**: Si no hay archivo del día, los contadores muestran 0 y las
  comparativas funcionan normalmente comparando 0 contra el histórico.
- **CA-10**: Se muestra un indicador de carga mientras se procesan los archivos.
- **CA-11**: Si falla la lectura, se muestra un error con opción de reintentar.
- **CA-12**: La comparativa semanal funciona correctamente cuando faltan
  archivos de algunos días intermedios: se suman solo los días disponibles y se
  indica cuántos días tienen datos de cada semana.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario abre la aplicación o navega a la pantalla de inicio.
2. El sistema verifica si la carpeta de trabajo está configurada.
3. El sistema muestra un indicador de carga.
4. El sistema lee el archivo de pedidos de hoy (`historico/YYYY-MM-DD.xlsx`).
5. El sistema lee los archivos históricos necesarios para las comparativas
   (ayer, hace 7 días, días de ambas semanas).
6. El sistema calcula los contadores y las diferencias.
7. El sistema muestra el dashboard con contadores y comparativas.

### Flujos alternativos

- **FA-01 — Sin carpeta configurada**: En el paso 2, si no hay carpeta, se
  muestra mensaje orientativo y el flujo termina.
- **FA-02 — Sin archivo de hoy**: En el paso 4, si no existe el archivo, los
  contadores se inicializan a 0. El flujo continúa con las comparativas.
- **FA-03 — Archivo histórico ausente**: En el paso 5, si un archivo de
  comparación no existe, esa comparativa individual se marca como "Sin datos".
  Las demás continúan normalmente.
- **FA-04 — Error de lectura**: En el paso 4 o 5, si falla la lectura de
  archivos, se muestra estado de error con botón de reintentar.

### Estados especiales / excepciones

- **Estado vacío**: Carpeta configurada pero sin ningún archivo (ni hoy ni
  históricos). Se muestran contadores a 0 y todas las comparativas como "Sin
  datos".
- **Estado loading**: Spinner o skeleton mientras se leen los archivos Excel.
- **Estado error**: Mensaje de error con botón "Reintentar" que vuelve a
  ejecutar el flujo desde el paso 3.
- **Sin carpeta de trabajo**: Mensaje orientativo con indicación de ir a
  Ajustes.

## 8) Edge cases

- **EC-01**: Hoy es lunes → la comparativa "hoy vs. ayer" usa el domingo (si
  existe) o el viernes. **Decisión**: usar estrictamente "hoy - 1 día
  calendario" sin saltar fines de semana, ya que el negocio podría operar
  cualquier día.
- **EC-02**: Hoy es lunes → la comparativa semanal solo tiene 1 día (el lunes).
  Se compara lunes de esta semana con lunes de la anterior.
- **EC-03**: Archivo Excel del día existe pero está vacío (0 filas de clientes).
  Los contadores muestran 0 clientes, 0 unidades, y "—" como producto estrella.
- **EC-04**: Archivo Excel tiene filas de clientes pero todas las cantidades
  son 0. Total unidades = 0, producto estrella = "—" (ninguno).
- **EC-05**: Solo existe el archivo de hoy y ningún histórico. Todas las
  comparativas muestran "Sin datos".
- **EC-06**: El archivo de una fecha de comparación existe pero tiene formato
  inválido (no se puede parsear). Se trata como "Sin datos" para esa
  comparativa, sin bloquear las demás.
- **EC-07**: Porcentaje de variación cuando el valor de referencia es 0 y el
  actual es > 0. Mostrar "+N unidades" sin porcentaje (evitar división por
  cero).
- **EC-08**: Porcentaje de variación cuando ambos valores son 0. Mostrar "0
  (0%)".

## 9) Impacto funcional

### Módulos o procesos afectados

- **Feature Home**: se reemplaza el contenido placeholder actual por el
  dashboard.
- **Feature Orders Today**: se reutiliza su `ExcelLocalDataSource` y la entidad
  `OrderSheet` para leer datos.
- **Feature Orders History**: se reutiliza su `OrdersHistoryRepository` para
  acceder a datos de fechas pasadas.
- **Feature Settings**: se consulta el `SettingsRepository` para obtener la ruta
  de la carpeta de trabajo.
- **DI (injection)**: se requiere registrar nuevas dependencias (repository, use
  case, cubit del dashboard).

### Impacto en usuario o negocio

- El usuario obtiene información inmediata al abrir la app, reduciendo la
  necesidad de navegar para conocer el estado del día.
- Las comparativas permiten detectar tendencias (caídas o subidas de pedidos) de
  un vistazo.

### Impacto en experiencia de usuario

- La pantalla de inicio pasa de ser inútil (placeholder) a ser el punto de
  entrada más valioso de la aplicación.
- El tiempo de carga podría ser perceptible si hay muchos archivos históricos
  que leer (hasta ~12 archivos para comparativas semanales).

## 10) Suposiciones

- **S-01**: Los archivos históricos siguen el formato
  `historico/YYYY-MM-DD.xlsx` y son legibles por el `ExcelLocalDataSource`
  existente.
- **S-02**: "Ayer" se define como el día calendario anterior (`today - 1`), sin
  distinguir entre días laborables y fines de semana. Los fines de semana son
  operativos.
- **S-03**: "Semana" se define de lunes a domingo (estándar ISO).
- **S-04**: El concepto de "clientes únicos" en la comparativa semanal se basa
  en la cuenta total de filas por día (un mismo cliente que aparezca en dos días
  distintos se cuenta en ambos). No se deduplica entre días.
- **S-05**: Los datos se cargan al entrar en la pantalla y se recargan al volver
  a ella. No hay refresco automático periódico.
- **S-06**: En la comparativa semanal, cuando faltan archivos de días
  intermedios, se suman solo los días disponibles sin indicar cuántos faltan.

## 11) Preguntas abiertas

No quedan preguntas abiertas. Todas resueltas e incorporadas a las suposiciones
(S-02, S-05, S-06).

## 12) Notas para análisis técnico

- **Reutilización**: el `ExcelLocalDataSource` y `OrdersHistoryRepository` ya
  proporcionan toda la infraestructura de lectura. No se necesitan nuevos data
  sources.
- **Rendimiento**: la comparativa semanal requiere leer hasta 12 archivos Excel.
  Considerar paralelización (`Future.wait`) y posible caching en memoria durante
  la sesión del cubit.
- **División por cero**: al calcular porcentajes, proteger contra valor de
  referencia = 0.
- **Dependencias visibles**: `SettingsRepository` (carpeta de trabajo),
  `OrdersHistoryRepository` (datos históricos), `OrdersTodayRepository` (datos
  del día), `ExcelLocalDataSource` (lectura directa si se crea un repository
  propio para el dashboard).
- **Consideraciones**: el dashboard no modifica datos; es puramente de lectura.
- **Estado: Listo para análisis técnico**
