import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../core/log/app_logger.dart';
import '../../../../core/utils/day_utils.dart';
import '../../../clients/domain/repositories/clients_repository.dart';
import '../../../shipping_methods/domain/entities/shipping_method.dart';
import '../../../shipping_methods/data/datasources/shipping_method_firestore_data_source.dart';
import '../../domain/entities/order_sheet.dart';
import '../../domain/services/order_sheet_pdf_generator.dart';

/// Generates and shows a PDF preview dialog for a client's order sheet.
///
/// Extracts rows with quantity > 0 for the given [col] (client index),
/// generates the PDF, and displays a preview with a save button.
Future<void> showOrderSheetPdfDialog(
  BuildContext context, {
  required OrderSheet orderSheet,
  required int col,
  required String Function(num) formatNum,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final clientName = orderSheet.clients[col];
  final clientId = col < orderSheet.clientIds.length
      ? orderSheet.clientIds[col]
      : '';

  final rows = <OrderSheetPdfRow>[];
  for (var p = 0; p < orderSheet.products.length; p++) {
    final qty = orderSheet.quantities[p][col];
    if (qty > 0) {
      String? note;
      if (p < orderSheet.cellNotes.length) {
        note = orderSheet.cellNotes[p][clientId];
      }
      rows.add(
        OrderSheetPdfRow(
          product: orderSheet.products[p],
          quantity: formatNum(qty),
          notes: note,
        ),
      );
    }
  }

  if (rows.isEmpty) {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.ordersTodayContextMenuGenerateOrderSheet),
        content: Text(l10n.ordersTodayGenerateOrderSheetEmpty),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.ordersTodayInfoDialogClose),
          ),
        ],
      ),
    );
    return;
  }

  final now = DateTime.now();
  final dateTimeFormatted = DateFormat('dd-MM-yyyy HH:mm:ss').format(now);
  final orderNumber = col + 1;

  // ── Resolve shipping method for current day ──────────────────
  final shippingMethodName = clientId.isNotEmpty
      ? await _resolveShippingMethod(
          context,
          clientId: clientId,
          clientName: clientName,
          date: DateTime.tryParse(orderSheet.date) ?? now,
        )
      : null;

  // User cancelled the shipping method selection → abort PDF generation
  if (shippingMethodName == null) return;
  if (!context.mounted) return;

  try {
    final pdfBytes = await sl<OrderSheetPdfGenerator>().generate(
      clientName: clientName,
      dateTime: dateTimeFormatted,
      orderNumber: orderNumber,
      rows: rows,
      shippingMethod: shippingMethodName,
    );

    final fileName =
        'Pedido_${clientName.replaceAll(RegExp(r'[^\w\s-]'), '')}_${orderSheet.date}';

    await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: fileName);
  } on Exception catch (e, st) {
    sl<AppLogger>().error('Error generating order sheet PDF', e, st);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.ordersTodayErrorUnknown)));
  }
}

