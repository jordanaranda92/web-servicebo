import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../domain/entities/invoice_preview.dart';
import '../bloc/provisional_invoice_cubit.dart';
import '../bloc/provisional_invoice_state.dart';

class ProvisionalInvoiceDialog extends StatefulWidget {
  const ProvisionalInvoiceDialog({
    super.key,
    required this.cubit,
    required this.clientId,
    required this.date,
    required this.productIds,
    required this.quantities,
    this.refunds = const [],
  });

  final ProvisionalInvoiceCubit cubit;
  final String clientId;
  final String date;
  final List<String> productIds;
  final List<num> quantities;
  final List<num> refunds;

  @override
  State<ProvisionalInvoiceDialog> createState() =>
      _ProvisionalInvoiceDialogState();
}

class _ProvisionalInvoiceDialogState extends State<ProvisionalInvoiceDialog> {
  @override
  void initState() {
    super.initState();
    widget.cubit.prepare(
      clientId: widget.clientId,
      date: widget.date,
      productIds: widget.productIds,
      quantities: widget.quantities,
      refunds: widget.refunds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocProvider.value(
      value: widget.cubit,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
          child: BlocBuilder<ProvisionalInvoiceCubit, ProvisionalInvoiceState>(
            buildWhen: (previous, current) =>
                previous.runtimeType != current.runtimeType ||
                previous != current,
            builder: (context, state) {
              return switch (state) {
                ProvisionalInvoiceInitial() ||
                ProvisionalInvoiceLoading() => _buildLoading(l10n, colorScheme),
                ProvisionalInvoicePreviewReady(:final preview) => _buildPreview(
                  preview: preview,
                  l10n: l10n,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  duplicateWarning: false,
                ),
                ProvisionalInvoiceDuplicateWarning(:final preview) =>
                  _buildPreview(
                    preview: preview,
                    l10n: l10n,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    duplicateWarning: true,
                  ),
                ProvisionalInvoiceCreating(:final preview) => _buildPreview(
                  preview: preview,
                  l10n: l10n,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  duplicateWarning: false,
                  creating: true,
                ),
                ProvisionalInvoiceSuccess(:final invoice) => _buildSuccess(
                  invoice.docNumber,
                  l10n,
                  colorScheme,
                  textTheme,
                ),
                ProvisionalInvoiceError(:final errorType, :final details) =>
                  _buildError(errorType, details, l10n, colorScheme, textTheme),
              };
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(AppLocalizations l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.provisionalInvoiceLoading),
        ],
      ),
    );
  }

  Widget _buildPreview({
    required InvoicePreview preview,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool duplicateWarning,
    bool creating = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            l10n.provisionalInvoicePreviewTitle,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Client and date
          Text(
            '${preview.clientName} — ${preview.date}',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Draft badge
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Text(
                l10n.provisionalInvoiceDraftBadge,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Duplicate warning banner
          if (duplicateWarning) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadii.small),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.error,
                    size: AppIconSizes.md,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.provisionalInvoiceDuplicateWarning,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Scrollable content: products table + totals + tax breakdown
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Lines table
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Table(
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      border: TableBorder.symmetric(
                        inside: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FixedColumnWidth(60),
                        2: FixedColumnWidth(80),
                        3: IntrinsicColumnWidth(),
                        4: FixedColumnWidth(90),
                      },
                      children: [
                        // Header
                        TableRow(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          children: [
                            _headerCell(
                              l10n.provisionalInvoiceProduct,
                              textTheme,
                            ),
                            _headerCell(
                              l10n.provisionalInvoiceQty,
                              textTheme,
                              align: TextAlign.right,
                            ),
                            _headerCell(
                              l10n.provisionalInvoicePrice,
                              textTheme,
                              align: TextAlign.right,
                            ),
                            _headerCell(
                              l10n.provisionalInvoiceTax,
                              textTheme,
                              align: TextAlign.right,
                            ),
                            _headerCell(
                              l10n.provisionalInvoiceLineTotal,
                              textTheme,
                              align: TextAlign.right,
                            ),
                          ],
                        ),
                        // Lines
                        ...preview.lines.map(
                          (line) => TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            children: [
                              _dataCell(line.productName, textTheme),
                              _dataCell(
                                _formatNum(line.quantity),
                                textTheme,
                                align: TextAlign.right,
                              ),
                              _dataCell(
                                '${_formatCurrency(line.unitPrice)} €',
                                textTheme,
                                align: TextAlign.right,
                              ),
                              _dataCell(
                                _formatTaxLabel(line.tax, l10n),
                                textTheme,
                                align: TextAlign.right,
                              ),
                              _dataCell(
                                '${_formatCurrency(line.lineTotal)} €',
                                textTheme,
                                align: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Totals
                  _totalRow(
                    l10n.provisionalInvoiceSubtotal,
                    '${_formatCurrency(preview.subtotal)} €',
                    textTheme,
                    colorScheme,
                    bold: true,
                  ),

                  // Tax breakdown table
                  if (preview.taxBreakdown.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: IntrinsicColumnWidth(),
                        2: FixedColumnWidth(80),
                      },
                      children: [
                        // Header row
                        TableRow(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          children: [
                            _headerCell(
                              l10n.provisionalInvoiceTaxHeader,
                              textTheme,
                            ),
                            _headerCell(
                              l10n.provisionalInvoiceTaxBase,
                              textTheme,
                              align: TextAlign.right,
                            ),
                            _headerCell(
                              l10n.provisionalInvoiceTaxAmount,
                              textTheme,
                              align: TextAlign.right,
                            ),
                          ],
                        ),
                        // Tax rows
                        ...preview.taxBreakdown.entries.map(
                          (e) => TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            children: [
                              _dataCell(e.key, textTheme),
                              _dataCell(
                                '${_formatCurrency(e.value.base)} €',
                                textTheme,
                                align: TextAlign.right,
                              ),
                              _dataCell(
                                '${_formatCurrency(e.value.amount)} €',
                                textTheme,
                                align: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Divider(),
                  _totalRow(
                    l10n.provisionalInvoiceTotal,
                    '${_formatCurrency(preview.total)} €',
                    textTheme,
                    colorScheme,
                    bold: true,
                  ),

                  // Refund notes
                  if (preview.refundNotes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.provisionalInvoiceNotesLabel,
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: preview.refundNotes
                              .map(
                                (note) => Text(
                                  note,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: creating ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.provisionalInvoiceCancel),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: creating
                    ? null
                    : () => widget.cubit.confirm(preview),
                child: creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.provisionalInvoiceConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(
    String docNumber,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: colorScheme.primary,
            size: AppIconSizes.xl,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.provisionalInvoiceSuccessTitle,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.provisionalInvoiceSuccessMessage(docNumber),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.provisionalInvoiceClose),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    ProvisionalInvoiceErrorType errorType,
    List<String>? details,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final message = switch (errorType) {
      ProvisionalInvoiceErrorType.configNotFound =>
        l10n.provisionalInvoiceErrorConfigNotFound,
      ProvisionalInvoiceErrorType.clientNotLinked =>
        l10n.provisionalInvoiceErrorClientNotLinked,
      ProvisionalInvoiceErrorType.productsNotLinked =>
        l10n.provisionalInvoiceErrorProductsNotLinked,
      ProvisionalInvoiceErrorType.productNotFoundInFd =>
        l10n.provisionalInvoiceErrorProductNotFoundInFd,
      ProvisionalInvoiceErrorType.noLines =>
        l10n.provisionalInvoiceErrorNoLines,
      ProvisionalInvoiceErrorType.network =>
        l10n.provisionalInvoiceErrorNetwork,
      ProvisionalInvoiceErrorType.server => l10n.provisionalInvoiceErrorServer,
      ProvisionalInvoiceErrorType.unknown =>
        l10n.provisionalInvoiceErrorUnknown,
    };

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.error,
            size: AppIconSizes.xl,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.provisionalInvoiceErrorTitle, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (details != null && details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...details.map(
              (d) => Text(
                '• $d',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.provisionalInvoiceClose),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
    String text,
    TextTheme textTheme, {
    TextAlign align = TextAlign.left,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      child: Text(
        text,
        textAlign: align,
        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _dataCell(
    String text,
    TextTheme textTheme, {
    TextAlign align = TextAlign.left,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.xs,
      ),
      child: Text(text, textAlign: align, style: textTheme.bodySmall),
    );
  }

  Widget _totalRow(
    String label,
    String value,
    TextTheme textTheme,
    ColorScheme colorScheme, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 90,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNum(num value) {
    if (value == value.toInt()) return value.toInt().toString();
    return _formatCurrency(value.toDouble());
  }

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final sign = intPart.startsWith('-') ? '-' : '';
    final digits = intPart.replaceAll('-', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '$sign${buffer.toString()},$decPart';
  }

  Map<String, String> _taxIdLabels(AppLocalizations l10n) => {
    'S_IVA_21': l10n.taxLabelIva21,
    'S_IVA_10': l10n.taxLabelIva10,
    'S_IVA_4': l10n.taxLabelIva4,
    'S_IVA_RE_5.2': l10n.taxLabelRe52,
    'S_IVA_RE_1.4': l10n.taxLabelRe14,
    'S_IVA_RE_0.5': l10n.taxLabelRe05,
  };

  String _formatTaxLabel(List<String> taxIds, AppLocalizations l10n) {
    if (taxIds.isEmpty) return '-';
    final labels = <String>[];
    final taxMap = _taxIdLabels(l10n);
    for (final id in taxIds) {
      labels.add(taxMap[id] ?? id);
    }
    return labels.join('\n');
  }
}
