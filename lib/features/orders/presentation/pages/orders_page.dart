import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/router/router.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/presentation/widgets/page_header.dart';
import '../../../../core/utils/app_date_formats.dart';
import '../../../../core/utils/category_color_utils.dart';
import '../../../auth/domain/usecases/get_user_color.dart';
import '../../../auth/domain/usecases/get_user_name.dart';
import '../../../invoices/presentation/bloc/provisional_invoice_cubit.dart';
import '../../../invoices/presentation/bloc/provisional_invoice_state.dart';
import '../../../invoices/presentation/widgets/provisional_invoice_dialog.dart';
import '../bloc/orders_presence_cubit.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import '../bloc/orders_state.dart';
import '../widgets/multi_select_entity_dialog.dart';
import '../widgets/single_select_entity_dialog.dart';
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
import '../../domain/entities/order_sheet.dart';
import '../../domain/repositories/orders_presence_repository.dart';
import '../../domain/services/order_sheet_excel_generator.dart';
import '../../domain/usecases/get_today_orders.dart';
import '../../../client_categories/domain/usecases/get_client_categories.dart';
import '../../../clients/domain/usecases/get_clients.dart';
import '../../../../core/usecase/usecase.dart';
import '../widgets/client_category_filter_dialog.dart';
import '../widgets/orders_table.dart';
import '../widgets/orders_mobile_view.dart';
import '../widgets/order_date_selector_dialog.dart';

/// Default color hex for invoice user badge when no presence color is available.
const _kDefaultInvoiceColor = '#607D8B';

