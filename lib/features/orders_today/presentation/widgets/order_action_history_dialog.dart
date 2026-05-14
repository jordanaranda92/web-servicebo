import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../domain/entities/order_action_entry.dart';
import '../../domain/usecases/get_action_history.dart';

class OrderActionHistoryDialog extends StatelessWidget {
  const OrderActionHistoryDialog({
    required this.getActionHistory,
    required this.date,
    required this.firestore,
    super.key,
  });

  final GetActionHistory getActionHistory;
  final DateTime date;
  final FirebaseFirestore firestore;

  static Future<void> show(
    BuildContext context, {
    required GetActionHistory getActionHistory,
    required DateTime date,
    required FirebaseFirestore firestore,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => OrderActionHistoryDialog(
        getActionHistory: getActionHistory,
        date: date,
        firestore: firestore,
      ),
    );
  }

  /// Reads history + users + clients + products in parallel (one-shot).
  Future<_HistoryData> _loadData() async {
    final results = await Future.wait([
      getActionHistory(GetActionHistoryParams(date: date)),
      firestore.collection('users').get(),
      firestore.collection('clients').get(),
      firestore.collection('products').get(),
    ]);

    final historyResult = results[0] as dynamic;
    final usersSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final clientsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final productsSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

    final entries =
        historyResult.getOrElse((_) => <OrderActionEntry>[])
            as List<OrderActionEntry>;

    final userNames = <String, String>{};
    for (final doc in usersSnap.docs) {
      final name = doc.data()['userName'] as String?;
      if (name != null) userNames[doc.id] = name;
    }

    final clientNames = <String, String>{};
    for (final doc in clientsSnap.docs) {
      final name = doc.data()['name'] as String?;
      if (name != null) clientNames[doc.id] = name;
    }

    final productNames = <String, String>{};
    for (final doc in productsSnap.docs) {
      final name = doc.data()['name'] as String?;
      if (name != null) productNames[doc.id] = name;
    }

    return _HistoryData(
      entries: entries,
      userNames: userNames,
      clientNames: clientNames,
      productNames: productNames,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.ordersTodayHistoryTitle),
      content: SizedBox(
        width: 520,
        height: 480,
        child: FutureBuilder<_HistoryData>(
          future: _loadData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: Text(l10n.ordersTodayHistoryLoading));
            }

            if (snapshot.hasError) {
              return Center(child: Text(l10n.ordersTodayHistoryError));
            }

            final data = snapshot.data!;
            if (data.entries.isEmpty) {
              return Center(child: Text(l10n.ordersTodayHistoryEmpty));
            }
            return _HistoryList(
              entries: data.entries,
              userNames: data.userNames,
              clientNames: data.clientNames,
              productNames: data.productNames,
              l10n: l10n,
            );
          },
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ordersTodayHistoryClose),
        ),
      ],
    );
  }
}

class _HistoryData {
  const _HistoryData({
    required this.entries,
    required this.userNames,
    required this.clientNames,
    required this.productNames,
  });

  final List<OrderActionEntry> entries;
  final Map<String, String> userNames;
  final Map<String, String> clientNames;
  final Map<String, String> productNames;
}

class _HistoryList extends StatefulWidget {
  const _HistoryList({
    required this.entries,
    required this.userNames,
    required this.clientNames,
    required this.productNames,
    required this.l10n,
  });

