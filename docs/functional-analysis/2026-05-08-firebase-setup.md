# Functional Analysis: Configuración de Firebase (Realtime Database y Analytics)

- **Fecha:** 2026-05-08
- **Identificador:** firebase-setup
- **Estado:** Draft — Pendiente de respuesta a preguntas abiertas

## 1) Resumen

Integrar Firebase en el proyecto Servicebo para habilitar dos servicios
concretos: **Firebase Realtime Database** (RTDB) y **Firebase Analytics**. Esto
implica crear el proyecto Firebase, configurar las plataformas objetivo (macOS y
Windows), añadir las dependencias necesarias e inicializar Firebase en el ciclo
de arranque de la aplicación, respetando los entornos existentes (local / pro).

## 2) Contexto y objetivo

### Qué se solicita

Configurar Firebase en un proyecto Flutter desktop existente que actualmente no
tiene ninguna integración con Firebase. Se requieren específicamente dos
servicios:

1. **Realtime Database** — base de datos NoSQL en tiempo real.
2. **Analytics** — seguimiento de eventos y uso de la aplicación.

### Qué problema resuelve

- **Realtime Database:** proporciona un mecanismo de sincronización de datos en
  tiempo real entre instancias de la app o con otros clientes, sin necesidad de
  implementar polling o websockets propios.
- **Analytics:** aporta visibilidad sobre el uso real de la aplicación
  (pantallas visitadas, acciones del usuario, retención, etc.).

### Qué resultado funcional se espera

- La aplicación arranca correctamente con Firebase inicializado en ambos
  entornos.
- La app puede leer y escribir datos en Realtime Database.
- Los eventos de analytics se registran y son visibles en la consola de
  Firebase.

## 3) Alcance

### En alcance

- **AC-01:** Creación/configuración del proyecto Firebase (consola) con las apps
  necesarias para las plataformas objetivo.
- **AC-02:** Integración de las dependencias de Firebase en el proyecto Flutter
  (`firebase_core`, `firebase_database`, `firebase_analytics`).
- **AC-03:** Inicialización de Firebase en el arranque de la app
  (`Firebase.initializeApp`) integrada con el flujo existente de
  `runApplication` y el sistema de configuración por entornos (`AppConfig`).
- **AC-04:** Soporte multi-entorno: posibilidad de apuntar a proyectos o
  instancias de Firebase distintas según el entorno (local vs. pro).
- **AC-05:** Verificación básica de conectividad con RTDB (lectura/escritura de
  un nodo de prueba).
- **AC-06:** Verificación básica de Analytics (envío de un evento de prueba
  visible en la consola).

### Fuera de alcance

- Modelado de datos o estructura de nodos en Realtime Database para
  funcionalidades de negocio.
- Reglas de seguridad de Realtime Database (se usarán reglas por defecto o de
  desarrollo).
- Implementación de features de negocio que consuman RTDB (ej.: sincronización
  de pedidos en tiempo real).
- Definición de plan de eventos de analytics (qué eventos de negocio trackear).
- Integración con otros servicios de Firebase (Auth, Crashlytics, Cloud
  Messaging, Remote Config, etc.).
- Configuración de CI/CD con Firebase.
- Migración de datos existentes a RTDB.

## 4) Actores implicados

| Actor                         | Rol                                                                                                                                |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Desarrollador**             | Configura el proyecto Firebase, integra dependencias, implementa la inicialización                                                 |
| **Administrador de Firebase** | Crea el proyecto en la consola de Firebase, gestiona permisos y configuración                                                      |
| **Usuario final**             | No interactúa directamente con esta configuración; se beneficia indirectamente de las funcionalidades que se construyan sobre ella |

## 5) Requisitos funcionales

- **RF-01:** El proyecto debe incluir las dependencias de Firebase necesarias:
  `firebase_core`, `firebase_database` y `firebase_analytics`.
- **RF-02:** Firebase debe inicializarse antes de que la aplicación renderice la
  primera pantalla, dentro del flujo existente de `_initializeServices`.
- **RF-03:** La configuración de Firebase debe variar según el entorno activo
  (`local` → proyecto Firebase de desarrollo, `pro` → proyecto Firebase de
  producción), usando `FirebaseOptions` específicas por entorno o un único
  proyecto con separación lógica.