/// Index of this page inside [SideMenuShell].

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _isFirebaseAvailable = false;
  String? _resolvedUserName;
  Color? _resolvedUserColor;
  bool _userNameResolved = false;

  // Formatted date string — recomputed when BLoC's active date changes.
  String _formattedDate = '';

  String _formatDate(DateTime date) {
    final formattedDate = AppDateFormats.dateWithDay().format(date);
    return formattedDate[0].toUpperCase() + formattedDate.substring(1);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Widget _buildDateTitle(BuildContext context, AppLocalizations l10n) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final activeDate = _bloc?.activeDate ?? DateTime.now();
    final isToday = () {
      final now = DateTime.now();
      return activeDate.year == now.year &&
          activeDate.month == now.month &&
          activeDate.day == now.day;
    }();
    final headerLabel = isToday
        ? l10n.ordersDateSelectorToday
        : AppDateFormats.dayName().format(activeDate).toUpperCase();
    _formattedDate = _formatDate(activeDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headerLabel,
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
  OrdersBloc? _bloc;
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

    final result = await sl<GetUserName>()(GetUserNameParams(uid: uid));
    if (!mounted) return;

    // Resolve color in parallel-safe manner
    final colorResult = await sl<GetUserColor>()(GetUserColorParams(uid: uid));
    if (!mounted) return;
    colorResult.fold((_) {}, (colorHex) {
      _resolvedUserColor =
          tryParseHex(colorHex) ?? PresenceColors.palette.first;
    });

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

    final isMobile =
        MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint;

    // Firebase not available — show message (both mobile and desktop)
    if (!_isFirebaseAvailable) {
      if (isMobile) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
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
                  l10n.ordersNoFolderTitle,
                  style: textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.ordersNoFolderMessage,
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
                  Text(l10n.ordersNoFolderTitle, style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.ordersNoFolderMessage,
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
                    label: Text(l10n.ordersGoToSettings),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Initialize BLoC once (shared between mobile and desktop)
    _bloc ??= sl<OrdersBloc>()..add(const OrdersLoadRequested());

    // Mobile: read-only card view (no presence)
    if (isMobile) {
      return BlocProvider<OrdersBloc>.value(
        value: _bloc!,
        child: const OrdersMobileView(),
      );
    }

    // Desktop: full editing table with presence
    final hasPresence = sl.isRegistered<OrdersPresenceRepository>();

    Widget content = BlocProvider<OrdersBloc>.value(
      value: _bloc!,
      child: const _OrdersContent(),
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
          userColor: _resolvedUserColor ?? PresenceColors.palette.first,
          initialDateKey: _dateKey(_bloc?.activeDate ?? DateTime.now()),
          resolveUserColor: (remoteUid) async {
            final result = await sl<GetUserColor>()(
              GetUserColorParams(uid: remoteUid),
            );
            return result.getOrElse((_) => null);
          },
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

class _OrdersContent extends StatefulWidget {
  const _OrdersContent();

  @override
  State<_OrdersContent> createState() => _OrdersContentState();
}

class _OrdersContentState extends State<_OrdersContent> {
  bool _isExporting = false;
  Set<String> _selectedCategoryIds = {};
  Map<String, String?> _clientCategoryIdMap = const {};

  @override
  void initState() {
    super.initState();
    _loadClientCategoryMap();
  }

  Future<void> _loadClientCategoryMap() async {
    final result = await sl<GetClients>()(NoParams());
    result.fold((_) {}, (clients) {
      final map = <String, String?>{};
      for (final client in clients) {
        map[client.id] = client.clientCategoryId;
      }
      if (mounted) setState(() => _clientCategoryIdMap = map);
    });
  }

  Future<void> _openCategoryFilter(BuildContext context) async {
    final result = await sl<GetClientCategories>()(NoParams());
    if (!context.mounted) return;

    final categories = result.getOrElse((_) => []);
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (_) => ClientCategoryFilterDialog(
        categories: categories,
        selectedIds: _selectedCategoryIds,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedCategoryIds = selected);
    }
  }

  OrderSheet _buildFilteredOrderSheet(OrderSheet sheet, List<int> indices) {
    return sheet.copyWith(
      clients: [for (final i in indices) sheet.clients[i]],
      clientIds: [for (final i in indices) sheet.clientIds[i]],
      clientOrders: [for (final i in indices) sheet.clientOrders[i]],
      quantities: [
        for (final row in sheet.quantities) [for (final i in indices) row[i]],
      ],
      cellFlags: [
        for (final flagRow in sheet.cellFlags)
          {
            for (final i in indices)
              if (i < sheet.clientIds.length &&
                  flagRow.containsKey(sheet.clientIds[i]))
                sheet.clientIds[i]: flagRow[sheet.clientIds[i]]!,
          },
      ],
      cellNotes: [
        for (final noteRow in sheet.cellNotes)
          {
            for (final i in indices)
              if (i < sheet.clientIds.length &&
                  noteRow.containsKey(sheet.clientIds[i]))
                sheet.clientIds[i]: noteRow[sheet.clientIds[i]]!,
          },
      ],
      cellRefunds: [
        for (final refundRow in sheet.cellRefunds)
          {
            for (final i in indices)
              if (i < sheet.clientIds.length &&
                  refundRow.containsKey(sheet.clientIds[i]))
                sheet.clientIds[i]: refundRow[sheet.clientIds[i]]!,
          },
      ],
      invoicedBy: {
        for (final i in indices)
          if (i < sheet.clientIds.length &&
              sheet.invoicedBy.containsKey(sheet.clientIds[i]))
            sheet.clientIds[i]: sheet.invoicedBy[sheet.clientIds[i]]!,
      },
      clientNotes: {
        for (final i in indices)
          if (i < sheet.clientIds.length &&
              sheet.clientNotes.containsKey(sheet.clientIds[i]))
            sheet.clientIds[i]: sheet.clientNotes[sheet.clientIds[i]]!,
      },
    );
  }

  Future<void> _exportExcel(BuildContext context, OrdersLoaded state) async {
    setState(() => _isExporting = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final sheet = state.orderSheet;
      final filteredIndices = _computeFilteredClientIndices(sheet);
      final exportSheet = filteredIndices.length == sheet.clients.length
          ? sheet
          : _buildFilteredOrderSheet(sheet, filteredIndices);
      final bytes = await sl<OrderSheetExcelGenerator>().generate(
        orderSheet: exportSheet,
        sheetName: l10n.ordersExcelSheetName,
      );
      final fileName = 'Pedidos_${sheet.date}.xlsx';

      if (!context.mounted) return;

      _downloadOnWeb(bytes, fileName);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.ordersExportExcelSuccess)));
      }
    } on Exception catch (e, st) {
      sl<AppLogger>().error('Error exporting Excel', e, st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.ordersExportExcelError),
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

  List<int> _computeFilteredClientIndices(OrderSheet sheet) {
    if (_selectedCategoryIds.isEmpty) {
      return List.generate(sheet.clients.length, (i) => i);
    }
    final indices = <int>[];
    for (var i = 0; i < sheet.clientIds.length; i++) {
      final catId = _clientCategoryIdMap[sheet.clientIds[i]];
      if (catId != null && _selectedCategoryIds.contains(catId)) {
        indices.add(i);
      } else if (catId == null && _selectedCategoryIds.contains(noCategoryId)) {
        indices.add(i);
      }
    }
    return indices;
  }

  Future<void> _openDateSelector(BuildContext context) async {
    final bloc = context.read<OrdersBloc>();
    final getTodayOrders = sl<GetTodayOrders>();
    final selectedDate = await showOrderDateSelectorDialog(
      context,
      currentDate: bloc.activeDate,
      onFetchClientCount: (date) async {
        final result = await getTodayOrders(GetTodayOrdersParams(date: date));
        return result.fold((_) => null, (sheet) => sheet?.clients.length);
      },
    );
    if (selectedDate == null || !context.mounted) return;

    bloc.add(OrdersDateChanged(date: selectedDate));

    // Re-init presence cubit on the new date
    final newDateKey =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    try {
      context.read<OrdersPresenceCubit>().switchDate(newDateKey);
    } catch (_) {
      // Presence cubit may not be available
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType || previous != current,
      builder: (context, state) {
        final mainContent = switch (state) {
          OrdersInitial() ||
          OrdersLoading() => const Center(child: CircularProgressIndicator()),
          OrdersCreating() => const OrdersPreparingState(),
          OrdersNoFile() => OrdersEmptyState(
            onCreateFile: () => context.read<OrdersBloc>().add(
              const OrdersCreateFileRequested(),
            ),
          ),
          OrdersError(:final errorType) => OrdersErrorState(
            errorType: errorType,
            onRetry: () =>
                context.read<OrdersBloc>().add(const OrdersRefreshRequested()),
          ),
          OrdersLoaded(:final orderSheet, :final activeDate) => OrdersTable(
            orderSheet: orderSheet,
            selectedDate: activeDate,
            selectedCategoryIds: _selectedCategoryIds,
            clientCategoryIdMap: _clientCategoryIdMap,
            onDateSelectorTap: () => _openDateSelector(context),
            footerTrailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: () => _openCategoryFilter(context),
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text(
                    _selectedCategoryIds.isNotEmpty
                        ? '${AppLocalizations.of(context)!.ordersFilterClients} (${_selectedCategoryIds.length})'
                        : AppLocalizations.of(context)!.ordersFilterClients,
                  ),
                ),
                const SizedBox(width: 8),
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
                  label: Text(AppLocalizations.of(context)!.ordersExportExcel),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    openUrlInNewTab(AppRoutes.ordersView);
                  },
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_full),
                  tooltip: AppLocalizations.of(context)!.ordersShowPreview,
                ),
              ],
            ),
            onCellUpdated: (productRow, clientCol, value) {
              context.read<OrdersBloc>().add(
                OrdersCellUpdateRequested(
                  productRow: productRow,
                  clientCol: clientCol,
                  value: value,
                ),
              );
            },
            onCellFlagUpdated: (productRow, clientCol, flagType) {
              context.read<OrdersBloc>().add(
                OrdersCellFlagUpdateRequested(
                  productRow: productRow,
                  clientCol: clientCol,
                  flagType: flagType,
                ),
              );
            },
            onCellNoteUpdated: (productRow, clientCol, note) {
              context.read<OrdersBloc>().add(
                OrdersCellNoteUpdateRequested(
                  productRow: productRow,
                  clientCol: clientCol,
                  note: note,
                ),
              );
            },
            onCellRefundUpdated: (productRow, clientCol, quantity) {
              context.read<OrdersBloc>().add(
                OrdersCellRefundUpdateRequested(
                  productRow: productRow,
                  clientCol: clientCol,
                  quantity: quantity,
                ),
              );
            },
            onDeleteClients: (indices) {
              context.read<OrdersBloc>().add(
                OrdersRemoveClientsRequested(clientIndices: indices),
              );
            },
            onDeleteProducts: (indices) {
              context.read<OrdersBloc>().add(
                OrdersRemoveProductsRequested(productIndices: indices),
              );
            },
            onResetOrders: (indices) {
              context.read<OrdersBloc>().add(
                OrdersResetOrdersRequested(clientIndices: indices),
              );
            },
            onAddClient: () async {
              final bloc = context.read<OrdersBloc>();
              final available = await bloc.getAvailableClients();
              if (!context.mounted) return;
              final l10n = AppLocalizations.of(context)!;
              final selected = await showDialog<List<String>>(
                context: context,
                builder: (_) => MultiSelectEntityDialog(
                  title: l10n.ordersAddClientDialogTitle,
                  items: available,
                  emptyIcon: Icons.person_off_outlined,
                ),
              );
              if (selected != null && selected.isNotEmpty && context.mounted) {
                context.read<OrdersBloc>().add(
                  OrdersAddClientsRequested(clientIds: selected),
                );
              }
            },
            onAddProduct: () async {
              final bloc = context.read<OrdersBloc>();
              final available = await bloc.getAvailableProducts();
              if (!context.mounted) return;
              final l10n = AppLocalizations.of(context)!;
              final selected = await showDialog<List<String>>(
                context: context,
                builder: (_) => MultiSelectEntityDialog(
                  title: l10n.ordersAddProductDialogTitle,
                  items: available,
                  emptyIcon: Icons.inventory_2_outlined,
                ),
              );
              if (selected != null && selected.isNotEmpty && context.mounted) {
                context.read<OrdersBloc>().add(
                  OrdersAddProductsRequested(productIds: selected),
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

              final bloc = context.read<OrdersBloc>();

              // Listen for success to save invoicedBy via BLoC
              StreamSubscription<ProvisionalInvoiceState>? invoiceSub;
              invoiceSub = cubit.stream.listen((cubitState) {
                if (cubitState is ProvisionalInvoiceSuccess) {
                  invoiceSub?.cancel();
                  bloc.add(
                    OrdersSaveInvoicedByRequested(
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
            onClientNoteUpdated: (clientCol, note) {
              context.read<OrdersBloc>().add(
                OrdersClientNoteUpdateRequested(
                  clientCol: clientCol,
                  note: note,
                ),
              );
            },
            onChangeClient: (col) async {
              final bloc = context.read<OrdersBloc>();
              final available = await bloc.getAvailableClients();
              if (!context.mounted) return;
              final l10n = AppLocalizations.of(context)!;
              final selected = await showDialog<String>(
                context: context,
                builder: (_) => SingleSelectEntityDialog(
                  title: l10n.ordersChangeClientDialogTitle,
                  items: available,
                  emptyIcon: Icons.person_off_outlined,
                  confirmLabel: l10n.ordersChangeClientDialogConfirm,
                ),
              );
              if (selected != null && context.mounted) {
                context.read<OrdersBloc>().add(
                  OrdersReplaceClientRequested(
                    clientCol: col,
                    newClientId: selected,
                  ),
                );
              }
            },
          ),
        };

        // Cuando hay datos, el botón ya está en el footer
        return mainContent;
      },
    );
  }
}