/// Resolves the shipping method name for a client on the given date.
///
/// 1. Looks up the client's `shippingMethodsByDay` for the weekday.
/// 2. If found, resolves the method name from the shipping methods list.
/// 3. If not found, shows a dialog for the user to pick one, saves it, and returns the name.
/// 4. Returns `null` if user cancels or no methods available.
Future<String?> _resolveShippingMethod(
  BuildContext context, {
  required String clientId,
  required String clientName,
  required DateTime date,
}) async {
  final dayCode = dayOrder[date.weekday - 1]; // weekday: 1=monday..7=sunday

  // Fetch client data and shipping methods
  final clientsResult = await sl<ClientsRepository>().getClients();
  final shippingMethods = await sl<ShippingMethodFirestoreDataSource>()
      .getAll();

  if (shippingMethods.isEmpty) return null;

  // Find this client's assignment for today's weekday
  String? methodId;
  clientsResult.fold((_) {}, (clients) {
    final client = clients.where((c) => c.id == clientId).firstOrNull;
    if (client != null) {
      methodId = client.shippingMethodsByDay[dayCode];
    }
  });

  // If the client already has a method assigned for this day, resolve the name
  if (methodId != null) {
    final method = shippingMethods.where((m) => m.id == methodId).firstOrNull;
    if (method != null) return method.name;
    // Method ID is stale/orphaned — fall through to ask user
  }

  // No method assigned — ask the user to pick one (mandatory)
  if (!context.mounted) return null;
  final selected = await _showSelectShippingMethodDialog(
    context,
    clientName: clientName,
    dayCode: dayCode,
    shippingMethods: shippingMethods,
  );

  // User cancelled → abort PDF generation entirely
  if (selected == null || !context.mounted) return null;

  // Save to Firestore
  // Build the full map with the new assignment
  Map<String, String> currentMap = {};
  clientsResult.fold((_) {}, (clients) {
    final client = clients.where((c) => c.id == clientId).firstOrNull;
    if (client != null) {
      currentMap = Map<String, String>.from(client.shippingMethodsByDay);
    }
  });
  currentMap[dayCode] = selected.id;

  await sl<ClientsRepository>().saveClientsBatch(
    shippingMethodsByDayChanges: {
      clientId: currentMap.map((k, v) => MapEntry(k, v)),
    },
  );

  return selected.name;
}

/// Shows a dialog to let the user pick a shipping method for the given day.
/// Styled like the FdProductSelectorDialog with a search bar and list.
Future<ShippingMethod?> _showSelectShippingMethodDialog(
  BuildContext context, {
  required String clientName,
  required String dayCode,
  required List<ShippingMethod> shippingMethods,
}) {
  final l10n = AppLocalizations.of(context)!;
  final localizedDayName = localizedDay(dayCode, l10n);

  return showDialog<ShippingMethod>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ShippingMethodSelectorDialog(
      clientName: clientName,
      localizedDayName: localizedDayName,
      shippingMethods: shippingMethods,
      cancelLabel: MaterialLocalizations.of(ctx).cancelButtonLabel,
    ),
  );
}

class _ShippingMethodSelectorDialog extends StatefulWidget {
  final String clientName;
  final String localizedDayName;
  final List<ShippingMethod> shippingMethods;
  final String cancelLabel;

  const _ShippingMethodSelectorDialog({
    required this.clientName,
    required this.localizedDayName,
    required this.shippingMethods,
    required this.cancelLabel,
  });

  @override
  State<_ShippingMethodSelectorDialog> createState() =>
      _ShippingMethodSelectorDialogState();
}

class _ShippingMethodSelectorDialogState
    extends State<_ShippingMethodSelectorDialog> {
  final _searchController = TextEditingController();
  late List<ShippingMethod> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.shippingMethods;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final trimmed = query.trim().toLowerCase();
    setState(() {
      if (trimmed.isEmpty) {
        _filtered = widget.shippingMethods;
      } else {
        _filtered = widget.shippingMethods
            .where((m) => m.name.toLowerCase().contains(trimmed))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final headerStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.pdfSelectShippingMethod),
          const SizedBox(height: 4),
          Text(
            l10n.pdfSubtitleFor(widget.clientName, widget.localizedDayName),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: l10n.pdfSearchShippingMethod,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.pdfColumnName, style: headerStyle)),
                  SizedBox(
                    width: 120,
                    child: Text(
                      l10n.pdfColumnPhone,
                      style: headerStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          l10n.pdfNoShippingMethodsFound,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final method = _filtered[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              hoverColor: colorScheme.surfaceContainerLow,
                              onTap: () => Navigator.of(context).pop(method),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        method.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        method.phone,
                                        textAlign: TextAlign.right,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.only(top: 16, right: 24, bottom: 24),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.primary),
          ),
          child: Text(widget.cancelLabel),
        ),
      ],
    );
  }
}
