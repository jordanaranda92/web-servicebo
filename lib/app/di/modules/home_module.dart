import 'package:get_it/get_it.dart';

import '../../../features/home/presentation/bloc/fd_counters_cubit.dart';
import '../../../features/home/presentation/bloc/side_menu_cubit.dart';

/// Registers home/navigation feature dependencies.
void registerHomeModule(GetIt sl) {
  sl.registerLazySingleton(() => SideMenuCubit(sl()));

  // Presentation — Cubit (factory: one per screen lifecycle)
  sl.registerFactory(() => FdCountersCubit(getInvoicesByDateRange: sl()));
}
