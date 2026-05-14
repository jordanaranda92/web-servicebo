# Technical Analysis: Side Menu responsivo en pantallas pequeñas

- **Fecha:** 2026-05-12
- **Identificador:** side-menu-mobile-responsive
- **Fuente:** docs/functional-analysis/2026-05-12-side-menu-mobile-responsive.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Introducir un comportamiento responsivo en `SideMenuShell` que alterne entre
  layout fijo (desktop) y `Drawer` overlay (mobile) según un breakpoint
  configurable de 768 px.
- Principales artefactos impactados: `SideMenuShell`, `SideMenu`, `AppSideMenu`
  (constantes).
- El `SideMenuCubit` y `SideMenuState` **no requieren cambios**: el estado del
  drawer lo gestiona internamente el `Scaffold` de Flutter.
- Riesgo general estimado: **bajo**. Los cambios están contenidos en 3 archivos,
  no hay nueva dependencia, y el comportamiento desktop permanece intacto.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC/Cubit, GetIt para DI, GoRouter para
  navegación.
- El `SideMenuShell` actúa como `ShellRoute` builder y envuelve todas las
  páginas autenticadas.

### Módulos relevantes

- `lib/features/home/presentation/pages/side_menu_shell.dart` — layout shell con
  `Scaffold > Row(SideMenu, Expanded(child))`.
- `lib/features/home/presentation/widgets/side_menu.dart` — widget del menú con
  estados expandido/colapsado, ítems, header, toggle button.
- `lib/features/home/presentation/bloc/side_menu_cubit.dart` — gestiona
  `isExpanded` con persistencia en `SharedPreferences`.
- `lib/features/home/presentation/bloc/side_menu_state.dart` — estado con único
  campo `isExpanded`.
- `lib/app/theme/theme_constants.dart` — constantes `AppSideMenu`
  (`expandedWidth`, `collapsedWidth`, `animationDuration`).
- `lib/app/router/router.dart` — `ShellRoute` que instancia
  `SideMenuShell(child: child)`.
- `lib/core/services/navigation_guard.dart` — guard de navegación con
  `shouldBlock` y `onDiscard`.

### Restricciones

- No se soporta gesto swipe para abrir/cerrar drawer.
- No se introduce bottom navigation ni AppBar global.
- El `SideMenu` mantiene su apariencia visual actual (rounded corners, sombra,
  colores del tema).
- `NavigationGuard` debe funcionar igual en ambos modos.

### Dependencias

- No se requieren nuevas dependencias. Se usa `Scaffold.drawer` nativo de
  Flutter.

## 3) Objetivo técnico

- **Qué debe cambiar:** El `SideMenuShell` debe detectar el ancho de pantalla y
  renderizar el menú de forma diferente según se supere o no el breakpoint.
- **Resultado técnico:** En pantallas ≤ 768 px el menú es un `Drawer` overlay
  con scrim, botón hamburguesa en esquina superior izquierda; en pantallas > 768
  px el layout actual (`Row` con `SideMenu` fijo) permanece intacto.
- **Limitaciones:** El breakpoint debe ser una constante configurable en
  `AppSideMenu`. El drawer siempre inicia cerrado (no se persiste su estado).

## 4) Diseño técnico de la solución

### Enfoque propuesto

Usar el `Scaffold.drawer` nativo de Flutter para el modo mobile. Esto
proporciona:

- Animación de slide-in/out estándar.
- Scrim automático con cierre al tocar.
- Control programático via `Scaffold.of(context).openDrawer()` /
  `closeDrawer()`.
- Sin necesidad de gestionar estado adicional en el cubit (el `Scaffold`
  gestiona el drawer internamente).

Se desactiva `drawerEnableOpenDragGesture` para cumplir con el requisito de no
soportar swipe.

La detección del breakpoint se hace con `MediaQuery.sizeOf(context).width`
dentro del método `build` de `SideMenuShell`, lo que garantiza reactividad ante
redimensionamiento de ventana.

### Componentes / módulos / servicios afectados

| Componente                      | Rol                                                                      |
| ------------------------------- | ------------------------------------------------------------------------ |
| `AppSideMenu` (theme_constants) | Nueva constante `mobileBreakpoint`                                       |
| `SideMenu` (widget)             | Nuevo parámetro `showToggleButton` para ocultar el toggle en modo drawer |
| `SideMenuShell` (page)          | Lógica de bifurcación responsive: desktop layout vs mobile drawer        |

### Contratos e interfaces

**`SideMenu`** — Se añade un parámetro opcional:

```
showToggleButton: bool (default true)
```

Cuando es `false`, el `_ToggleButton` y su divider superior no se renderizan.

**`SideMenuShell`** — El contrato público no cambia
(`const SideMenuShell({required this.child})`). Los cambios son internos al
`build`.

### Flujo de datos o de control

**Modo desktop (ancho > 768 px):**

```
SideMenuShell.build()
  → MediaQuery: ancho > 768
  → Scaffold(body: Row(SideMenu fijo, Expanded(child)))
  → Comportamiento idéntico al actual
```

**Modo mobile (ancho ≤ 768 px):**

