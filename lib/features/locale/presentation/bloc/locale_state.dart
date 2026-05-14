import 'dart:ui';

import 'package:equatable/equatable.dart';

/// State for locale/language management.
class LocaleState extends Equatable {
  const LocaleState({this.locale});

  /// The current locale. If null, the system locale is used.
  final Locale? locale;

  @override
  List<Object?> get props => [locale];

  LocaleState copyWith({Locale? locale}) {
    return LocaleState(locale: locale ?? this.locale);
  }
}
