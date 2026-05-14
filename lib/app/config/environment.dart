/// Represents the different environments the application can run in.
enum Environment {
  /// Dev environment
  dev,

  /// Pro environment
  pro;

  /// Returns a human-readable name for the environment.
  String get displayName {
    switch (this) {
      case Environment.dev:
        return 'Dev';
      case Environment.pro:
        return 'Pro';
    }
  }

  /// Returns true if the environment is dev.
  bool get isDev => this == Environment.dev;

  /// Returns true if the environment is pro.
  bool get isPro => this == Environment.pro;
}
