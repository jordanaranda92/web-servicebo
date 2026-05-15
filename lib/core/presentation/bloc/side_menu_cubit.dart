import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'side_menu_state.dart';

class SideMenuCubit extends Cubit<SideMenuState> {
  static const String _expandedKey = 'side_menu_expanded';

  final SharedPreferences _prefs;

  SideMenuCubit(this._prefs)
    : super(SideMenuState(isExpanded: _prefs.getBool(_expandedKey) ?? true));

  void toggleExpanded() {
    final newExpanded = !state.isExpanded;
    _prefs.setBool(_expandedKey, newExpanded);
    emit(SideMenuState(isExpanded: newExpanded));
  }
}
