import 'package:servicebo/core/log/log_level.dart';

import 'environment.dart';

/// Abstract base class for application configuration.
///
/// Defines all configuration values that vary between environments.
/// Each environment (local, dev, pre, pro) provides its own concrete implementation.
abstract class AppConfig {
  /// The current environment.
  Environment get environment;

  /// The base URL for API requests.
  String get baseUrl;

  /// Whether to enable verbose logging.
  bool get enableLogging;

  /// Whether to show debug banners and overlays.
  bool get showDebugBanner;

  /// Minimum log level for the logging system.
  LogLevel get logMinLevel;
}