```
SideMenuShell.build()
  → MediaQuery: ancho ≤ 768
  → Scaffold(
      drawer: Drawer(SideMenu expandido, sin toggle),
      drawerEnableOpenDragGesture: false,
      body: Stack(
        child,                       ← contenido a ancho completo
        Positioned(hamburger button) ← esquina superior izquierda
      )
    )
```

**Flujo de navegación en modo mobile:**

```
1. Usuario pulsa hamburger button
2. Scaffold.of(context).openDrawer()
3. Drawer se abre con SideMenu expandido
4. Usuario pulsa ítem del menú
5. onItemSelected:
   a. Si index == selectedIndex → closeDrawer(), return
   b. Si NavigationGuard.shouldBlock → showUnsavedDialog()
      - "Quedarse" → nada (drawer permanece abierto)
      - "Descartar" → guard.clear(), closeDrawer(), context.go(target)
   c. Si no bloquea → closeDrawer(), context.go(target)
6. Usuario pulsa scrim → Scaffold cierra drawer automáticamente
```

### Gestión de errores y validaciones

- Si `MediaQuery` no está disponible (no debería ocurrir dentro de
  `MaterialApp`), el layout defaultea a desktop (valor ancho > breakpoint como
  fallback seguro).
- El `NavigationGuard` mantiene su flujo actual sin modificaciones.
- Si el drawer está abierto y se cruza el breakpoint por redimensionamiento, el
  rebuild del `Scaffold` con `drawer: null` cierra el drawer automáticamente.

### Consideraciones de compatibilidad o migración

- **Ninguna migración requerida.** Los cambios son aditivos y retrocompatibles.
- El parámetro `showToggleButton` tiene valor por defecto `true`, por lo que no
  rompe usos existentes de `SideMenu`.
- El estado persistido `isExpanded` en `SharedPreferences` sigue siendo
  relevante solo para desktop; en mobile se ignora.

## 5) Impacto por artefactos

### Artefactos a crear

Ninguno.

### Artefactos a modificar

