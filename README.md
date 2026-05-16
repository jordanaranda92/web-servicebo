<p align="center">
  <img src="assets/images/logo-servicebo.png" alt="Servicebo" width="400">
</p>

<p align="center">
  Aplicación de gestión de pedidos diarios para empresas de distribución.<br/>
  Lectura y escritura de archivos Excel, sincronización con FacturaDirecta y Firebase.
</p>

---

## ✨ Características principales

- **Tabla de pedidos del día** — Visualización y edición de pedidos en formato
  tabla dinámica (clientes × productos) con totales automáticos.
- **Gestión de archivos Excel** — Lectura/escritura de archivos `.xlsx` diarios
  desde una carpeta de trabajo local.
- **Dashboard con estadísticas** — Contadores de clientes, productos, unidades y
  comparativas temporales (hoy vs ayer, semana vs semana anterior).
- **Gestión de clientes** — CRUD completo con importación desde FacturaDirecta,
  categorías y métodos de envío.
- **Gestión de productos** — Catálogo de productos con sincronización desde
  fuentes externas.
- **Facturación provisional** — Generación de facturas integrada con
  FacturaDirecta.
- **Exportación PDF y Excel** — Exportación de pedidos en múltiples formatos.
- **Autenticación Firebase** — Login con email/contraseña y persistencia de
  sesión.
- **Cloud Functions** — Proxy autenticado a la API de FacturaDirecta y limpieza
  automática al eliminar usuarios.
- **Plataforma web** — Aplicación desplegada como web app en Firebase Hosting.

## 📋 Requisitos previos

| Herramienta  | Versión mínima            |
| ------------ | ------------------------- |
| Flutter SDK  | ≥ 3.10.8                  |
| Dart SDK     | ≥ 3.10.8                  |
| Node.js      | 22 (para Cloud Functions) |
| Firebase CLI | Última versión            |

> [!NOTE]
> La aplicación se despliega exclusivamente como **web app** en Firebase
> Hosting.

## 🚀 Inicio rápido

```bash
# Clonar el repositorio
git clone <url-del-repositorio>
cd servicebo

# Instalar dependencias Flutter
flutter pub get

# Generar traducciones
flutter gen-l10n

# Ejecutar en entorno dev
flutter run -t lib/main_dev.dart
```

Para las Cloud Functions:

```bash
cd functions
npm install
npm run serve
```

## 🏗️ Arquitectura

El proyecto sigue **Clean Architecture feature-first** con las siguientes capas
por cada feature:

```
lib/
├── app/
│   ├── config/              # Configuración y entornos (dev, pro)
│   ├── di/                  # Inyección de dependencias (GetIt)
│   │   └── modules/         # Un módulo por feature
│   ├── localization/        # i18n (ARB + gen-l10n)
│   ├── router/              # Rutas de navegación (GoRouter)
│   └── theme/               # Tema visual (Material 3)
├── core/
│   ├── error/               # Excepciones y Failures
│   ├── extensions/          # Extensiones de fpdart
│   ├── log/                 # Sistema de logging
│   ├── presentation/        # Widgets compartidos
│   └── usecase/             # Clase base UseCase
├── features/
│   ├── auth/                # 🔐 Autenticación (Firebase Auth)
│   ├── home/                # 📊 Dashboard con contadores
│   ├── orders_today/        # 📋 Pedidos del día (Excel)
│   ├── orders_history/      # 📈 Historial de pedidos
│   ├── clients/             # 👥 Gestión de clientes
│   ├── client_categories/   # 🏷️ Categorías de clientes
│   ├── shipping_methods/    # 🚚 Métodos de envío
│   ├── products/            # 📦 Catálogo de productos
│   ├── invoices/            # 🧾 Facturación
│   └── settings/            # ⚙️ Configuración
└── main.dart / main_dev.dart / main_pro.dart
```

Cada feature sigue la estructura de capas:

| Capa            | Responsabilidad                                             |
| --------------- | ----------------------------------------------------------- |
| `domain/`       | Entidades, repositorios (abstract) y casos de uso           |
| `data/`         | Implementación de repositorios, data sources (local/remoto) |
| `presentation/` | Pages, Widgets, BLoC/Cubit                                  |

### Dependencias clave

| Paquete                           | Propósito                                     |
| --------------------------------- | --------------------------------------------- |
| `flutter_bloc`                    | Gestión de estado (BLoC/Cubit)                |
| `get_it`                          | Inyección de dependencias (Service Locator)   |
| `fpdart`                          | Programación funcional (`Either<Failure, T>`) |
| `go_router`                       | Navegación declarativa                        |
| `dio`                             | Cliente HTTP                                  |
| `excel`                           | Lectura/escritura de archivos Excel           |
| `pdf` / `printing`                | Generación y previsualización de PDF          |
| `firebase_core` / `firebase_auth` | Autenticación Firebase                        |
| `cloud_firestore`                 | Base de datos Firestore                       |
| `firebase_database`               | Realtime Database                             |
| `cloud_functions`                 | Invocación de Cloud Functions                 |

