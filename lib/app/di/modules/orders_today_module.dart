import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get_it/get_it.dart';

import '../../../core/auth/current_user_provider.dart';
import '../../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../../features/auth/data/providers/firebase_current_user_provider.dart';
import '../../../features/orders_today/data/datasources/remote/order_firestore_data_source.dart';
import '../../../features/orders_today/data/datasources/remote/order_firestore_data_source_impl.dart';
import '../../../features/orders_today/data/datasources/remote/orders_rtdb_data_source.dart';
import '../../../features/orders_today/data/datasources/remote/orders_rtdb_data_source_impl.dart';
import '../../../features/orders_today/data/repositories/orders_presence_repository_impl.dart';
import '../../../features/orders_today/data/repositories/orders_today_repository_impl.dart';
import '../../../features/orders_today/data/services/order_sheet_excel_service.dart';
import '../../../features/orders_today/data/services/order_sheet_pdf_service.dart';
import '../../../features/orders_today/domain/repositories/orders_presence_repository.dart';
import '../../../features/orders_today/domain/repositories/orders_today_repository.dart';
import '../../../features/orders_today/domain/services/order_sheet_excel_generator.dart';
import '../../../features/orders_today/domain/services/order_sheet_pdf_generator.dart';
import '../../../features/orders_today/domain/usecases/add_order_clients.dart';
import '../../../features/orders_today/domain/usecases/add_order_products.dart';
import '../../../features/orders_today/domain/usecases/create_today_file.dart';
import '../../../features/orders_today/domain/usecases/get_action_history.dart';
import '../../../features/orders_today/domain/usecases/get_today_orders.dart';
import '../../../features/orders_today/domain/usecases/remove_order_clients.dart';
import '../../../features/orders_today/domain/usecases/remove_order_products.dart';
import '../../../features/orders_today/domain/usecases/reset_client_orders.dart';
import '../../../features/orders_today/domain/usecases/update_cell_flag.dart';
import '../../../features/orders_today/domain/usecases/update_cell_note.dart';
import '../../../features/orders_today/domain/usecases/update_cell_refund.dart';
import '../../../features/orders_today/domain/usecases/update_order_cell.dart';
import '../../../features/orders_today/presentation/bloc/orders_today_bloc.dart';

void registerOrdersTodayModule(GetIt sl) {
  // Data — CurrentUserProvider
  sl.registerLazySingleton<CurrentUserProvider>(
    () => FirebaseCurrentUserProvider(
      sl<FirebaseAuth>(),
      sl<AuthRemoteDataSource>(),
    ),
  );

  // Data — Firestore DataSource
  sl.registerLazySingleton<OrderFirestoreDataSource>(
    () => OrderFirestoreDataSourceImpl(
      sl<FirebaseFirestore>(),
      sl<CurrentUserProvider>(),
      sl(),
    ),
  );

  // Data — RTDB DataSource (only if Firebase is available)
  final firebaseAvailable =
      sl.isRegistered<bool>(instanceName: 'firebaseAvailable') &&
      sl<bool>(instanceName: 'firebaseAvailable');
  if (firebaseAvailable) {
    sl.registerLazySingleton<OrdersRtdbDataSource>(
      () => OrdersRtdbDataSourceImpl(sl<FirebaseDatabase>(), sl()),
    );

    sl.registerLazySingleton<OrdersPresenceRepository>(
      () => OrdersPresenceRepositoryImpl(sl<OrdersRtdbDataSource>()),
    );
  }

  // Data — Repository
  sl.registerLazySingleton<OrdersTodayRepository>(
    () => OrdersTodayRepositoryImpl(sl(), sl(), sl(), sl()),
    dispose: (repo) => repo.dispose(),
  );

  // Domain — UseCases
  sl.registerLazySingleton(() => GetTodayOrders(sl()));
  sl.registerLazySingleton(() => CreateTodayFile(sl()));
  sl.registerLazySingleton(() => UpdateOrderCell(sl()));
  sl.registerLazySingleton(() => UpdateCellFlag(sl()));
  sl.registerLazySingleton(() => UpdateCellNote(sl()));
  sl.registerLazySingleton(() => UpdateCellRefund(sl()));
  sl.registerLazySingleton(() => RemoveOrderClients(sl()));
  sl.registerLazySingleton(() => RemoveOrderProducts(sl()));
  sl.registerLazySingleton(() => ResetClientOrders(sl()));
  sl.registerLazySingleton(() => AddOrderClients(sl()));
  sl.registerLazySingleton(() => AddOrderProducts(sl()));
  sl.registerLazySingleton(() => GetActionHistory(sl()));

  // Data — Services
  sl.registerLazySingleton<OrderSheetExcelGenerator>(
    () => OrderSheetExcelService(),
  );
  sl.registerLazySingleton<OrderSheetPdfGenerator>(
    () => OrderSheetPdfService(),
  );

  // Presentation — BLoC
  sl.registerFactory(
    () => OrdersTodayBloc(
      getTodayOrders: sl(),
      createTodayFile: sl(),
      updateOrderCell: sl(),
      updateCellFlag: sl(),
      updateCellNote: sl(),
      updateCellRefund: sl(),
      resetClientOrders: sl(),
      removeOrderClients: sl(),
      removeOrderProducts: sl(),
      addOrderClients: sl(),
      addOrderProducts: sl(),
      repository: sl(),
      logger: sl(),
    ),
  );
}
