import 'package:servicebo/core/log/log_level.dart';

import '../app_config.dart';
import '../environment.dart';

/// Configuration for pro environment.
class ProConfig implements AppConfig {
  @override
  Environment get environment => Environment.pro;

  @override
  String get baseUrl => 'https://api.servicebo.com';

  @override
  bool get enableLogging => false;

  @override
  bool get showDebugBanner => false;

  @override
  LogLevel get logMinLevel => LogLevel.none;
}
