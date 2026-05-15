import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/router/router.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/presentation/widgets/page_header.dart';
import '../../../../core/utils/app_date_formats.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../invoices/presentation/bloc/provisional_invoice_cubit.dart';
import '../../../invoices/presentation/bloc/provisional_invoice_state.dart';
import '../../../invoices/presentation/widgets/provisional_invoice_dialog.dart';
import '../bloc/orders_presence_cubit.dart';
import '../bloc/orders_today_bloc.dart';
import '../bloc/orders_today_event.dart';
import '../bloc/orders_today_state.dart';
import '../widgets/multi_select_entity_dialog.dart';
import '../widgets/orders_empty_state.dart';
import '../widgets/orders_error_state.dart';
import '../widgets/orders_preparing_state.dart';
import '../../../../core/log/app_logger.dart';
import '../../../../core/utils/web_download_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) '../../../../core/utils/web_download_web.dart';
import '../../../../core/utils/web_open_url_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) '../../../../core/utils/web_open_url_web.dart';
import '../../domain/repositories/orders_presence_repository.dart';
import '../../domain/services/order_sheet_excel_generator.dart';
import '../../domain/entities/order_action_entry.dart';
import '../../domain/usecases/get_action_history.dart';
import '../widgets/order_action_history_dialog.dart';
import '../widgets/orders_table.dart';

/// Default color hex for invoice user badge when no presence color is available.
const _kDefaultInvoiceColor = '#607D8B';

/// Index of this page inside [SideMenuShell].

class OrdersTodayPage extends StatefulWidget {
  const OrdersTodayPage({super.key});

  @override
  State<OrdersTodayPage> createState() => _OrdersTodayPageState();
}

class _OrdersTodayPageState extends State<OrdersTodayPage> {
  bool _isFirebaseAvailable = false;
  String? _resolvedUserName;
  bool _userNameResolved = false;

  // Cached date string — the day doesn't change during widget lifetime.
  late final String _formattedDate = () {
    final now = DateTime.now();
    final formattedDate = AppDateFormats.dateWithDay().format(now);
    return formattedDate[0].toUpperCase() + formattedDate.substring(1);
  }();

  Widget _buildDateTitle(BuildContext context, AppLocalizations l10n) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.ordersTodayHeaderLabel,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          _formattedDate,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // BLoC instances created once and reused across rebuilds
  OrdersTodayBloc? _bloc;
  OrdersPresenceCubit? _presenceCubit;

  @override
  void initState() {
    super.initState();
    _checkFirebaseAvailable();
    _resolveUserName();
  }

  Future<void> _resolveUserName() async {
    final firebaseAuth = sl<FirebaseAuth>();
    final uid = firebaseAuth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _userNameResolved = true);
      return;
    }

    final result = await sl<AuthRepository>().getUserName(uid);
    if (!mounted) return;
    result.fold(
      (_) {
        setState(() => _userNameResolved = true);
      },
      (name) {
        if (name != null && name.isNotEmpty) {
          // Close stale cubit so it's recreated with the resolved userName
          _presenceCubit?.close();
          _presenceCubit = null;
          setState(() {
            _resolvedUserName = name;
            _userNameResolved = true;
          });
        } else {
          setState(() => _userNameResolved = true);
        }
      },
    );
  }

  @override
  void dispose() {
    _bloc?.close();
    _presenceCubit?.close();
    super.dispose();
  }

  void _checkFirebaseAvailable() {
    final available =
        sl.isRegistered<bool>(instanceName: 'firebaseAvailable') &&
        sl<bool>(instanceName: 'firebaseAvailable');
    if (!mounted) return;
    setState(() => _isFirebaseAvailable = available);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Mobile placeholder
    final isMobile =
        MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint;
    if (isMobile) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.desktop_windows_outlined,
                size: AppIconSizes.xl,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.ordersTodayMobileTitle,
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.ordersTodayMobileDescription,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isFirebaseAvailable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(titleWidget: _buildDateTitle(context, l10n)),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: AppIconSizes.xl,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.ordersTodayNoFolderTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.ordersTodayNoFolderMessage,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () {
                      context.go(AppRoutes.settings);
                    },
                    icon: const Icon(Icons.settings_rounded),
                    label: Text(l10n.ordersTodayGoToSettings),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final hasPresence = sl.isRegistered<OrdersPresenceRepository>();

    _bloc ??= sl<OrdersTodayBloc>()..add(const OrdersTodayLoadRequested());

    Widget content = BlocProvider<OrdersTodayBloc>.value(
      value: _bloc!,
      child: const _OrdersTodayContent(),
    );

    if (hasPresence && _userNameResolved) {
      _presenceCubit ??= () {
        final firebaseAuth = sl<FirebaseAuth>();
        final currentUser = firebaseAuth.currentUser;
        final uid = currentUser?.uid ?? 'anonymous';
        final email = currentUser?.email ?? uid;
        return OrdersPresenceCubit(
          repository: sl<OrdersPresenceRepository>(),
          userId: uid,
          userName: _resolvedUserName ?? email,
        )..init();
      }();
      content = BlocProvider<OrdersPresenceCubit>.value(
        value: _presenceCubit!,
        child: content,
      );
    }

    return content;
  }
}

