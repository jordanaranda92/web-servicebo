# Technical Analysis: Rediseño de vista detalle de cliente en modo mobile

- **Fecha:** 2026-05-12
- **Identificador:** client-detail-mobile-redesign
- **Fuente:**
  docs/functional-analysis/2026-05-12-client-detail-mobile-redesign.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Modificar `SideMenuShell._buildMobileLayout` para que sea route-aware: cuando
  la ruta activa sea `/clients/:id/detail`, sustituir el AppBar genérico
  (hamburguesa + título de sección) por uno específico (back arrow + "Detalle de
  cliente" + icono editar).
- Modificar `ClientDetailPage.build` para bifurcar el layout según breakpoint:
  en mobile ocultar el `PageHeader` actual y añadir la sección "Datos del
  cliente" antes de "Datos de Factura Directa"; en desktop mantener el layout
  actual sin cambios.
- Añadir 2 claves i18n nuevas al archivo ARB.
- **Áreas impactadas:** `SideMenuShell`, `ClientDetailPage`, archivo ARB.
- **Riesgo general:** bajo — cambios localizados y reversibles, sin alterar
  modelo de datos ni lógica de negocio.

## 2) Contexto técnico observado

### Arquitectura y patrones

- Clean Architecture feature-first con BLoC/Cubit, GetIt, GoRouter.
- `ShellRoute` único envuelve todas las rutas autenticadas con `SideMenuShell`
  como layout shell.
- `SideMenuShell` detecta mobile (≤ 768 px via `AppSideMenu.mobileBreakpoint`) y
  renderiza un `Scaffold` con `AppBar` + `Drawer`, o un `Row` con sidebar fija
  en desktop.
- El título del AppBar mobile se resuelve por índice de menú
  (`_mobileTitleForIndex`), lo que no distingue subrutas como detalle/edición.

### Módulos relevantes

| Archivo                                                           | Rol                                                           |
| ----------------------------------------------------------------- | ------------------------------------------------------------- |
| `lib/features/home/presentation/pages/side_menu_shell.dart`       | Shell layout, AppBar mobile, Drawer                           |
| `lib/features/clients/presentation/pages/client_detail_page.dart` | Vista detalle con `PageHeader`, sección FD y métodos de envío |
| `lib/core/presentation/widgets/page_header.dart`                  | Widget reutilizable: fila con título, acciones y divider      |
| `lib/app/router/router.dart`                                      | Definición de rutas GoRouter                                  |
| `lib/app/localization/l10n/app_es.arb`                            | Archivo de traducciones                                       |
| `lib/features/clients/domain/entities/client.dart`                | Entidad `Client` con `name`, `categoryName`, `categoryColor`  |

### Restricciones

- No se deben modificar rutas, modelo de datos ni lógica de negocio.
- La vista desktop no debe cambiar.
- `ClientEditPage` ya soporta recibir `client: null` y resuelve por ID — no hay
  riesgo al navegar desde el AppBar sin `extra`.

## 3) Objetivo técnico

- **Qué debe cambiar:** el rendering de `SideMenuShell` en mobile para la ruta
  de detalle de cliente, y el body de `ClientDetailPage` en mobile.
- **Resultado:** en pantallas ≤ 768 px, el detalle de cliente muestra un AppBar
  con navegación/acciones propias y una sección "Datos del cliente" adicional en
  el body.
- **Limitaciones:** no alterar el layout desktop, no modificar la entidad
  `Client`, no alterar la configuración de rutas.

## 4) Diseño técnico de la solución

### Enfoque propuesto

**A) `SideMenuShell` route-aware (AppBar mobile)**

En `_buildMobileLayout`, antes de construir el `Scaffold`, detectar si la ruta
actual es `/clients/:id/detail` mediante regex sobre `location`:

```
final clientDetailMatch = RegExp(r'/clients/([^/]+)/detail').firstMatch(location);
final isClientDetail = clientDetailMatch != null;
```

