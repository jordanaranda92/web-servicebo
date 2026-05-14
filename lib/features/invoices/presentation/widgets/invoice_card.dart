import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/theme_constants.dart';
import '../../domain/entities/invoice.dart';
import 'invoice_status_chip.dart';

class InvoiceCard extends StatelessWidget {
  const InvoiceCard({super.key, required this.invoice, this.onTap});

  final Invoice invoice;
  final VoidCallback? onTap;

  static final _displayDateFmt = DateFormat('dd-MM-yyyy');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cur = invoice.currency ?? '';
    final subtotalText = invoice.subtotal != null
        ? '${invoice.subtotal!.toStringAsFixed(2)} $cur'.trim()
        : '';
    final totalText = invoice.total != null
        ? '${invoice.total!.toStringAsFixed(2)} $cur'.trim()
        : '';

    return Card(
      elevation: AppElevation.low,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: AppOpacity.medium,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: doc number + date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    invoice.docNumber,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatDate(invoice.date),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Client name
              Text(
                invoice.contactName ?? '—',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Status chip + Amounts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InvoiceStatusChip(status: invoice.status ?? ''),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (subtotalText.isNotEmpty)
                        Text(
                          subtotalText,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        totalText,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _displayDateFmt.format(parsed);
  }
}