## ⚙️ Configuración

### Entornos

| Entorno    | Entrypoint          | URL base                    | Logging  | Debug banner |
| ---------- | ------------------- | --------------------------- | -------- | ------------ |
| Dev        | `lib/main_dev.dart` | `http://localhost:8080`     | ✅ DEBUG | ✅           |
| Producción | `lib/main_pro.dart` | `https://api.servicebo.com` | ❌       | ❌           |

### Firebase

El proyecto utiliza Firebase con el proyecto `application-servicebo`. La
configuración se encuentra en `lib/firebase_options.dart`.

> [!IMPORTANT]
> Para configurar Firebase en un nuevo entorno, ejecuta:
>
> ```bash
> flutterfire configure --project=application-servicebo
> ```

### Cloud Functions

Las funciones se encuentran en `functions/` y se despliegan sobre **Node.js
22**:

| Función         | Descripción                                                                               |
| --------------- | ----------------------------------------------------------------------------------------- |
| `fdProxy`       | Proxy autenticado a la API de FacturaDirecta (GET/POST). Requiere autenticación Firebase. |
| `onUserDeleted` | Trigger que limpia datos asociados al eliminar un usuario de Firebase Auth.               |

El token de FacturaDirecta se almacena en **Google Secret Manager**
(`FD_API_TOKEN`).

## 🔧 Scripts disponibles

### Flutter

| Comando                                            | Descripción                    |
| -------------------------------------------------- | ------------------------------ |
| `flutter pub get`                                  | Instalar dependencias          |
| `flutter run -t lib/main_dev.dart`                 | Ejecutar en entorno dev        |
| `flutter run -t lib/main_pro.dart`                 | Ejecutar en entorno producción |
| `flutter gen-l10n`                                 | Generar archivos de traducción |
| `flutter test`                                     | Ejecutar tests unitarios       |
| `flutter test --coverage`                          | Tests con cobertura            |
| `dart analyze`                                     | Análisis estático              |
| `dart format .`                                    | Formatear código               |
| `flutter build web -t lib/main_pro.dart --release` | Build web (producción)         |

### Cloud Functions

| Comando          | Descripción                    |
| ---------------- | ------------------------------ |
| `npm run build`  | Compilar TypeScript            |
| `npm run serve`  | Build + emuladores locales     |
| `npm run deploy` | Desplegar funciones a Firebase |
| `npm run logs`   | Ver logs de funciones          |
| `npm run lint`   | Linter (ESLint)                |

## 🧪 Tests

El proyecto utiliza `flutter_test`, `mocktail` y `bloc_test` para los tests
unitarios:

```bash
# Ejecutar todos los tests
flutter test

# Tests con cobertura
flutter test --coverage

# Informe HTML de cobertura (requiere lcov)
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

Los tests se organizan replicando la estructura de `lib/`:

```
test/
├── features/
│   ├── home/presentation/bloc/
│   └── settings/
│       ├── data/repositories/
│       └── presentation/bloc/
└── widget_test.dart
```

## 🌐 Internacionalización (i18n)

El proyecto está configurado con `gen_l10n` y soporta **español (es)** como
idioma principal.

- **Archivos ARB**: `lib/app/localization/l10n/app_es.arb`
- **Clase generada**: `AppLocalizations`

Para añadir una nueva traducción:

1. Añade la clave en `lib/app/localization/l10n/app_es.arb`.
2. Ejecuta `flutter gen-l10n`.
3. Usa `AppLocalizations.of(context)!.tuClave` en el código.

> [!WARNING]
> No hardcodees textos visibles al usuario. Usa siempre `AppLocalizations`.

## 🚢 Despliegue

### Web (Firebase Hosting)

```bash
# Build de producción
flutter build web -t lib/main_pro.dart --release

# Desplegar a Firebase Hosting
firebase deploy --only hosting
```

### Cloud Functions

```bash
# Desde el directorio raíz
firebase deploy --only functions
```

> [!TIP]
> Los builds de producción deben usar siempre el entrypoint `lib/main_pro.dart`.
> | `dio` | Cliente HTTP |

FacturaDirecta\
APIKEY DdaxdT.4QY1XXjF3qd3pRDGMEvvarMb5uxyllsx

Pendiente:

- Posibilidad de eliminar clientes de Firestore.
- posibilidad de cambiar un cliente en la pantalla de pedidos de hoy.

Correcciones:

- No se ven