- **RF-04:** Si la inicialización de Firebase falla, la aplicación debe manejar
  el error de forma controlada (log del error, posibilidad de continuar sin
  Firebase o mostrar un aviso).
- **RF-05:** Firebase Analytics debe registrar al menos los eventos automáticos
  de pantalla (`screen_view`) una vez configurado.
- **RF-06:** Firebase Realtime Database debe ser accesible para operaciones
  básicas de lectura y escritura una vez inicializado.
- **RF-07:** La configuración debe funcionar en las plataformas objetivo del
  proyecto: **macOS** y **Windows**.

## 6) Criterios de aceptación

- **CA-01:** La app compila y arranca sin errores en macOS y Windows con
  Firebase inicializado.
- **CA-02:** Al arrancar la app con el entorno `local`, Firebase se conecta al
  proyecto de desarrollo; con `pro`, al proyecto de producción (o al mismo
  proyecto con separación lógica definida).
- **CA-03:** Un evento de prueba enviado desde la app aparece en la sección
  Analytics de la consola de Firebase en un plazo razonable (hasta 24h por el
  procesamiento de Analytics).
- **CA-04:** Una escritura de prueba en Realtime Database desde la app es
  visible en la consola de Firebase en tiempo real.
- **CA-05:** Una lectura de prueba desde la app devuelve los datos previamente
  escritos en RTDB.
- **CA-06:** Si Firebase no está disponible (sin red, configuración inválida),
  la app no crashea; se registra el error en el sistema de logs existente.
- **CA-07:** Las dependencias de Firebase no rompen los tests existentes del
  proyecto.

## 7) Flujos y comportamiento esperado

### Flujo principal — Inicialización exitosa

1. El usuario (o sistema) lanza la app con un entorno configurado (local/pro).
2. `runApplication(config)` se invoca con la configuración del entorno.
3. `_initializeServices(config)` ejecuta `Firebase.initializeApp(options: ...)`
   con las `FirebaseOptions` correspondientes al entorno.
4. Firebase se inicializa correctamente.
5. El servicio de Analytics comienza a registrar eventos automáticos.
6. La referencia a Realtime Database queda disponible para su uso en la app.
7. La app continúa con la inyección de dependencias y el renderizado normal.

### Flujos alternativos

- **FA-01 — Sin conexión a internet:** Firebase se inicializa con los datos en
  caché (si los hay). RTDB opera en modo offline con sincronización diferida.
  Analytics encola eventos para envío posterior.
- **FA-02 — Configuración Firebase ausente o inválida:** La inicialización lanza
  una excepción. La app la captura, registra el error en el logger, y decide si
  continuar sin Firebase o mostrar un aviso al usuario.

### Estados especiales / excepciones

- **Estado sin conectividad:** RTDB funciona offline (Firebase soporta
  persistencia local). Analytics encola eventos.
- **Estado error de configuración:** Firebase no se inicializa. Las
  funcionalidades que dependan de Firebase no estarán disponibles. La app debe
  seguir funcionando en sus funcionalidades independientes de Firebase.
- **Estado primera ejecución:** Puede requerir aceptación de permisos
  específicos de plataforma (macOS: entitlements de red, keychain).

## 8) Edge cases

- **EC-01:** La app se ejecuta en una plataforma no soportada por algún plugin
  de Firebase (ej.: `firebase_analytics` podría tener limitaciones en Windows).
  Se debe verificar compatibilidad real de cada plugin con cada plataforma
  objetivo.
- **EC-02:** Conflicto entre el sistema de Google OAuth existente (paquete
  `googleapis_auth`) y Firebase Auth (si se añadiera en el futuro). No aplica
  directamente ahora pero debe tenerse en cuenta.
- **EC-03:** Ejecución de tests unitarios: `Firebase.initializeApp` no debe
  ejecutarse en entorno de test si no hay un mock adecuado. Los tests existentes
  no deben romperse.
- **EC-04:** Múltiples llamadas a `Firebase.initializeApp` (ej.: hot restart en
  desarrollo) deben manejarse sin error.
- **EC-05:** Reglas de seguridad por defecto de RTDB: en modo desarrollo pueden
  ser abiertas, pero en producción deben restringirse. Esto queda fuera de
  alcance de esta configuración inicial pero es un riesgo a documentar.

