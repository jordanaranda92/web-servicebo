import 'package:servicebo/core/log/log_level.dart';

import '../app_config.dart';
import '../environment.dart';

/// Configuration for dev environment.
class DevConfig implements AppConfig {
  @override
  Environment get environment => Environment.dev;

  @override
  String get baseUrl => 'http://localhost:8080';

  @override
  bool get enableLogging => true;

  @override
  bool get showDebugBanner => true;

  @override
  LogLevel get logMinLevel => LogLevel.debug;
}
