import 'package:get_it/get_it.dart';

import '../../../features/statistics/presentation/bloc/fd_counters_cubit.dart';

/// Registers statistics feature dependencies.
void registerStatisticsModule(GetIt sl) {
  // Presentation — Cubit (factory: one per screen lifecycle)
  sl.registerFactory(() => FdCountersCubit(getInvoicesByDateRange: sl()));
}
