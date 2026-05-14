import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../orders_today/domain/entities/order_sheet.dart';

class HistoryOrdersTable extends StatelessWidget {
  const HistoryOrdersTable({
    super.key,
    required this.orderSheet,
    this.searchFilter = '',
  });

  final OrderSheet orderSheet;
  final String searchFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final products = orderSheet.products;
    final clients = orderSheet.clients;

    // Filter clients by search
    final filteredClientIndices = <int>[];
    for (var i = 0; i < clients.length; i++) {
      if (searchFilter.isEmpty ||
          clients[i].toLowerCase().contains(searchFilter.toLowerCase())) {
        filteredClientIndices.add(i);
      }
    }

    // Calculate product totals for filtered clients
    final productTotals = <String, num>{};
    for (var p = 0; p < products.length; p++) {
      num total = 0;
      for (final cIdx in filteredClientIndices) {
        if (p < orderSheet.quantities.length &&
            cIdx < orderSheet.quantities[p].length) {
          total += orderSheet.quantities[p][cIdx];
        }
      }
      productTotals[products[p]] = total;
    }

    num grandTotal = 0;
    for (final total in productTotals.values) {
      grandTotal += total;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.small),
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    colorScheme.surfaceContainerHighest,
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return colorScheme.surfaceContainerLow;
                    }
                    return null;
                  }),
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    verticalInside: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    top: BorderSide(color: colorScheme.outlineVariant),
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                    left: BorderSide(color: colorScheme.outlineVariant),
                    right: BorderSide(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  headingRowHeight: 100,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  horizontalMargin: AppSpacing.md,
                  columnSpacing: AppSpacing.md,
                  columns: [
                    DataColumn(
                      label: Text(
                        l10n.ordersHistoryColumnClient,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ...products.map(
                      (product) => DataColumn(
                        label: Transform.rotate(
                          angle: -0.785,
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            product,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.visible,
                            softWrap: false,
                          ),
                        ),
                        numeric: true,
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l10n.ordersHistoryColumnTotal,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      numeric: true,
                    ),
                  ],
                  rows: [
                    ...filteredClientIndices.map((cIdx) {
                      num rowTotal = 0;
                      for (var p = 0; p < products.length; p++) {
                        if (p < orderSheet.quantities.length &&
                            cIdx < orderSheet.quantities[p].length) {
                          rowTotal += orderSheet.quantities[p][cIdx];
                        }
                      }
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(clients[cIdx], style: textTheme.bodyMedium),
                          ),
                          ...List.generate(products.length, (p) {
                            num val = 0;
                            if (p < orderSheet.quantities.length &&
                                cIdx < orderSheet.quantities[p].length) {
                              val = orderSheet.quantities[p][cIdx];
                            }
                            return DataCell(
                              Text(
                                _formatNum(val),
                                style: textTheme.bodyMedium,
                              ),
                            );
                          }),
                          DataCell(
                            Text(
                              _formatNum(rowTotal),
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    DataRow(
                      color: WidgetStatePropertyAll(
                        colorScheme.surfaceContainerHighest,
                      ),
                      cells: [
                        DataCell(
                          Text(
                            l10n.ordersHistoryRowTotals,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...products.map(
                          (product) => DataCell(
                            Text(
                              _formatNum(productTotals[product] ?? 0),
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatNum(grandTotal),
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatNum(num value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}