Si `isClientDetail == true`:

| Propiedad AppBar | Valor                                                                           |
| ---------------- | ------------------------------------------------------------------------------- |
| `leading`        | `IconButton(Icons.arrow_back_rounded)` → `context.go(AppRoutes.clients)`        |
| `title`          | `Text(l10n.clientsDetailTitle)`                                                 |
| `actions`        | `[IconButton(Icons.edit_outlined)]` → `context.push('/clients/$clientId/edit')` |

Adicionalmente:

- `drawer`: `null` (no se necesita menú lateral en detalle).
- `drawerEnableOpenDragGesture`: `false`.

Si `isClientDetail == false`: comportamiento actual sin cambios.

**B) `ClientDetailPage` layout condicional (body)**

En el método `build`, detectar mobile mediante
`MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint`.

- **Mobile (`isMobile == true`):**
  - Omitir `PageHeader` (el AppBar del shell ya provee back arrow, título y
    edit).
  - Insertar sección "Datos del cliente" (card con `_FdDataRow` para Nombre y
    fila custom para Categoría badge) antes de la sección "Datos de Factura
    Directa".
  - El contenido scrollable ocupa todo el espacio del body.

- **Desktop (`isMobile == false`):**
  - Mantener el layout actual sin cambios (`PageHeader` + secciones).

**C) Sección "Datos del cliente"**

Misma estructura visual que la sección FD existente:

- Título `Text(l10n.clientsClientDataSection)` con `titleMedium` bold.
- `Card` con borde y padding.
- Fila Nombre:
  `_FdDataRow(icon: Icons.person_outline, label: l10n.clientsColumnName, value: client.name)`.
- Divider.
- Fila Categoría: fila personalizada con `Icons.label_outline` + label + badge
  con color de fondo (reutilizando la lógica del badge existente con
  `tryParseHex(client.categoryColor)` + `contrastTextColor`). Si no hay
  categoría, mostrar `l10n.clientsCategoryUnspecified` en texto italic.

### Componentes / módulos / servicios afectados

| Componente                         | Tipo de cambio                    |
| ---------------------------------- | --------------------------------- |
| `SideMenuShell._buildMobileLayout` | Lógica condicional por ruta       |
| `ClientDetailPage.build`           | Layout condicional mobile/desktop |
| `app_es.arb`                       | 2 claves nuevas                   |

### Contratos e interfaces

No se modifican contratos, entidades ni interfaces de repositorio/use case.

### Flujo de datos o de control

```
[Mobile] Usuario pulsa cliente en listado
  → GoRouter navega a /clients/:id/detail
  → SideMenuShell detecta ruta detail → AppBar custom (back, título, edit)
  → ClientDetailPage.build detecta isMobile
    → Omite PageHeader
    → Renderiza sección "Datos del cliente" + sección FD + métodos de envío

[Desktop] Sin cambios: SideMenuShell muestra sidebar, ClientDetailPage muestra PageHeader + secciones.
```

### Gestión de errores y validaciones

- **Estado loading (cliente aún no resuelto):** El AppBar del shell ya puede
  mostrar back arrow y título. El botón de editar en `actions` del AppBar puede
  mostrarse siempre ya que la ruta de edición también resuelve el cliente por ID
  si `extra` es null. Alternativamente, se puede ocultar hasta que el cliente se
  resuelva, pero esto requiere comunicación shell-child que añade complejidad
  innecesaria.
- **Estado not found:** El body muestra el estado actual de "no encontrado" con
  botón de volver. El AppBar mobile con back arrow sigue funcional.
- **Sin categoría:** El campo Categoría muestra
  `l10n.clientsCategoryUnspecified` en texto italic, consistente con el patrón
  de `ClientCard`.

### Consideraciones de compatibilidad o migración

- No hay migración de datos.
- Los cambios son puramente de presentación.
- La clave regex para detectar la ruta depende de la estructura de rutas actual
  (`/clients/:id/detail`). Si las rutas cambian en el futuro, la regex deberá
  actualizarse. Esto es aceptable dado que la detección es localizada en un solo
  punto.

