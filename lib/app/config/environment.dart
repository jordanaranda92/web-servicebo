/// Represents the different environments the application can run in.
enum Environment {
  /// Local environment
  local,

  /// Pro environment
  pro;

  /// Returns a human-readable name for the environment.
  String get displayName {
    switch (this) {
      case Environment.local:
        return 'Local';
      case Environment.pro:
        return 'Pro';
    }
  }

  /// Returns true if the environment is local.
  bool get isLocal => this == Environment.local;

  /// Returns true if the environment is pro.
  bool get isPro => this == Environment.pro;

}
