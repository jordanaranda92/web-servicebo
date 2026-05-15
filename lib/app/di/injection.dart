import 'package:get_it/get_it.dart';

import '../config/app_config.dart';
import 'modules/auth_module.dart';
import 'modules/client_categories_module.dart';
import 'modules/clients_module.dart';
import 'modules/core_module.dart';
import 'modules/navigation_module.dart';
import 'modules/invoices_module.dart';
import 'modules/locale_module.dart';
import 'modules/orders_history_module.dart';
import 'modules/orders_today_module.dart';
import 'modules/products_module.dart';
import 'modules/settings_module.dart';
import 'modules/shipping_methods_module.dart';
import 'modules/statistics_module.dart';

final sl = GetIt.instance;

/// Initializes the dependency injection container.
///
/// Must be called before `runApp` in `main.dart`.
Future<void> initDI(AppConfig config, {bool firebaseAvailable = false}) async {
  // Register the app configuration
  sl.registerLazySingleton<AppConfig>(() => config);
  sl.registerLazySingleton<bool>(
    () => firebaseAvailable,
    instanceName: 'firebaseAvailable',
  );

  await registerCoreModule(sl, firebaseAvailable: firebaseAvailable);

  // Register global modules (locale, etc.)
  registerLocaleModule(sl);

  // Register feature modules
  registerAuthModule(sl);
  registerNavigationModule(sl);
  registerSettingsModule(sl);
  registerOrdersTodayModule(sl);
  registerOrdersHistoryModule(sl);
  registerClientsModule(sl);
  registerClientCategoriesModule(sl);
  registerShippingMethodsModule(sl);
  registerProductsModule(sl);
  registerInvoicesModule(sl);
  registerStatisticsModule(sl);
}
