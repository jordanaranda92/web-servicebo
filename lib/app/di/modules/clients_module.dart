import 'package:get_it/get_it.dart';

import '../../../features/clients/data/datasources/client_firestore_data_source.dart';
import '../../../features/clients/data/datasources/client_firestore_data_source_impl.dart';
import '../../../features/clients/data/repositories/clients_repository_impl.dart';
import '../../../features/clients/domain/repositories/clients_repository.dart';
import '../../../features/clients/domain/usecases/get_clients.dart';
import '../../../features/clients/domain/usecases/save_clients_batch.dart';
import '../../../features/clients/domain/usecases/get_client_fd_data.dart';
import '../../../features/clients/domain/usecases/get_fd_fiscal_ids.dart';
import '../../../features/clients/domain/usecases/fetch_new_fd_contacts.dart';
import '../../../features/clients/domain/usecases/add_selected_fd_contacts.dart';
import '../../../features/clients/domain/usecases/watch_clients.dart';
import '../../../features/clients/presentation/bloc/clients_cubit.dart';

void registerClientsModule(GetIt sl) {
  // Data — DataSources
  sl.registerLazySingleton<ClientFirestoreDataSource>(
    () => ClientFirestoreDataSourceImpl(sl(), sl()),
  );

  // Data — Repository
  sl.registerLazySingleton<ClientsRepository>(
    () => ClientsRepositoryImpl(sl(), sl(), sl()),
  );

  // Domain — UseCases
  sl.registerLazySingleton(() => GetClients(sl()));
  sl.registerLazySingleton(() => WatchClients(sl()));
  sl.registerLazySingleton(() => SaveClientsBatch(sl()));
  sl.registerLazySingleton(() => GetClientFdData(sl()));
  sl.registerLazySingleton(() => GetFdFiscalIds(sl()));
  sl.registerLazySingleton(
    () => FetchNewFdContacts(sl(), sl<ClientsRepository>()),
  );
  sl.registerLazySingleton(
    () => AddSelectedFdContacts(sl<ClientsRepository>()),
  );

  // Presentation — Cubits
  sl.registerFactory(
    () => ClientsCubit(sl(), sl(), sl(), sl(), sl(), sl(), sl()),
  );
}
