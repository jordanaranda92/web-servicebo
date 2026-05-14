import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../../core/presentation/pages/not_found_page.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/client_categories/presentation/pages/client_categories_page.dart';
import '../../features/clients/domain/entities/client.dart';
import '../../features/clients/presentation/pages/client_detail_page.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/side_menu_shell.dart';
import '../../features/invoices/presentation/pages/invoice_detail_page.dart';
import '../../features/invoices/presentation/pages/invoices_page.dart';
import '../../features/orders_history/presentation/pages/orders_history_page.dart';
import '../../features/orders_today/presentation/pages/orders_today_page.dart';
import '../../features/orders_today/presentation/pages/orders_today_readonly_page.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/shipping_methods/presentation/pages/shipping_methods_page.dart';
import '../../features/statistics/presentation/pages/statistics_page.dart';

/// Route paths as constants for type-safe navigation.
abstract class AppRoutes {
  static const String home = '/home';
  static const String ordersToday = '/orders-today';
  static const String ordersHistory = '/orders-history';
  static const String clients = '/clients';
  static const String clientDetail = '/clients/:id/detail';
  static const String clientCategories = '/client-categories';
  static const String shippingMethods = '/shipping-methods';
  static const String products = '/products';
  static const String invoices = '/invoices';
  static const String invoiceDetail = '/invoices/:id/detail';
  static const String statistics = '/statistics';
  static const String settings = '/settings';
  static const String ordersTodayView = '/orders-today/view';
  static const String login = '/login';

  /// Base menu paths (without admin-only items).
  static const List<String> _baseMenuPaths = [
    home,
    ordersToday,
    ordersHistory,
    clients,
    clientCategories,
    shippingMethods,
    products,
    invoices,
  ];

  /// Returns ordered list of paths matching the side menu item indices.
  /// Admin users get the statistics item between invoices and settings.
  static List<String> menuPathsForRole({required bool isAdmin}) {
    return [..._baseMenuPaths, if (isAdmin) statistics, settings];
  }

  /// Kept for backward compatibility — returns paths for the current user's role.
  static List<String> get menuPaths {
    final authState = sl<AuthCubit>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.isAdmin;
    return menuPathsForRole(isAdmin: isAdmin);
  }

  /// Returns the menu index for the given location, or 0 (home) as default.
  static int indexFromLocation(String location, {bool? isAdmin}) {
    final paths = isAdmin != null
        ? menuPathsForRole(isAdmin: isAdmin)
        : menuPaths;
    for (var i = paths.length - 1; i >= 0; i--) {
      if (location.startsWith(paths[i])) return i;
    }
    return 0;
  }
}

/// Convenience wrapper for navigation.
abstract class AppRouter {
  static void go(BuildContext context, String path) =>
      GoRouter.of(context).go(path);

  static void push(BuildContext context, String path, {Object? extra}) =>
      GoRouter.of(context).push(path, extra: extra);

  static void pop(BuildContext context) => GoRouter.of(context).pop();
}

/// Creates the application [GoRouter].
GoRouter createRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      final loggedIn = sl<FirebaseAuth>().currentUser != null;
      final goingToLogin = state.matchedLocation == AppRoutes.login;

      if (!loggedIn && !goingToLogin) return AppRoutes.login;
      if (loggedIn && goingToLogin) return AppRoutes.home;
      if (state.matchedLocation == '/') return AppRoutes.home;

      // Role-based guard: redirect non-admin users away from /statistics
      if (state.matchedLocation == AppRoutes.statistics) {
        final authState = sl<AuthCubit>().state;
        final isAdmin =
            authState is AuthAuthenticated && authState.user.isAdmin;
        if (!isAdmin) return AppRoutes.home;
      }

      return null;
    },
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.ordersTodayView,
        builder: (context, state) => const OrdersTodayReadonlyPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => SideMenuShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: AppRoutes.ordersToday,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OrdersTodayPage()),
          ),
          GoRoute(
            path: AppRoutes.ordersHistory,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OrdersHistoryPage()),
          ),
          GoRoute(
            path: AppRoutes.clients,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ClientsPage()),
            routes: [
              GoRoute(
                path: ':id/detail',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: ClientDetailPage(
                    clientId: state.pathParameters['id']!,
                    client: state.extra as Client?,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.clientCategories,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ClientCategoriesPage()),
          ),
          GoRoute(
            path: AppRoutes.shippingMethods,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ShippingMethodsPage()),
          ),
          GoRoute(
            path: AppRoutes.products,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProductsPage()),
          ),
          GoRoute(
            path: AppRoutes.invoices,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InvoicesPage()),
            routes: [
              GoRoute(
                path: ':id/detail',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: InvoiceDetailPage(
                    invoiceId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.statistics,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StatisticsPage()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsPage()),
          ),
        ],
      ),
    ],
  );
}
