# Technical Analysis: Icono de ayuda con diálogo informativo en la tabla de pedidos

- **Fecha:** 2026-05-10
- **Identificador:** orders-table-info-dialog
- **Fuente:** docs/functional-analysis/2026-05-10-orders-table-info-dialog.md
- **Estado:** Ready for implementation

## 1) Resumen técnico

- Reemplazar el `Container` vacío de color `primary` en la celda esquina 2:2 del
  `_buildProductHeader()` por un `IconButton` con icono `Icons.info_outline`.
- Extraer el diálogo informativo a un widget dedicado o método privado dentro de
  `OrdersTable`, usando `ListTile` sobre `ListView` dentro de un `AlertDialog`
  con `ConstrainedBox`.
- Añadir 26 claves i18n al archivo ARB (1 título del diálogo, 1 botón cerrar, 12
  títulos de acción, 12 descripciones de acción).
- Principales áreas impactadas: `orders_table.dart` (UI), `app_es.arb` (i18n).
- Riesgo general estimado: **bajo** — cambio puramente visual/informativo sin
  lógica de negocio ni modificación de datos.

## 2) Contexto técnico observado

### Arquitectura

- Clean Architecture feature-first con BLoC.
- Feature `orders_today` con capas `data/`, `domain/`, `presentation/`.
- Widget `OrdersTable` (~1400 líneas) es un `StatefulWidget` que gestiona la
  tabla completa: headers congelados, scroll sincronizado, edición de celdas,
  menús contextuales, flags, presencia multiusuario.

### Módulos relevantes

- `OrdersTable` en
  `lib/features/orders_today/presentation/widgets/orders_table.dart`.
- Archivo ARB: `lib/app/localization/l10n/app_es.arb` (i18n centralizado).
- Generación de localización: `AppLocalizations` (gen-l10n).

### Patrones existentes

- Los diálogos existentes en `OrdersTable` usan `showDialog<T>` con
  `AlertDialog` estándar de Material 3 (ver `_showDeleteConfirmation`,
  `_showResetConfirmation`).
- Los textos usan `AppLocalizations.of(context)!` (alias `l10n`).
- Los colores/tipografía vienen de campos cacheados: `_colorScheme`,
  `_textTheme`, `_customColors`.
- La celda esquina 2:2 actual es un
  `SizedBox(width: _dataColWidth) > Container(color: _colorScheme.primary)`,
  visible solo cuando `widget.onAddClient != null` (línea ~658).

### Restricciones

- Los valores de colores y tipografía no deben hardcodearse; deben obtenerse del
  tema.
- Los textos visibles al usuario deben ir en el archivo ARB.
- El widget ya es extenso (~1400 líneas); el diálogo debe ser conciso o
  extraerse a un método privado.

## 3) Objetivo técnico

- **Qué debe cambiar:** La celda esquina vacía 2:2 pasa de ser un contenedor
  inerte a ser un botón interactivo con icono de info.
- **Qué resultado técnico se persigue:** Al pulsar se muestra un `AlertDialog`
  scrollable con 12 entradas tipo `ListTile` (icono + título negrita + subtítulo
  descriptivo).
- **Limitaciones:** No añadir dependencias externas. No refactorizar la
  estructura del widget más allá de lo necesario. No alterar el layout ni tamaño
  de la celda.

## 4) Diseño técnico de la solución

### Enfoque propuesto

Modificar la celda esquina 2:2 dentro de `_buildProductHeader()` para incluir un
`InkWell`/`IconButton` con `Icons.info_outline`. Al pulsarlo, invocar un nuevo
método privado `_showInfoDialog()` que construye y muestra el diálogo.

### Componentes / módulos / servicios afectados

| Componente                          | Tipo de cambio                                     |
| ----------------------------------- | -------------------------------------------------- |
| `OrdersTable._buildProductHeader()` | Reemplazar `Container` vacío por `InkWell` + icono |
| `OrdersTable._showInfoDialog()`     | Nuevo método privado                               |
| `app_es.arb`                        | Nuevas claves i18n                                 |
| `AppLocalizations` (generado)       | Se regenera automáticamente con `flutter gen-l10n` |

### Contratos e interfaces

No se alteran contratos públicos. `OrdersTable` no expone nuevos callbacks ni
parámetros. El diálogo es autocontenido.

### Flujo de datos o de control

1. Usuario pulsa icono info en celda 2:2.
2. `InkWell.onTap` → `_showInfoDialog()`.
3. `_showInfoDialog()` → `showDialog()` con `AlertDialog`.
4. `AlertDialog.content` contiene un `ConstrainedBox(maxWidth: 480)` con
   `ListView` de 12 `ListTile`.
