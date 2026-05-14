import 'package:get_it/get_it.dart';

import '../../../features/clients/data/datasources/client_firestore_data_source.dart';
import '../../../features/orders_history/data/repositories/orders_history_repository_impl.dart';
import '../../../features/orders_history/domain/repositories/orders_history_repository.dart';
import '../../../features/orders_history/domain/usecases/get_available_dates.dart';
import '../../../features/orders_history/domain/usecases/get_history_orders.dart';
import '../../../features/orders_history/presentation/bloc/orders_history_bloc.dart';
import '../../../features/orders_today/data/datasources/remote/order_firestore_data_source.dart';
import '../../../features/products/data/datasources/product_firestore_data_source.dart';

void registerOrdersHistoryModule(GetIt sl) {
  // Data — Repository
  sl.registerLazySingleton<OrdersHistoryRepository>(
    () => OrdersHistoryRepositoryImpl(
      sl<OrderFirestoreDataSource>(),
      sl<ClientFirestoreDataSource>(),
      sl<ProductFirestoreDataSource>(),
      sl(),
    ),
  );

  // Domain — UseCases
  sl.registerLazySingleton(() => GetAvailableDates(sl()));
  sl.registerLazySingleton(() => GetHistoryOrders(sl()));

  // Presentation — BLoC
  sl.registerFactory(
    () => OrdersHistoryBloc(getAvailableDates: sl(), getHistoryOrders: sl()),
  );
}
