# Functional Analysis: Contadores de Albaranes y Facturas en el Dashboard

- **Fecha:** 2026-05-08
- **Identificador:** dashboard-fd-counters
- **Estado:** Ready for technical analysis

## 1) Resumen

Añadir dos nuevos contadores ("Albaranes" y "Facturas") a la sección "Resumen
del día" del dashboard (home). Estos contadores muestran la cantidad total de
albaranes y facturas obtenidas desde la API de FacturaDirecta. Al pulsar sobre
cada card, el usuario navega a la vista correspondiente (Albaranes o Facturas).
Si la cuenta de FacturaDirecta no está configurada, cada card muestra un aviso
indicándolo en lugar del valor numérico.

## 2) Contexto y objetivo

- **Qué se solicita:** Ampliar el grid de `StatCard` del "Resumen del día" en la
  home con dos cards adicionales que reflejen datos provenientes de
  FacturaDirecta.
- **Qué problema resuelve:** Actualmente el dashboard solo muestra métricas
  locales de pedidos (clientes, productos, unidades, top producto). El usuario
  no tiene visibilidad rápida sobre sus albaranes y facturas sin navegar a las
  secciones específicas.
- **Qué resultado funcional se espera:** El usuario ve de un vistazo cuántos
  albaranes y facturas tiene en FacturaDirecta, y puede acceder a su listado con
  un solo clic desde el dashboard.

## 3) Alcance

### En alcance

- Añadir un `StatCard` de "Albaranes" en la sección "Resumen del día" de la home
  que muestre el número total de albaranes obtenidos del endpoint
  `GET /{companyId}/deliveryNotes` de FacturaDirecta.
- Añadir un `StatCard` de "Facturas" en la sección "Resumen del día" de la home
  que muestre el número total de facturas obtenidas del endpoint
  `GET /{companyId}/invoices` de FacturaDirecta.
- Al pulsar la card de "Albaranes", navegar a la vista de Albaranes (índice 6
  del menú lateral).
- Al pulsar la card de "Facturas", navegar a la vista de Facturas (índice 7 del
  menú lateral).
- Si la configuración de FacturaDirecta no existe (sin `companyId` o
  `apiToken`), mostrar un aviso visual en cada card en lugar del contador
  numérico.
- Los contadores se cargan al mismo tiempo que el resto de datos del dashboard.
- Gestionar los estados de carga, error y éxito de estos contadores de forma
  independiente al dashboard local (los contadores existentes no deben verse
  afectados si FacturaDirecta falla).

### Fuera de alcance

- Mostrar detalle o desglose de los albaranes/facturas en las cards (solo el
  número total).
- Filtrar o paginar los datos de FacturaDirecta desde el dashboard.
- Cachear los datos de FacturaDirecta en el dashboard.
- Modificar el comportamiento o presentación de los 4 `StatCard` existentes
  (clientes, productos, unidades totales, producto top).
- Crear nuevos endpoints o lógica en la API de FacturaDirecta.

## 4) Actores implicados

- **Usuario final:** Persona que usa Servicebo para gestionar pedidos y
  consultar datos de facturación.
- **Sistema externo:** API REST de FacturaDirecta
  (`GET /{companyId}/deliveryNotes`, `GET /{companyId}/invoices`).

## 5) Requisitos funcionales

- **RF-01:** La sección "Resumen del día" del dashboard debe mostrar 6 cards en
  lugar de 4, añadiendo "Albaranes" y "Facturas" al final del grid existente.
- **RF-02:** La card "Albaranes" debe mostrar como valor el número de albaranes
  **del día actual** devueltos por la API de FacturaDirecta (filtrados por fecha
  = hoy).
- **RF-03:** La card "Facturas" debe mostrar como valor el número de facturas
  **del día actual** devueltas por la API de FacturaDirecta (filtradas por fecha
  = hoy).
- **RF-04:** Al pulsar la card "Albaranes", el sistema debe navegar a la página
  de Albaranes (equivalente a pulsar el ítem "Albaranes" del menú lateral).
- **RF-05:** Al pulsar la card "Facturas", el sistema debe navegar a la página
  de Facturas (equivalente a pulsar el ítem "Facturas" del menú lateral).
- **RF-06:** Si la configuración de FacturaDirecta no está guardada (sin
  `companyId` o `apiToken`), ambas cards deben mostrar un aviso visual (por
  ejemplo, un icono de advertencia y un texto corto como "Sin configurar") en
  lugar del valor numérico.
- **RF-07:** El fallo en la obtención de datos de FacturaDirecta (error de red,
  credenciales inválidas, etc.) NO debe impedir la carga del resto del
  dashboard. Los 4 contadores locales deben seguir mostrándose normalmente.