5. `AlertDialog.actions` contiene un botón "Entendido" que cierra con
   `Navigator.of(context).pop()`.
6. `barrierDismissible: true` por defecto.

### Estructura del diálogo

```
AlertDialog
├── icon: Icons.help_outline (primary)
├── title: Text(l10n.ordersTodayInfoDialogTitle)
├── content: ConstrainedBox(maxWidth: 480, maxHeight: 0.7 * screenHeight)
│   └── ListView
│       ├── ListTile(icon: person_add, title: "Añadir cliente", subtitle: "...")
│       ├── ListTile(icon: add_box, title: "Añadir producto", subtitle: "...")
│       ├── ListTile(icon: inventory, title: "Modificar stock", subtitle: "...")
│       ├── ListTile(icon: lock_outline, title: "Stock estricto", subtitle: "...")
│       ├── ListTile(icon: grid_on, title: "Asignar cantidad", subtitle: "...")
│       ├── ListTile(icon: bookmark_outline, title: "Compensaciones", subtitle: "...")
│       ├── ListTile(icon: bookmark_added, title: "Reservas", subtitle: "...")
│       ├── ListTile(icon: person_remove, title: "Quitar cliente", subtitle: "...")
│       ├── ListTile(icon: delete_outline, title: "Quitar producto", subtitle: "...")
│       ├── ListTile(icon: restart_alt, title: "Restablecer pedido", subtitle: "...")
│       ├── ListTile(icon: receipt_long, title: "Hoja de pedido", subtitle: "...")
│       └── ListTile(icon: description, title: "Factura provisional", subtitle: "...")
└── actions: [FilledButton("Entendido")]
```

### Gestión de errores y validaciones

No aplica. El diálogo es estático. No hay operaciones que puedan fallar.

### Consideraciones de compatibilidad o migración

Ninguna. Es un cambio aditivo sin breaking changes.

## 5) Impacto por artefactos

### Artefactos a crear

Ningún archivo nuevo. Todo se integra en artefactos existentes.

### Artefactos a modificar

| Artefacto                                                          | Cambio esperado                                                                                                   |
| ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| `lib/features/orders_today/presentation/widgets/orders_table.dart` | Reemplazar `Container` vacío en celda 2:2 por `Material` + `InkWell` + `Icon`. Añadir método `_showInfoDialog()`. |
| `lib/app/localization/l10n/app_es.arb`                             | Añadir ~26 claves: título del diálogo, botón cerrar, 12 títulos de acción, 12 descripciones.                      |

### Artefactos a retirar o reemplazar

Ninguno.

## 6) Estrategia de implementación

### Paso 1: Añadir claves i18n al archivo ARB

- Añadir las 26 claves nuevas con prefijo `ordersTodayInfo*` en `app_es.arb`.
- Ejecutar `flutter gen-l10n` para regenerar `AppLocalizations`.

### Paso 2: Implementar `_showInfoDialog()` en `OrdersTable`

- Crear método privado en `_OrdersTableState` junto a los otros métodos de
  diálogo (`_showDeleteConfirmation`, `_showResetConfirmation`).
- Usar `showDialog` con `AlertDialog`, icono, título y contenido scrollable.
- El contenido es un `ListView` con `shrinkWrap: true` dentro de un
  `ConstrainedBox` para limitar ancho y alto.
- Cada entrada es un `ListTile` con `leading` (icono en `primary`), `title`
  (texto en negrita) y `subtitle` (descripción).

### Paso 3: Reemplazar la celda esquina 2:2

- En `_buildProductHeader()`, sustituir:
  ```dart
  SizedBox(
    width: _dataColWidth,
    child: Container(color: _colorScheme.primary),
  )
  ```
  por:
  ```dart
  SizedBox(
    width: _dataColWidth,
    child: Material(
      color: _colorScheme.primary,
      child: InkWell(
        onTap: _showInfoDialog,
        child: Center(
          child: Icon(
            Icons.info_outline,
            size: 20,
            color: _colorScheme.onPrimary,
          ),
        ),
      ),
    ),
  )
  ```

### Orden recomendado

1. ARB → 2. `_showInfoDialog()` → 3. Celda 2:2

### Dependencias entre pasos

- Paso 2 depende de Paso 1 (necesita las claves i18n generadas).
- Paso 3 depende de Paso 2 (referencia al método `_showInfoDialog`).

### Puntos delicados

- La celda esquina mide `_dataColWidth` × `_dataColWidth` (48×48). El icono debe
  caber bien (size 20 con padding del InkWell splash es suficiente).
