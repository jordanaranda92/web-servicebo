import 'package:get_it/get_it.dart';

import '../../../core/presentation/bloc/side_menu_cubit.dart';

/// Registers navigation/shell dependencies.
void registerNavigationModule(GetIt sl) {
  sl.registerLazySingleton(() => SideMenuCubit(sl()));
}