## 5) Impacto por artefactos

### Artefactos a crear

Ninguno.

### Artefactos a modificar

| Artefacto                                                         | Cambio esperado                                                                                                                                                        |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/features/home/presentation/pages/side_menu_shell.dart`       | `_buildMobileLayout`: detectar ruta de detalle de cliente y personalizar AppBar (leading, title, actions), ocultar drawer. ~20 líneas.                                 |
| `lib/features/clients/presentation/pages/client_detail_page.dart` | `build`: bifurcar layout mobile/desktop. En mobile: omitir `PageHeader`, añadir sección "Datos del cliente" con Nombre y Categoría (badge) antes de FD. ~50–60 líneas. |
| `lib/app/localization/l10n/app_es.arb`                            | Añadir 2 claves: `clientsDetailTitle`, `clientsClientDataSection`.                                                                                                     |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Paso 1: Añadir claves i18n

- Agregar `clientsDetailTitle` ("Detalle de cliente") y
  `clientsClientDataSection` ("Datos del cliente") en `app_es.arb`.
- Regenerar archivos de localización (`flutter gen-l10n` o build automático).

### Paso 2: Modificar `SideMenuShell._buildMobileLayout`

- Extraer `location` (ya disponible vía `GoRouterState`).
- Detectar ruta de detalle con regex.
- Condicionar `leading`, `title`, `actions` y `drawer` del Scaffold mobile.
- Pasar `location` como parámetro a `_buildMobileLayout` o acceder desde el
  contexto.

### Paso 3: Modificar `ClientDetailPage.build`

- Detectar `isMobile` con `MediaQuery`.
- Bifurcar el return:
  - Desktop: layout actual sin cambios.
  - Mobile: `Expanded > SingleChildScrollView > Column` con sección "Datos del
    cliente" (card con nombre y categoría badge) + sección FD existente +
    métodos de envío.
- Omitir `PageHeader` en mobile.

### Orden recomendado

1. i18n (Paso 1) — sin dependencias.
2. SideMenuShell (Paso 2) — depende de Paso 1 para `l10n.clientsDetailTitle`.
3. ClientDetailPage (Paso 3) — depende de Paso 1 para
   `l10n.clientsClientDataSection`.

Pasos 2 y 3 son independientes entre sí y podrían hacerse en paralelo tras el
Paso 1.

### Dependencias entre pasos

- Paso 2 y 3 dependen de Paso 1 (claves i18n disponibles).
- Paso 2 y 3 son independientes entre sí.

### Puntos delicados

- **Regex de detección de ruta:** debe coincidir exactamente con el patrón
  `/clients/:id/detail`. El ID puede contener caracteres alfanuméricos, guiones,
  etc. La regex `r'/clients/([^/]+)/detail'` es suficientemente robusta.
- **Navegación sin `extra`:** el botón de editar en el AppBar del shell navega a
  `/clients/$clientId/edit` sin pasar el objeto `Client` como `extra`.
  `ClientEditPage` ya soporta esto y resuelve el cliente por ID desde el
  cubit/stream. No hay riesgo funcional.
- **Consistencia responsive:** el cambio de desktop a mobile (y viceversa) al
  redimensionar la ventana debe ser fluido. Ambos layouts usan el mismo estado
  (`_client`, `_fdData`, etc.) y la detección es por `MediaQuery`, lo que
  Flutter reconstruye automáticamente.

## 7) Estrategia de validación

### Verificación automática

- `flutter analyze` — sin errores ni warnings nuevos.
- Tests existentes de `ClientDetailPage` y `SideMenuShell` (si existen) deben
  seguir pasando.

### Verificación manual

- **Escenario 1:** En ventana ≤ 768 px, navegar a detalle de cliente → verificar
  AppBar (back arrow, "Detalle de cliente", icono editar).
- **Escenario 2:** Pulsar back arrow → confirmar navegación a listado
  `/clients`.
- **Escenario 3:** Pulsar icono editar → confirmar navegación a
  `/clients/:id/edit`.
- **Escenario 4:** Verificar sección "Datos del cliente" con Nombre y Categoría
  (badge con color).
- **Escenario 5:** Verificar con cliente sin categoría asignada → "Categoría no
  asignada" en italic.
- **Escenario 6:** En ventana > 768 px, verificar que la vista desktop no ha
  cambiado (PageHeader con nombre, categoría badge, back arrow, botón editar).
- **Escenario 7:** Redimensionar ventana de desktop a mobile y viceversa →
  transición sin errores ni pérdida de datos.
- **Escenario 8:** Deep link a `/clients/:id/detail` en mobile → AppBar
  correcto, back arrow funcional.
- **Escenario 9:** Estado loading/not found en mobile → spinner o mensaje de
  error con AppBar funcional.

### Pruebas recomendables

- Widget test de `ClientDetailPage` verificando que en mobile se renderiza la
  sección "Datos del cliente" y no se renderiza `PageHeader`.
- Widget test verificando que en desktop se renderiza `PageHeader` y no la
  sección "Datos del cliente".

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                                            | Probabilidad | Impacto                                                    |
| --------------------------------------------------------------------------------- | ------------ | ---------------------------------------------------------- |
| La regex de detección de ruta no coincide en algún edge case (e.g., query params) | Baja         | Medio — se mostraría el AppBar genérico                    |
| `ClientEditPage` no maneja bien `extra: null`                                     | Muy baja     | Bajo — ya tiene lógica de resolución por ID                |
| Cambios en `SideMenuShell` afectan otras rutas                                    | Muy baja     | Alto — la condicional es explícita para la ruta de detalle |

### Impacto potencial

- Solo afecta la presentación en mobile de la vista de detalle de cliente.
- No afecta datos, lógica de negocio, ni otras vistas.

### Mitigación

- Condicional explícita con regex específica; el else mantiene el comportamiento
  original intacto.
- Verificación manual de las rutas adyacentes (listado, edición) tras el cambio.

### Plan de rollback

- Revertir los 3 cambios (SideMenuShell, ClientDetailPage, ARB). Son cambios
  aislados sin migración de datos.

## 9) Suposiciones

- El breakpoint mobile es ≤ 768 px (`AppSideMenu.mobileBreakpoint`) y no
  cambiará.
- `ClientEditPage` ya resuelve el cliente por ID cuando no recibe `extra`,
  basado en la lógica observada de `_resolveClient` con patrón widget.client →
  cubit cache → stream.
- El patrón de URI de la ruta de detalle es estable: `/clients/:id/detail`.
- Las claves i18n existentes (`clientsColumnName`, `clientsCategoryUnspecified`)
  son reutilizables para la nueva sección.

## 10) Preguntas abiertas

Ninguna. Todas las decisiones funcionales están resueltas.

## 11) Notas para implementación

- **No modificar** el bloque desktop de `ClientDetailPage` — solo añadir la
  bifurcación mobile.
- **Reutilizar** `_FdDataRow` para el campo Nombre. Para Categoría, crear una
  fila similar pero con un widget badge como valor (reutilizar la lógica de
  badge de `PageHeader` / `ClientCard`).
- **Pasar `location`** a `_buildMobileLayout` como parámetro (ya se calcula en
  `build`), en lugar de recalcularlo.
- No es necesario ocultar el botón de editar del AppBar durante el estado
  loading — la ruta de edición resuelve el cliente de forma autónoma.
- Las claves i18n existentes cubren "Nombre" (`clientsColumnName`), "Categoría"
  (`clientsColumnCategory`) y "Categoría no asignada"
  (`clientsCategoryUnspecified`). Solo se necesitan 2 claves nuevas: título
  AppBar y título sección.
- **Estado: Listo para implementación**