- El `ListView` dentro de `AlertDialog.content` requiere `shrinkWrap: true` para
  evitar errores de layout por constraints infinitos, o envolverse en un
  `SizedBox` con dimensiones acotadas.
- Usar `MediaQuery.sizeOf(context).height * 0.7` como `maxHeight` del
  `ConstrainedBox` para garantizar scrollabilidad en pantallas pequeñas sin
  ocupar toda la pantalla en las grandes.

## 7) Estrategia de validación

### Verificación automática

- `flutter gen-l10n` debe completarse sin errores.
- `flutter analyze` sin errores ni warnings nuevos.
- `flutter test` existentes deben seguir pasando (el cambio es aditivo UI-only).

### Verificación manual

- Abrir la pantalla de pedidos del día con datos.
- Verificar que el icono de info aparece en la celda esquina (2:2).
- Pulsar el icono y comprobar que el diálogo se abre.
- Verificar que las 12 acciones aparecen con icono, título en negrita y
  descripción.
- Verificar scroll cuando el contenido excede la altura disponible (simular
  pantalla pequeña o reducir ventana).
- Cerrar el diálogo con el botón "Entendido".
- Cerrar el diálogo pulsando fuera.
- Verificar que el icono NO aparece cuando `onAddClient` es `null`.
- Comprobar coherencia visual: colores del tema, tipografía, espaciado.

### Escenarios de edge cases

- Pantalla muy pequeña (ej. ventana de 400px de alto) → el diálogo debe
  scrollear.
- Tema oscuro → verificar contraste y legibilidad.

## 8) Riesgos, impacto y rollback

### Riesgos identificados

- **Bajo:** El widget ya tiene ~1400 líneas. Añadir un método más es incremental
  pero acumulativo.
- **Bajo:** Posible overflow visual si los textos i18n son muy largos en algún
  idioma futuro.

### Impacto potencial

- Solo afecta a la UI de la tabla de pedidos.
- No modifica lógica de negocio, persistencia ni flujos de datos.

### Mitigación

- Usar `ConstrainedBox` con `maxHeight` relativo para prevenir overflow.
- `ListTile.subtitle` soporta multilínea por defecto.

### Plan de rollback

- Revertir los 3 cambios (celda, método, ARB). Son cambios puramente aditivos en
  2 archivos.

## 9) Suposiciones

- Solo se gestiona el idioma español (`app_es.arb`). Si hubiera otros ARB,
  necesitarían sus traducciones.
- Los textos descriptivos de cada acción se basarán en la mecánica observada en
  el código:
  - Añadir cliente/producto: botones azules en el header.
  - Quitar cliente/producto: clic derecho sobre nombre del cliente/producto →
    menú contextual.
  - Editar celda: clic sobre celda de cliente o stock.
  - Flags (compensación/reserva): clic derecho en celda de cliente → menú
    contextual.
  - Stock estricto: clic derecho en celda de stock → menú contextual.
  - Restablecer pedido: clic derecho sobre nombre del cliente → menú contextual.
  - Generar hoja/factura: clic derecho sobre nombre del cliente → menú
    contextual (actualmente disabled).
- El `AlertDialog` estándar de Material 3 es suficiente sin necesidad de un
  widget custom.

## 10) Preguntas abiertas

- ~~Los ítems de "Generar hoja de pedido" y "Generar factura provisional" están
  actualmente deshabilitados (`enabled: false`) en el menú contextual. ¿El texto
  de ayuda debe indicar que están "próximamente" o simplemente describir la
  acción prevista?~~ → **Resuelta:** Describir cómo realizarlas y para qué
  sirven:
  - **Generar hoja de pedido:** describir la mecánica (clic derecho sobre nombre
    del cliente) y su propósito: permite a los trabajadores ver la cantidad de
    productos que ha solicitado el cliente.
  - **Generar factura provisional:** describir la mecánica (clic derecho sobre
    nombre del cliente) y su propósito: genera la factura en estado provisional
    en Factura Directa.

## 11) Notas para implementación

- Respetar el patrón existente de diálogos en el widget (ver
  `_showDeleteConfirmation` como referencia de estilo).
- No refactorizar el widget más allá de lo estrictamente necesario.
- Las claves ARB deben seguir la convención de prefijo `ordersTodayInfo` para
  agruparlas.
- Usar `_colorScheme.primary` para los iconos del `ListTile.leading` (coherencia
  con iconos del menú contextual existente).
- El título en negrita de cada `ListTile` se logra con `titleTextStyle` o un
  `Text` con `fontWeight: FontWeight.bold`.
- Mantener la condición de visibilidad `widget.onAddClient != null` ya existente
  para la celda esquina.
- **Estado: Listo para implementación**