- **RF-08:** Si la llamada a FacturaDirecta falla por error de red/API, las
  cards de Albaranes y Facturas deben mostrar un estado de error (por ejemplo,
  "Error" o un icono indicativo) sin bloquear el dashboard.
- **RF-09:** Los textos de las nuevas cards deben estar internacionalizados
  (i18n).

## 6) Criterios de aceptación

- **CA-01:** Al acceder al dashboard con FacturaDirecta configurada y operativa,
  se muestran 6 cards en "Resumen del día": las 4 existentes más "Albaranes"
  (con el número total) y "Facturas" (con el número total).
- **CA-02:** Al pulsar la card "Albaranes" se navega a la vista de Albaranes. Al
  pulsar "Facturas" se navega a la vista de Facturas.
- **CA-03:** Sin configuración de FacturaDirecta, el dashboard carga normalmente
  los 4 contadores locales; las cards "Albaranes" y "Facturas" muestran un aviso
  de "Sin configurar" (o equivalente).
- **CA-04:** Si la API de FacturaDirecta devuelve error (red, 401, 500...), las
  cards "Albaranes" y "Facturas" muestran un indicador de error; los 4
  contadores locales se muestran con normalidad.
- **CA-05:** Durante la carga de datos de FacturaDirecta, las cards pueden
  mostrar un indicador de carga (spinner o placeholder) mientras los contadores
  locales ya se muestran.
