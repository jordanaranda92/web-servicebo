import 'package:intl/intl.dart';

/// Centralized date format constants to avoid hardcoded format strings.
class AppDateFormats {
  static const String locale = 'es';

  /// "lunes"
  static DateFormat dayName() => DateFormat('EEEE', locale);

  /// "Lunes, 28 de marzo"
  static DateFormat dateWithDay() => DateFormat("EEEE, d 'de' MMMM", locale);

  /// "Lunes, 28 de marzo de 2026"
  static DateFormat fullDateWithDay() =>
      DateFormat("EEEE, d 'de' MMMM 'de' yyyy", locale);

  /// "28/03/2026"
  static DateFormat shortDate() => DateFormat('dd/MM/yyyy', locale);

  /// "14:30:00"
  static DateFormat time() => DateFormat('HH:mm:ss', locale);
}
