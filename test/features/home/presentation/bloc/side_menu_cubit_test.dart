import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:servicebo/features/home/presentation/bloc/side_menu_cubit.dart';
import 'package:servicebo/features/home/presentation/bloc/side_menu_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  group('SideMenuCubit', () {
    late SideMenuCubit cubit;
    late SharedPreferences mockPrefs;

    setUp(() {
      mockPrefs = MockSharedPreferences();
      when(() => mockPrefs.getBool(any())).thenReturn(true);
      when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
      cubit = SideMenuCubit(mockPrefs);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state has isExpanded true', () {
      expect(cubit.state, const SideMenuState());
      expect(cubit.state.isExpanded, true);
    });

    SideMenuCubit buildCubit() {
      final prefs = MockSharedPreferences();
      when(() => prefs.getBool(any())).thenReturn(true);
      when(() => prefs.setBool(any(), any())).thenAnswer((_) async => true);
      return SideMenuCubit(prefs);
    }

    group('toggleExpanded', () {
      blocTest<SideMenuCubit, SideMenuState>(
        'toggles isExpanded from true to false',
        build: buildCubit,
        act: (cubit) => cubit.toggleExpanded(),
        expect: () => [const SideMenuState(isExpanded: false)],
      );

      blocTest<SideMenuCubit, SideMenuState>(
        'toggles isExpanded back to true',
        build: buildCubit,
        act: (cubit) {
          cubit.toggleExpanded();
          cubit.toggleExpanded();
        },
        expect: () => [
          const SideMenuState(isExpanded: false),
          const SideMenuState(isExpanded: true),
        ],
      );
    });
  });
}