- **CA-06:** Todos los textos visibles ("Albaranes", "Facturas", "Sin
  configurar", etc.) están internacionalizados.

## 7) Flujos y comportamiento esperado

### Flujo principal

1. El usuario accede al dashboard (Home).
2. El sistema verifica si existe una carpeta de Google Drive configurada (lógica
   existente).
3. El sistema carga los datos locales del dashboard (clientes, productos,
   unidades, top producto) — lógica existente que no cambia.
4. **En paralelo**, el sistema verifica si existe configuración de
   FacturaDirecta (companyId + apiToken).
5. Si la configuración existe, el sistema llama a
   `GET /{companyId}/deliveryNotes` y `GET /{companyId}/invoices` para obtener
   los contadores.
6. Se muestra la sección "Resumen del día" con 6 cards: las 4 existentes más
   "Albaranes" (cantidad) y "Facturas" (cantidad).
7. El usuario pulsa sobre la card "Albaranes" → el sistema navega a la vista de
   Albaranes (cambia el ítem seleccionado en el menú lateral al índice 6).
8. (Alternativamente) El usuario pulsa sobre la card "Facturas" → el sistema
   navega a la vista de Facturas (índice 7).

### Flujos alternativos

- **FA-01 — Sin configuración de FacturaDirecta:** En el paso 4, si no hay
  configuración guardada, las cards de "Albaranes" y "Facturas" muestran un
  aviso visual ("Sin configurar") sin icono de error ni spinner. Las 4 cards
  existentes se muestran normalmente. Al pulsar la card con el aviso, se podría
  navegar igualmente a la sección correspondiente (donde recibirá el mismo
  mensaje de "configurar en Ajustes").
- **FA-02 — Error de red/API en FacturaDirecta:** En el paso 5, si la llamada a
  la API falla, las cards de "Albaranes" y "Facturas" muestran un estado de
  error visual (texto "Error" o icono de advertencia). Los contadores locales
  permanecen intactos.
- **FA-03 — Sin carpeta de Google Drive configurada:** El dashboard muestra el
  estado `DashboardNoFolder` existente (pantalla completa de aviso). En este
  caso las cards de FacturaDirecta NO se muestran, ya que no se llega a
  renderizar la sección "Resumen del día".

### Estados especiales / excepciones

- **Estado loading:** Mientras se cargan los contadores de FacturaDirecta, las
  dos cards nuevas pueden mostrar un indicador de carga (shimmer, spinner, o
  "—"). Los 4 contadores locales se muestran normalmente si ya están
  disponibles.
- **Estado error FD:** Las cards muestran un texto/icono de error. No bloquean
  el dashboard.
- **Estado sin configurar FD:** Las cards muestran un aviso informativo ("Sin
  configurar").
- **Estado vacío FD:** Si la API devuelve listas vacías de albaranes/facturas,
  las cards muestran "0" como valor. Esto es un estado válido.

## 8) Edge cases

- **EC-01:** La API de FacturaDirecta devuelve listas vacías o ningún
  albarán/factura con fecha de hoy → las cards muestran "0".
- **EC-02:** Configuración de FacturaDirecta parcial (companyId existe pero
  apiToken no, o viceversa) → tratarlo como "sin configurar".
- **EC-03:** Las credenciales de FacturaDirecta son inválidas (401/403) → las
  cards muestran estado de error; los contadores locales no se afectan.
- **EC-04:** Timeout en la llamada a FacturaDirecta → las cards muestran estado
  de error; el resto del dashboard permanece funcional.
- **EC-05:** El usuario navega rápidamente fuera del home y vuelve antes de que
  se complete la llamada a FacturaDirecta → la llamada anterior se cancela o se
  ignora; se lanza una nueva carga al volver.
- **EC-06:** El dashboard local falla (DashboardError) → las cards de FD no se
  muestran porque la vista de error es pantalla completa.

## 9) Impacto funcional

- **Módulos afectados:**
  - **Home / Dashboard:** Se amplía la sección "Resumen del día" con 2 cards
    adicionales. El `DashboardCubit`/estado necesitará gestionar datos de
    FacturaDirecta (o se crea un cubit separado para estos contadores).
  - **Navegación (SideMenuCubit):** Se usa para navegar al pulsar las cards
    (cambiar `selectedIndex` a 6 o 7).
  - **Settings (solo lectura):** Se consulta la configuración de FacturaDirecta
    para saber si está disponible.
- **Impacto en usuario:** El usuario gana visibilidad inmediata de sus datos de
  FacturaDirecta desde el dashboard, sin navegar a secciones individuales.
- **Impacto en experiencia de usuario:** La sección "Resumen del día" crece de 4
  a 6 cards. Las nuevas cards son interactivas (pulsables), a diferencia de las
  existentes. Debe evaluarse si el grid se mantiene legible con 6 elementos.

## 10) Suposiciones

- **S-01:** Los contadores reflejan el número de albaranes y facturas **del día
  actual** (filtrados por fecha = hoy sobre los datos devueltos por la API).
- **S-02:** La carga de datos de FacturaDirecta para los contadores se realiza
  cada vez que se muestra el dashboard (misma política que los contadores
  locales), sin caché.
- **S-03:** Las cards de FD utilizan el mismo widget `StatCard` existente (o una
  variante interactiva del mismo) para mantener la coherencia visual.
- **S-04:** La navegación al pulsar una card se implementa cambiando el
  `selectedIndex` del `SideMenuCubit`, replicando el comportamiento de pulsar un
  ítem del menú lateral.
- **S-05:** No se necesita un endpoint de conteo dedicado; se reutilizan los
  endpoints de listado existentes (`GET /{companyId}/deliveryNotes` y
  `GET /{companyId}/invoices`), se filtran por fecha = hoy y se cuenta el número
  de elementos resultantes.

## 11) Preguntas abiertas

- ~~**PA-01:** ¿El contador debe reflejar el total histórico de
  albaranes/facturas o solo los del día/mes actual?~~ — **Resuelto:** Solo los
  del día actual.
- ~~**PA-02:** ¿Las cards existentes deben ser también pulsables (para navegar a
  secciones relacionadas) o solo las nuevas?~~ — **Resuelto:** Solo las nuevas
  por ahora.

No quedan preguntas abiertas.

## 12) Notas para análisis técnico

- La home page actual tiene un `DashboardCubit` que gestiona un `DashboardStats`
  con `DaySummary`. Los contadores de FD son independientes de estos datos
  locales; se recomienda un cubit o estado separado para evitar que un fallo en
  FD afecte al dashboard local.
- El widget `StatCard` actual no soporta interacción (onTap). Se necesitará
  envolverlo en un `GestureDetector`/`InkWell` o crear una variante interactiva.
- El `StatCard` actual no tiene un estado de "aviso" o "error". Se necesitará
  una forma de mostrar el texto de aviso ("Sin configurar") en lugar del valor
  numérico, posiblemente con un icono de advertencia.
- Para obtener los contadores, se pueden reutilizar los use cases existentes
  `GetDeliveryNotes` y `GetInvoices` (que ya existen en
  `lib/features/delivery_notes/` y `lib/features/invoices/`) y filtrar por fecha
  = hoy en el cubit/repository, o crear use cases dedicados que apliquen el
  filtro de fecha y devuelvan solo el conteo.
- La navegación al pulsar las cards se puede hacer invocando
  `context.read<SideMenuCubit>().selectItem(6)` para Albaranes y `selectItem(7)`
  para Facturas, siguiendo el patrón ya existente en `_goToSettings()`.
- Se necesitarán nuevas claves i18n para los labels de las cards ("Albaranes",
  "Facturas") y los estados de aviso/error ("Sin configurar", "Error al
  cargar").
- La configuración de FacturaDirecta se puede consultar a través de
  `SettingsRepository.getFacturaDirectaConfig()`.
- **Estado: Listo para análisis técnico**