## 9) Impacto funcional

- **Módulos afectados:**
  - `lib/main.dart` — modificación del flujo de inicialización.
  - `lib/app/config/` — posible extensión de `AppConfig` con propiedades de
    Firebase.
  - `lib/app/di/` — registro de servicios de Firebase en GetIt.
  - `lib/core/` — posible wrapper/service para RTDB y Analytics.
  - `pubspec.yaml` — nuevas dependencias.
  - Configuración de plataforma: `macos/` (Podfile, entitlements), `windows/`
    (CMakeLists).

- **Impacto en usuario:** Transparente. El usuario no percibe cambios directos
  en esta fase de configuración.

- **Impacto en negocio:** Habilita la infraestructura para futuras
  funcionalidades basadas en datos en tiempo real y para obtener métricas de uso
  de la aplicación.

- **Impacto en experiencia de desarrollo:**
  - Los desarrolladores necesitarán tener acceso al proyecto Firebase.
  - Se requiere `flutterfire_cli` o configuración manual para generar los
    archivos de configuración.
  - Posible impacto menor en tiempo de compilación por nuevas dependencias
    nativas.

## 10) Suposiciones

- **S-01:** Existe o se creará un proyecto en la consola de Firebase para esta
  aplicación.
- **S-02:** Se usarán dos proyectos Firebase separados (o un proyecto con
  configuración diferenciada) para los entornos local y pro.
- **S-03:** Las plataformas objetivo actuales son macOS y Windows (basado en la
  estructura del proyecto y la configuración de orientación landscape).
- **S-04:** No se requiere Firebase Authentication en este momento (el proyecto
  usa su propio sistema con FacturaDirecta y Google OAuth).
- **S-05:** La versión mínima de macOS del proyecto es compatible con los
  plugins de Firebase (macOS 10.15+).
- **S-06:** Se aceptan las reglas de seguridad abiertas de RTDB para la fase
  inicial de configuración.

## 11) Preguntas abiertas

- **PA-01:** ¿Se desea un **único proyecto Firebase** con separación lógica por
  entorno (ej.: prefijos en RTDB, property diferente en Analytics) o **dos
  proyectos Firebase independientes** (uno para desarrollo/local, otro para
  producción)?
- **PA-02:** ¿Cuál es el **uso previsto de Realtime Database**? (ej.:
  sincronización de pedidos entre dispositivos, notificaciones en tiempo real,
  configuración remota, etc.). Esto no afecta a la configuración base pero ayuda
  a dimensionar y priorizar.
- **PA-03:** ¿La app necesita funcionar también en **plataformas móviles**
  (iOS/Android) ahora o en el futuro? Esto influye en la configuración del
  proyecto Firebase y los archivos de plataforma a generar.

## 12) Notas para análisis técnico

- **Dependencias a evaluar:** `firebase_core`, `firebase_database`,
  `firebase_analytics`. Verificar compatibilidad con macOS y Windows en las
  versiones actuales de cada plugin.
- **FlutterFire CLI:** Evaluar uso de `flutterfire configure` para generar
  `firebase_options.dart` por entorno, o configuración manual.
- **Entitlements macOS:** Se requerirán permisos de red
  (`com.apple.security.network.client`) en los entitlements de macOS. Verificar
  si ya están configurados.
- **Inicialización:** Integrar `Firebase.initializeApp` en `_initializeServices`
  de `main.dart`, antes de `initDI`.
- **Inyección de dependencias:** Registrar `FirebaseDatabase.instance` y
  `FirebaseAnalytics.instance` en GetIt como singletons.
- **Testing:** Proveer un mecanismo para que los tests no dependan de Firebase
  real (mock o `setupFirebaseForTesting`).
- **Restricción funcional:** La inicialización de Firebase no debe bloquear el
  arranque de la app si falla.
- **Riesgo:** `firebase_analytics` puede tener soporte limitado o nulo en
  Windows desktop. Verificar estado del plugin.
- **Estado: Listo para análisis técnico** (pendiente de resolución de preguntas
  abiertas PA-01 a PA-03, aunque se puede proceder con supuestos razonables).
