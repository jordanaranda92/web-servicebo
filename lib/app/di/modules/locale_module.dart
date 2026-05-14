import 'package:get_it/get_it.dart';

// Data
import '../../../features/locale/data/repositories/locale_repository_impl.dart';
// Domain
import '../../../features/locale/domain/repositories/locale_repository.dart';
// Presentation
import '../../../features/locale/presentation/bloc/locale_cubit.dart';

/// Registers locale feature dependencies.
///
/// Order: Presentation -> Domain -> Data
void registerLocaleModule(GetIt sl) {
  // Presentation
  // LocaleCubit is a singleton because it's a global cubit that:
  // 1. Is used as a global provider in main.dart
  // 2. Requires initialization once at startup (init() method)
  // 3. Maintains persistent state throughout the app lifecycle
  sl.registerLazySingleton(() => LocaleCubit(sl()));

  // Domain
  // UseCases would go here if needed

  // Data
  sl.registerLazySingleton<LocaleRepository>(() => LocaleRepositoryImpl(sl()));
}