class _OrdersTodayContent extends StatefulWidget {
  const _OrdersTodayContent();

  @override
  State<_OrdersTodayContent> createState() => _OrdersTodayContentState();
}

class _OrdersTodayContentState extends State<_OrdersTodayContent> {
  bool _isExporting = false;

  bool _isAdmin(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    return authState is AuthAuthenticated && authState.user.isAdmin;
  }

  Future<void> _exportExcel(
    BuildContext context,
    OrdersTodayLoaded state,
  ) async {
    setState(() => _isExporting = true);
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = _isAdmin(context);
    try {
      final history = isAdmin
          ? (await sl<GetActionHistory>()(
              GetActionHistoryParams(date: DateTime.now()),
            )).getOrElse((_) => [])
          : <OrderActionEntry>[];

      final bytes = await sl<OrderSheetExcelGenerator>().generate(
        orderSheet: state.orderSheet,
        history: history,
      );
      final fileName = 'Pedidos_${state.orderSheet.date}.xlsx';

      if (!context.mounted) return;

      _downloadOnWeb(bytes, fileName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.ordersTodayExportExcelSuccess)),
        );
      }
    } on Exception catch (e, st) {
      sl<AppLogger>().error('Error exporting Excel', e, st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.ordersTodayExportExcelError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ignore: avoid_web_libraries_in_flutter
  void _downloadOnWeb(List<int> bytes, String fileName) {
    downloadFileOnWeb(bytes, fileName);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersTodayBloc, OrdersTodayState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType || previous != current,
      builder: (context, state) {
        final mainContent = switch (state) {
          OrdersTodayInitial() || OrdersTodayLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          OrdersTodayCreating() => const OrdersPreparingState(),
          OrdersTodayNoFile() => OrdersEmptyState(
            onCreateFile: () => context.read<OrdersTodayBloc>().add(
              const OrdersTodayCreateFileRequested(),
            ),
          ),
          OrdersTodayError(:final errorType) => OrdersErrorState(
            errorType: errorType,
            onRetry: () => context.read<OrdersTodayBloc>().add(
              const OrdersTodayRefreshRequested(),
            ),
          ),
          OrdersTodayLoaded(:final orderSheet) => OrdersTable(
            orderSheet: orderSheet,
            footerTrailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _isExporting
                      ? null
                      : () => _exportExcel(context, state),
                  icon: _isExporting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.surface,
                            ),
                          ),
                        )
                      : const Icon(Icons.table_chart_outlined, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!.ordersTodayExportExcel,
                  ),
                ),
                const SizedBox(width: 8),
                if (_isAdmin(context)) ...[
                  IconButton.filled(
                    onPressed: () {
                      OrderActionHistoryDialog.show(
                        context,
                        getActionHistory: sl<GetActionHistory>(),
                        date: DateTime.now(),
                      );
                    },
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.history),
                    tooltip: AppLocalizations.of(
                      context,
                    )!.ordersTodayHistoryButton,
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton.filled(
                  onPressed: () {
                    openUrlInNewTab(AppRoutes.ordersTodayView);
                  },
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_full),
                  tooltip: AppLocalizations.of(context)!.ordersTodayShowPreview,
                ),
              ],
            ),
            onCellUpdated: (productRow, clientCol, value) {
              context.read<OrdersTodayBloc>().add(
                OrdersTodayCellUpdateRequested(
                  productRow: productRow,
                  clientCol: clientCol,
                  value: value,
                ),
              );
            },
            onCellFlagUpdated: (productRow, clientCol, flagType) {
              context.read<OrdersTodayBloc>().add(
                OrdersTodayCellFlagUpdateRequested(
                  productRow: productRow,
                  clientCol: clientCol,
                  flagType: flagType,
                ),
              );
            },
            onCellNoteUpdated: (productRow, clientCol, note) {
              context.read<OrdersTodayBloc>().add(
                OrdersTodayCellNoteUpdateRequested(
                  productRow: productRow,
                  clientCol: clientCol,
                  note: note,
                ),
              );
            },
            onCellRefundUpdated: (productRow, clientCol, quantity) {
              context.read<OrdersTodayBloc>().add(
                OrdersTodayCellRefundUpdateRequested(
                  productRow: productRow,
                  clientCol: clientCol,
                  quantity: quantity,
                ),
              );
            },
            onDeleteClients: (indices) {
              context.read<OrdersTodayBloc>().add(
                OrdersTodayRemoveClientsRequested(clientIndices: indices),
              );
            },
            onDeleteProducts: (indices) {
              context.read<OrdersTodayBloc>().add(
                OrdersTodayRemoveProductsRequested(productIndices: indices),
              );
            },
            onResetOrders: (indices) {
              context.read<OrdersTodayBloc>().add(
                OrdersTodayResetOrdersRequested(clientIndices: indices),
              );
            },
            onAddClient: () async {
              final bloc = context.read<OrdersTodayBloc>();
              final available = await bloc.getAvailableClients();
              if (!context.mounted) return;
              final l10n = AppLocalizations.of(context)!;
              final selected = await showDialog<List<String>>(
                context: context,
                builder: (_) => MultiSelectEntityDialog(
                  title: l10n.ordersTodayAddClientDialogTitle,
                  items: available,
                  emptyIcon: Icons.person_off_outlined,
                ),
              );
              if (selected != null && selected.isNotEmpty && context.mounted) {
                context.read<OrdersTodayBloc>().add(
                  OrdersTodayAddClientsRequested(clientIds: selected),
                );
              }
            },
            onAddProduct: () async {
              final bloc = context.read<OrdersTodayBloc>();
              final available = await bloc.getAvailableProducts();
              if (!context.mounted) return;
              final l10n = AppLocalizations.of(context)!;
              final selected = await showDialog<List<String>>(
                context: context,
                builder: (_) => MultiSelectEntityDialog(
                  title: l10n.ordersTodayAddProductDialogTitle,
                  items: available,
                  emptyIcon: Icons.inventory_2_outlined,
                ),
              );
              if (selected != null && selected.isNotEmpty && context.mounted) {
                context.read<OrdersTodayBloc>().add(
                  OrdersTodayAddProductsRequested(productIds: selected),
                );
              }
            },
            onGenerateProvisionalInvoice: (col) {
              final orderSheet = state.orderSheet;
              final clientId = col < orderSheet.clientIds.length
                  ? orderSheet.clientIds[col]
                  : '';
              if (clientId.isEmpty) return;

              final productIds = orderSheet.productIds;
              final quantities = <num>[
                for (var p = 0; p < orderSheet.products.length; p++)
                  orderSheet.quantities[p][col],
              ];

              final refunds = <num>[
                for (var p = 0; p < orderSheet.products.length; p++)
                  p < orderSheet.cellRefunds.length
                      ? (orderSheet.cellRefunds[p][clientId] ?? 0)
                      : 0,
              ];

              final cubit = sl<ProvisionalInvoiceCubit>();

              // Capture user info before async listener
              final firebaseAuth = sl<FirebaseAuth>();
              final uid = firebaseAuth.currentUser?.uid ?? 'anonymous';
              OrdersPresenceCubit? presenceCubit;
              try {
                presenceCubit = context.read<OrdersPresenceCubit>();
              } catch (_) {
                // Presence cubit not available
              }
              final invoiceUserName =
                  presenceCubit?.userName ??
                  firebaseAuth.currentUser?.email ??
                  uid;
              final invoiceColorValue = presenceCubit?.myColor;
              final invoiceColor = invoiceColorValue != null
                  ? '#${invoiceColorValue.toARGB32().toRadixString(16).substring(2).toUpperCase()}'
                  : _kDefaultInvoiceColor;

              final bloc = context.read<OrdersTodayBloc>();

              // Listen for success to save invoicedBy via BLoC
              StreamSubscription<ProvisionalInvoiceState>? invoiceSub;
              invoiceSub = cubit.stream.listen((cubitState) {
                if (cubitState is ProvisionalInvoiceSuccess) {
                  invoiceSub?.cancel();
                  bloc.add(
                    OrdersTodaySaveInvoicedByRequested(
                      clientId: clientId,
                      userId: uid,
                      userName: invoiceUserName,
                      color: invoiceColor,
                    ),
                  );
                }
              });

              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => ProvisionalInvoiceDialog(
                  cubit: cubit,
                  clientId: clientId,
                  date: orderSheet.date,
                  productIds: productIds,
                  quantities: quantities,
                  refunds: refunds,
                ),
              ).whenComplete(() {
                invoiceSub?.cancel();
                cubit.close();
              });
            },
          ),
        };

        // Cuando hay datos, el botón ya está en el footer
        return mainContent;
      },
    );
  }
}