| Artefacto                                                   | Cambio esperado                                                                                                                                                                   |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/app/theme/theme_constants.dart`                        | Añadir `static const double mobileBreakpoint = 768;` a la clase `AppSideMenu`                                                                                                     |
| `lib/features/home/presentation/widgets/side_menu.dart`     | Añadir parámetro `showToggleButton` (default `true`). Condicionar renderizado del divider inferior y `_ToggleButton`                                                              |
| `lib/features/home/presentation/pages/side_menu_shell.dart` | Refactorizar `build()` para bifurcar entre layout desktop (actual) y layout mobile (drawer + hamburger button). Extraer lógica de `onItemSelected` para reutilizar en ambos modos |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Pasos

1. **Añadir constante `mobileBreakpoint`** a `AppSideMenu` en
   `theme_constants.dart`.
2. **Añadir parámetro `showToggleButton`** al widget `SideMenu` y condicionar el
   renderizado del toggle button y su divider.
3. **Refactorizar `SideMenuShell.build()`:**
   - Obtener `screenWidth` de `MediaQuery.sizeOf(context).width`.
   - Definir `isMobile = screenWidth <= AppSideMenu.mobileBreakpoint`.
   - Si `isMobile`: configurar `Scaffold` con `drawer` (wrapping `SideMenu`
     expandido + sin toggle, dentro de un `Drawer` con fondo transparente y
     elevation 0), `drawerEnableOpenDragGesture: false`, body como `Stack` con
     `child` + botón hamburguesa posicionado top-left.
   - Si `!isMobile`: mantener `Scaffold` con body `Row` actual (sin `drawer`).
   - Extraer la lógica de `onItemSelected` a un método privado para reutilizar,
     añadiendo cierre de drawer en modo mobile.
4. **Validar** con tests manuales en diferentes anchos de pantalla.

### Orden recomendado

1 → 2 → 3 (secuencial, cada paso depende del anterior).

### Dependencias entre pasos

- Paso 3 depende de paso 1 (usa `AppSideMenu.mobileBreakpoint`).
- Paso 3 depende de paso 2 (usa `showToggleButton: false` en modo drawer).

### Puntos delicados

- **Contexto del Scaffold para `openDrawer()`**: El botón hamburguesa debe usar
  un `context` que sea descendiente del `Scaffold`. Dado que está dentro del
  `body`, el contexto del `Builder`/`BlocBuilder` es válido. Verificar que no se
  usa el `context` del propio `SideMenuShell.build` sino uno interno.
- **Drawer abierto durante redimensionamiento**: Si el drawer está visible y el
  usuario redimensiona por encima del breakpoint, el `Scaffold` se reconstruye
  con `drawer: null`. Flutter maneja esto cerrando el drawer automáticamente,
  pero conviene verificar que no produce errores.
- **Padding del hamburger button**: Debe respetar
  `MediaQuery.of(context).padding.top` (safe area / notch) para no quedar tapado
  por la barra de estado.
- **`buildWhen` del `BlocBuilder`**: En modo mobile, el `BlocBuilder` ya no
  necesita reconstruir para `isExpanded` (el drawer siempre es expandido). No
  obstante, dado que `buildWhen` solo filtra reconstrucciones innecesarias, no
  es un problema funcional; simplemente no habrá cambios de `isExpanded` que
  triggereen rebuild en modo mobile.

## 7) Estrategia de validación

### Verificación automática

- Los tests existentes de `SideMenuCubit` deben pasar sin cambios (el cubit no
  se modifica).
- Se recomienda añadir un test de widget para `SideMenuShell` que valide:
  - Con `MediaQuery` de ancho 600 px: no renderiza `SideMenu` en el `Row`, sí
    renderiza botón hamburguesa.
  - Con `MediaQuery` de ancho 1024 px: renderiza `SideMenu` en el `Row`, no
    renderiza botón hamburguesa.

### Verificación manual

- Probar en Chrome (web) redimensionando la ventana por encima y debajo de 768
  px.
- Probar abrir drawer, navegar, cerrar con scrim, y diálogo de unsaved changes
  en mobile.
- Probar deep link directo en pantalla pequeña: verificar que el drawer está
  cerrado y el ítem activo es correcto al abrirlo.

### Escenarios clave

| Escenario                                       | Esperado                                                   |
| ----------------------------------------------- | ---------------------------------------------------------- |
| Carga en ≤768 px                                | Contenido 100% ancho, hamburger visible, sin SideMenu fijo |
| Hamburger → abrir drawer                        | SideMenu expandido con scrim                               |
| Seleccionar ítem en drawer                      | Drawer cierra, navega a página                             |
| Tocar scrim                                     | Drawer cierra, sin navegación                              |
| Redimensionar >768 → ≤768                       | SideMenu desaparece, hamburger aparece                     |
| Redimensionar ≤768 → >768 (drawer abierto)      | Drawer se cierra, SideMenu fijo aparece                    |
| NavigationGuard con cambios pendientes (mobile) | Diálogo se muestra correctamente                           |

### Tipos de pruebas recomendables

- **Unitarios**: Ya cubiertos por `side_menu_cubit_test.dart` (sin cambios).
- **Widget tests**: Para `SideMenuShell` y `SideMenu` (nuevo parámetro
  `showToggleButton`).

## 8) Riesgos, impacto y rollback

### Riesgos identificados

| Riesgo                                                       | Probabilidad | Impacto |
| ------------------------------------------------------------ | ------------ | ------- |
| Drawer abierto + redimensionamiento causa excepción          | Baja         | Medio   |
| Hamburger button queda oculto por contenido de alguna página | Baja         | Medio   |
| `Scaffold.of(context)` falla por contexto incorrecto         | Baja         | Alto    |

### Impacto potencial

- Solo afecta al módulo `home` (shell de navegación). No impacta la lógica de
  negocio de ninguna feature.
- Si falla, solo afecta la navegación en pantallas pequeñas; desktop no se ve
  afectado.

### Mitigación

- Verificar con `Builder` widget que el contexto usado para `openDrawer()` es
  hijo del `Scaffold`.
- Usar `SafeArea` o `MediaQuery.padding` para posicionar correctamente el
  hamburger button.
- Probar redimensionamiento durante QA manual.

### Plan de rollback

- Revertir los 3 archivos modificados a su estado anterior. No hay migración de
  datos, esquema ni estado persistido nuevo.

## 9) Suposiciones

- El `Scaffold.drawer` de Flutter cierra automáticamente el drawer cuando se
  reconstruye con `drawer: null` durante un cambio de breakpoint.
- Ninguna página hija tiene contenido que se superponga a la posición del botón
  hamburguesa (top-left). Si alguna lo tiene, se deberá gestionar con z-index o
  padding en esa página.
- El valor 768 px es adecuado. Si en el futuro se quiere otro valor, basta con
  cambiar `AppSideMenu.mobileBreakpoint`.

## 10) Preguntas abiertas

- Ninguna. Todas las preguntas funcionales fueron resueltas.

## 11) Notas para implementación

- **No modificar** `SideMenuCubit` ni `SideMenuState`. El drawer lo gestiona
  `Scaffold` internamente.
- **No persistir** el estado del drawer. En mobile siempre inicia cerrado.
- **Reutilizar** el widget `SideMenu` existente, pasándole `isExpanded: true` y
  `showToggleButton: false` en modo drawer.
- El `Drawer` wrapper debe tener `backgroundColor: Colors.transparent` y
  `elevation: 0` para que la estética propia del `SideMenu` (rounded corners,
  shadow, surface color) se preserve.
- Usar `AppSideMenu.expandedWidth` + padding para calcular el `width` del
  `Drawer`.
- En el callback `onItemSelected` en modo mobile, llamar
  `Scaffold.of(context).closeDrawer()` **antes** de `context.go(targetPath)`
  para asegurar que el drawer se cierra en la transición.
- En el diálogo de unsaved changes (modo mobile), si el usuario elige "Descartar
  y salir", cerrar el drawer antes de navegar.
- Desactivar swipe con `drawerEnableOpenDragGesture: false` en el `Scaffold`.
- **Estado: Listo para implementación**