  final List<OrderActionEntry> entries;
  final Map<String, String> userNames;
  final Map<String, String> clientNames;
  final Map<String, String> productNames;
  final AppLocalizations l10n;

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  final _selectedActions = <OrderActionType>{};
  final _selectedUserIds = <String>{};
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<OrderActionEntry> get _filteredEntries {
    return widget.entries.where((e) {
      if (_selectedActions.isNotEmpty &&
          !_selectedActions.contains(e.actionType)) {
        return false;
      }
      if (_selectedUserIds.isNotEmpty && !_selectedUserIds.contains(e.userId)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Returns only the action types present in the entries.
  Set<OrderActionType> get _availableActions =>
      widget.entries.map((e) => e.actionType).toSet();

  /// Returns only the user IDs present in the entries.
  Map<String, String> get _availableUsers {
    final map = <String, String>{};
    for (final entry in widget.entries) {
      if (!map.containsKey(entry.userId)) {
        map[entry.userId] = widget.userNames[entry.userId] ?? entry.userName;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = widget.l10n;
    final timeFormat = DateFormat('HH:mm:ss');
    final filtered = _filteredEntries;
    final availableActions = _availableActions;
    final availableUsers = _availableUsers;

    return Column(
      children: [
        // ── Filters ──
        _buildFilters(theme, l10n, availableActions, availableUsers),
        const SizedBox(height: 8),
        // ── Timeline ──
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(l10n.ordersTodayHistoryEmpty))
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ScrollbarTheme(
                    data: ScrollbarThemeData(
                      thumbColor: WidgetStatePropertyAll(
                        theme.colorScheme.primary,
                      ),
                      thickness: const WidgetStatePropertyAll(6),
                      radius: const Radius.circular(3),
                    ),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: filtered.length,
                        padding: const EdgeInsets.only(
                          top: 8,
                          bottom: 8,
                          left: 8,
                          right: 16,
                        ),
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          final isLast = index == filtered.length - 1;
                          final detailStr = _formatDetails(entry);

                          final actionColor = _colorForAction(entry.actionType);

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Timeline rail ──
                                SizedBox(
                                  width: 36,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        margin: const EdgeInsets.only(top: 2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: actionColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          border: Border.all(
                                            color: actionColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          _iconForAction(entry.actionType),
                                          size: 14,
                                          color: actionColor,
                                        ),
                                      ),
                                      if (!isLast)
                                        Expanded(
                                          child: Container(
                                            width: 2,
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            color: theme
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // ── Content card ──
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: theme
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color:
                                                      theme.colorScheme.outline,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  timeFormat.format(
                                                    entry.timestamp,
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .outline,
                                                      ),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(
                                                  Icons.person_outline,
                                                  size: 14,
                                                  color:
                                                      theme.colorScheme.outline,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    widget.userNames[entry
                                                            .userId] ??
                                                        entry.userName,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .outline,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: actionColor.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _localizedAction(
                                                  entry.actionType,
                                                  l10n,
                                                ),
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: actionColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            if (detailStr.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                detailStr,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilters(
    ThemeData theme,
    AppLocalizations l10n,
    Set<OrderActionType> availableActions,
    Map<String, String> availableUsers,
  ) {
    final actionLabel = _selectedActions.isEmpty
        ? 'Todas las acciones'
        : _selectedActions.length == 1
        ? _localizedAction(_selectedActions.first, l10n)
        : '${_selectedActions.length} acciones';

    final userLabel = _selectedUserIds.isEmpty
        ? 'Todos los usuarios'
        : _selectedUserIds.length == 1
        ? availableUsers[_selectedUserIds.first] ?? ''
        : '${_selectedUserIds.length} usuarios';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (availableUsers.length > 1) ...[
          _MultiSelectDropdown<String>(
            label: userLabel,
            icon: Icons.person_outline,
            items: availableUsers.keys.toList(),
            selectedItems: _selectedUserIds,
            itemLabel: (id) => availableUsers[id] ?? id,
            onChanged: (selected) => setState(() {
              _selectedUserIds
                ..clear()
                ..addAll(selected);
            }),
          ),
          const SizedBox(height: 8),
        ],
        _MultiSelectDropdown<OrderActionType>(
          label: actionLabel,
          icon: Icons.filter_list,
          items: availableActions.toList(),
          selectedItems: _selectedActions,
          itemLabel: (type) => _localizedAction(type, l10n),
          itemColor: _colorForAction,
          onChanged: (selected) => setState(() {
            _selectedActions
              ..clear()
              ..addAll(selected);
          }),
        ),
      ],
    );
  }

  static const _detailLabels = <String, String>{
    'clientCount': 'Clientes',
    'productCount': 'Productos',
    'clientIds': 'Clientes',
    'productIds': 'Productos',
    'productId': 'Producto',
    'clientId': 'Cliente',
    'oldValue': 'Anterior',
    'newValue': 'Nuevo valor',
  };

  static String _detailLabel(String key) => _detailLabels[key] ?? key;

  String _formatDetails(OrderActionEntry entry) {
    final d = entry.details;
    if (entry.actionType == OrderActionType.quantityChanged) {
      return [
        'Cliente: ${_resolveValue('clientId', d['clientId'] ?? '')}',
        'Producto: ${_resolveValue('productId', d['productId'] ?? '')}',
        'Cantidad anterior: ${d['oldValue'] ?? '0'}',
        'Cantidad nueva: ${d['newValue'] ?? ''}',
      ].join('\n');
    }
    if (entry.actionType == OrderActionType.stockChanged) {
      return [
        'Producto: ${_resolveValue('productId', d['productId'] ?? '')}',
        'Stock anterior: ${d['oldValue'] ?? '0'}',
        'Stock nuevo: ${d['newValue'] ?? ''}',
      ].join('\n');
    }
    if (entry.actionType == OrderActionType.compensationMarked ||
        entry.actionType == OrderActionType.compensationUnmarked ||
        entry.actionType == OrderActionType.reservationMarked ||
        entry.actionType == OrderActionType.reservationUnmarked) {
      return [
        'Cliente: ${_resolveValue('clientId', d['clientId'] ?? '')}',
        'Producto: ${_resolveValue('productId', d['productId'] ?? '')}',
      ].join('\n');
    }
    if (entry.actionType == OrderActionType.refundAdded ||
        entry.actionType == OrderActionType.refundEdited ||
        entry.actionType == OrderActionType.refundRemoved) {
      final lines = [
        'Cliente: ${_resolveValue('clientId', d['clientId'] ?? '')}',
        'Producto: ${_resolveValue('productId', d['productId'] ?? '')}',
      ];
      if (entry.actionType != OrderActionType.refundRemoved) {
        lines.add('Cantidad: ${d['quantity'] ?? d['newValue'] ?? ''}');
      }
      return lines.join('\n');
    }
    if (entry.actionType == OrderActionType.clientsAdded ||
        entry.actionType == OrderActionType.clientsRemoved) {
      return 'Cliente: ${_resolveValue('clientIds', d['clientIds'] ?? '')}';
    }
    return d.entries
        .map((e) => '${_detailLabel(e.key)}: ${_resolveValue(e.key, e.value)}')
        .join(', ');
  }

  /// Resolves comma-separated IDs to names for client/product fields.
  String _resolveValue(String key, String value) {
    if (key == 'clientIds' || key == 'clientId') {
      return _resolveIds(value, widget.clientNames);
    }
    if (key == 'productIds' || key == 'productId') {
      return _resolveIds(value, widget.productNames);
    }
    return value;
  }

  static String _resolveIds(String csv, Map<String, String> nameMap) {
    return csv
        .split(',')
        .map((id) => nameMap[id.trim()] ?? id.trim())
        .join(', ');
  }

  static IconData _iconForAction(OrderActionType type) {
    return switch (type) {
      OrderActionType.quantityChanged => Icons.edit,
      OrderActionType.stockChanged => Icons.inventory,
      OrderActionType.compensationMarked ||
      OrderActionType.compensationUnmarked => Icons.swap_horiz,
      OrderActionType.reservationMarked ||
      OrderActionType.reservationUnmarked => Icons.bookmark,
      OrderActionType.strictStockMarked ||
      OrderActionType.strictStockUnmarked => Icons.lock,
      OrderActionType.refundAdded ||
      OrderActionType.refundEdited ||
      OrderActionType.refundRemoved => Icons.undo,
      OrderActionType.ordersReset => Icons.restart_alt,
      OrderActionType.clientsAdded ||
      OrderActionType.clientsRemoved => Icons.people,
      OrderActionType.productsAdded ||
      OrderActionType.productsRemoved => Icons.inventory_2,
      OrderActionType.orderSheetCreated => Icons.note_add,
      OrderActionType.orderSheetGenerated => Icons.table_chart,
      OrderActionType.provisionalInvoiceGenerated => Icons.receipt,
    };
  }

  static Color _colorForAction(OrderActionType type) {
    return switch (type) {
      OrderActionType.quantityChanged => const Color(0xFF1976D2), // blue
      OrderActionType.stockChanged => const Color(0xFF00838F), // teal
      OrderActionType.compensationMarked ||
      OrderActionType.compensationUnmarked => const Color(0xFF7B1FA2), // purple
      OrderActionType.reservationMarked ||
      OrderActionType.reservationUnmarked => const Color(
        0xFF0277BD,
      ), // light blue
      OrderActionType.strictStockMarked ||
      OrderActionType.strictStockUnmarked => const Color(0xFF4E342E), // brown
      OrderActionType.refundAdded ||
      OrderActionType.refundEdited ||
      OrderActionType.refundRemoved => const Color(0xFFC62828), // red
      OrderActionType.ordersReset => const Color(0xFFE65100), // deep orange
      OrderActionType.clientsAdded => const Color(0xFF2E7D32), // green
      OrderActionType.clientsRemoved => const Color(0xFFAD1457), // pink
      OrderActionType.productsAdded => const Color(0xFF558B2F), // light green
      OrderActionType.productsRemoved => const Color(0xFF6A1B9A), // deep purple
      OrderActionType.orderSheetCreated => const Color(0xFF00695C), // teal dark
      OrderActionType.orderSheetGenerated => const Color(0xFF283593), // indigo
      OrderActionType.provisionalInvoiceGenerated => const Color(
        0xFFF57F17,
      ), // amber dark
    };
  }

  String _localizedAction(OrderActionType type, AppLocalizations l10n) {
    return switch (type) {
      OrderActionType.quantityChanged => l10n.orderActionQuantityChanged,
      OrderActionType.stockChanged => l10n.orderActionStockChanged,
      OrderActionType.compensationMarked => l10n.orderActionCompensationMarked,
      OrderActionType.compensationUnmarked =>
        l10n.orderActionCompensationUnmarked,
      OrderActionType.reservationMarked => l10n.orderActionReservationMarked,
      OrderActionType.reservationUnmarked =>
        l10n.orderActionReservationUnmarked,
      OrderActionType.strictStockMarked => l10n.orderActionStrictStockMarked,
      OrderActionType.strictStockUnmarked =>
        l10n.orderActionStrictStockUnmarked,
      OrderActionType.refundAdded => l10n.orderActionRefundAdded,
      OrderActionType.refundEdited => l10n.orderActionRefundEdited,
      OrderActionType.refundRemoved => l10n.orderActionRefundRemoved,
      OrderActionType.ordersReset => l10n.orderActionOrdersReset,
      OrderActionType.clientsAdded => l10n.orderActionClientsAdded,
      OrderActionType.clientsRemoved => l10n.orderActionClientsRemoved,
      OrderActionType.productsAdded => l10n.orderActionProductsAdded,
      OrderActionType.productsRemoved => l10n.orderActionProductsRemoved,
      OrderActionType.orderSheetCreated => l10n.orderActionOrderSheetCreated,
      OrderActionType.orderSheetGenerated =>
        l10n.orderActionOrderSheetGenerated,
      OrderActionType.provisionalInvoiceGenerated =>
        l10n.orderActionProvisionalInvoiceGenerated,
    };
  }
}

/// Generic inline multi-select dropdown with checkboxes.
class _MultiSelectDropdown<T> extends StatefulWidget {
  const _MultiSelectDropdown({
    required this.label,
    required this.icon,
    required this.items,
    required this.selectedItems,
    required this.itemLabel,
    required this.onChanged,
    this.itemColor,
    super.key,
  });

  final String label;
  final IconData icon;
  final List<T> items;
  final Set<T> selectedItems;
  final String Function(T) itemLabel;
  final Color Function(T)? itemColor;
  final ValueChanged<Set<T>> onChanged;

  @override
  State<_MultiSelectDropdown<T>> createState() =>
      _MultiSelectDropdownState<T>();
}

class _MultiSelectDropdownState<T> extends State<_MultiSelectDropdown<T>> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = widget.selectedItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasSelection
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: hasSelection
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hasSelection
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll(theme.colorScheme.primary),
                thickness: const WidgetStatePropertyAll(6),
                radius: const Radius.circular(3),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: widget.items.map((item) {
                    final selected = widget.selectedItems.contains(item);
                    return CheckboxListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: theme.colorScheme.primary,
                      title: Text(
                        widget.itemLabel(item),
                        style: theme.textTheme.bodySmall,
                      ),
                      value: selected,
                      onChanged: (val) {
                        final updated = Set<T>.from(widget.selectedItems);
                        if (val == true) {
                          updated.add(item);
                        } else {
                          updated.remove(item);
                        }
                        widget.onChanged(updated);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
