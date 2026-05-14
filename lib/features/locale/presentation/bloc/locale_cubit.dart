import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/locale_repository.dart';
import 'locale_state.dart';

/// Cubit that manages the application's locale state.
class LocaleCubit extends Cubit<LocaleState> {
  LocaleCubit(this._repository) : super(const LocaleState());

  final LocaleRepository _repository;

  /// Initializes the cubit by loading the saved locale.
  Future<void> init() async {
    final savedLocale = await _repository.getLocale();
    emit(LocaleState(locale: savedLocale));
  }

  /// Changes the application locale and persists the preference.
  Future<void> changeLocale(Locale locale) async {
    await _repository.saveLocale(locale);
    emit(LocaleState(locale: locale));
  }

  /// Resets to system locale and clears the saved preference.
  Future<void> resetToSystemLocale() async {
    await _repository.clearLocale();
    emit(const LocaleState(locale: null));
  }
}
