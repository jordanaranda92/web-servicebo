/// Sistema de logging centralizado.
///
/// Uso:
/// ```dart
/// final logger = getIt<AppLogger>();
/// logger.debug('Cargando datos...');
/// logger.info('Usuario autenticado: $userId');
/// logger.warning('Cache expirada, recargando...');
/// logger.error('Fallo al conectar', error, stackTrace);
/// ```
///
/// Se activa/desactiva según `enableLogging` de `AppConfig`.
library;

export 'app_logger.dart';
export 'firebase_operations_logger.dart';
export 'log_level.dart';
