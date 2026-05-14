# Configuración de la Aplicación

Esta carpeta contiene archivos de configuración global de la aplicación.

## Contenido

- `app_config.dart` - Clase abstracta base de configuración
- `environment.dart` - Enum con los diferentes entornos
- `environments/` - Configuraciones específicas por entorno:
- `local_config.dart` - Configuración del entorno **local**
- `pro_config.dart` - Configuración del entorno **pro**

## Contenido Sugerido Adicional

- `api_config.dart` - URLs base, timeouts, headers por defecto
- `constants.dart` - Constantes globales de la aplicación
