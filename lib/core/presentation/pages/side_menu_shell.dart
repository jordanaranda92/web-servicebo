import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/injection.dart';
import '../../../app/localization/l10n/app_localizations.dart';
import '../../../app/router/router.dart';
import '../../../app/theme/theme_constants.dart';
import '../../services/navigation_guard.dart';
import '../../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../../features/auth/presentation/bloc/auth_state.dart';
import '../bloc/side_menu_cubit.dart';
import '../bloc/side_menu_state.dart';
import '../widgets/side_menu.dart';

class SideMenuShell extends StatelessWidget {
  const SideMenuShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final guard = sl<NavigationGuard>();
    final location = GoRouterState.of(context).uri.toString();
    final authState = context.read<AuthCubit>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.isAdmin;
    final currentMenuPaths = AppRoutes.menuPathsForRole(isAdmin: isAdmin);
    final selectedIndex = AppRoutes.indexFromLocation(
      location,
      isAdmin: isAdmin,
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth <= AppSideMenu.mobileBreakpoint;

    if (isMobile) {
      return _buildMobileLayout(
        context,
        selectedIndex,
        guard,
        location,
        isAdmin: isAdmin,
        currentMenuPaths: currentMenuPaths,
      );
    }
    return _buildDesktopLayout(
      context,
      selectedIndex,
      guard,
      isAdmin: isAdmin,
      currentMenuPaths: currentMenuPaths,
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    int selectedIndex,
    NavigationGuard guard, {
    required bool isAdmin,
    required List<String> currentMenuPaths,
  }) {
    return Scaffold(
      body: BlocBuilder<SideMenuCubit, SideMenuState>(
        buildWhen: (previous, current) =>
            previous.isExpanded != current.isExpanded,
        builder: (context, state) {
          return Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SideMenu(
                  selectedIndex: selectedIndex,
                  isExpanded: state.isExpanded,
                  isAdmin: isAdmin,
                  onItemSelected: (index) => _onItemSelected(
                    context,
                    index,
                    selectedIndex,
                    guard,
                    currentMenuPaths,
                  ),
                  onToggleExpanded: () =>
                      context.read<SideMenuCubit>().toggleExpanded(),
                ),
              ),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    int selectedIndex,
    NavigationGuard guard,
    String location, {
    required bool isAdmin,
    required List<String> currentMenuPaths,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final clientDetailMatch = RegExp(
      r'/clients/([^/]+)/detail',
    ).firstMatch(location);
    final isClientDetail = clientDetailMatch != null;

    final invoiceDetailMatch = RegExp(
      r'/invoices/([^/]+)/detail',
    ).firstMatch(location);
    final isInvoiceDetail = invoiceDetailMatch != null;

    if (isClientDetail) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          leading: IconButton(
            onPressed: () => context.go(AppRoutes.clients),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(l10n.clientsDetailTitle),
          titleSpacing: 0,
          scrolledUnderElevation: 0,
        ),
        body: child,
      );
    }

    if (isInvoiceDetail) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          leading: IconButton(
            onPressed: () => context.go(AppRoutes.invoices),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(l10n.invoiceDetailTitle),
          titleSpacing: 0,
          scrolledUnderElevation: 0,
        ),
        body: child,
      );
    }

    return Scaffold(
      drawerEnableOpenDragGesture: false,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leading: Builder(
          builder: (scaffoldContext) {
            return IconButton(
              onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            );
          },
        ),
        title: Text(
          _mobileTitleForIndex(selectedIndex, l10n, isAdmin: isAdmin),
        ),
        titleSpacing: 0,
        scrolledUnderElevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        width: AppSideMenu.expandedWidth + AppSpacing.lg,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SideMenu(
            selectedIndex: selectedIndex,
            isExpanded: true,
            showToggleButton: false,
            isAdmin: isAdmin,
            onItemSelected: (index) {
              if (index == selectedIndex) {
                Navigator.of(context).pop();
                return;
              }
              final targetPath = currentMenuPaths[index];
              if (guard.shouldBlock) {
                _showUnsavedDialog(context, guard, targetPath, isMobile: true);
              } else {
                Navigator.of(context).pop();
                context.go(targetPath);
              }
            },
            onToggleExpanded: () {},
          ),
        ),
      ),
      body: child,
    );
  }

  void _onItemSelected(
    BuildContext context,
    int index,
    int selectedIndex,
    NavigationGuard guard,
    List<String> currentMenuPaths,
  ) {
    if (index == selectedIndex) return;
    final targetPath = currentMenuPaths[index];
    if (guard.shouldBlock) {
      _showUnsavedDialog(context, guard, targetPath);
    } else {
      context.go(targetPath);
    }
  }

  void _showUnsavedDialog(
    BuildContext context,
    NavigationGuard guard,
    String targetPath, {
    bool isMobile = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonUnsavedTitle),
        content: Text(l10n.commonUnsavedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonUnsavedStay),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              guard.onDiscard?.call();
              guard.clear();
              if (isMobile) {
                Navigator.of(context).pop();
              }
              context.go(targetPath);
            },
            child: Text(l10n.commonUnsavedLeave),
          ),
        ],
      ),
    );
  }

  String _mobileTitleForIndex(
    int index,
    AppLocalizations l10n, {
    required bool isAdmin,
  }) {
    final titles = [
      l10n.menuOrdersToday,
      l10n.menuOrdersHistory,
      l10n.menuClients,
      l10n.menuClientCategories,
      l10n.menuShippingMethods,
      l10n.menuProducts,
      l10n.menuInvoices,
      if (isAdmin) l10n.menuStatistics,
      l10n.menuSettings,
    ];
    return (index >= 0 && index < titles.length) ? titles[index] : '';
  }
}
