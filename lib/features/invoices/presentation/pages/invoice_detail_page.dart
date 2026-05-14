import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/router/router.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/presentation/widgets/page_header.dart';
import '../../domain/entities/invoice.dart';
import '../bloc/invoice_detail_cubit.dart';
import '../bloc/invoice_detail_state.dart';
import '../widgets/invoice_status_chip.dart';

class InvoiceDetailPage extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailPage({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  late final InvoiceDetailCubit _cubit;
  static final _displayDateFmt = DateFormat('dd-MM-yyyy');

  @override
  void initState() {
    super.initState();
    _cubit = sl<InvoiceDetailCubit>();
    _cubit.loadInvoice(widget.invoiceId);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isMobile =
        MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint;

    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<InvoiceDetailCubit, InvoiceDetailState>(
        builder: (context, state) {
          if (state is InvoiceDetailLoading || state is InvoiceDetailInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InvoiceDetailError) {
            return _buildError(state, l10n, colorScheme, textTheme);
          }

          if (state is InvoiceDetailLoaded) {
            if (isMobile) {
              return _buildMobileBody(
                state.invoice,
                l10n,
                colorScheme,
                textTheme,
              );
            }
            return _buildDesktopBody(
              state.invoice,
              l10n,
              colorScheme,
              textTheme,
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ─── Desktop layout ──────────────────────────────────────────────────

  Widget _buildDesktopBody(
    Invoice invoice,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          titleWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
                tooltip: l10n.invoiceDetailGoBack,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.invoiceDetailTitle,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: _buildContent(
              invoice,
              l10n,
              colorScheme,
              textTheme,
              isMobile: false,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Mobile layout ───────────────────────────────────────────────────

  Widget _buildMobileBody(
    Invoice invoice,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: _buildContent(
        invoice,
        l10n,
        colorScheme,
        textTheme,
        isMobile: true,
      ),
    );
  }

  // ─── Shared content ──────────────────────────────────────────────────

  Widget _buildContent(
    Invoice invoice,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    bool isMobile = false,
  }) {
    final cur = invoice.currency ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card
        _buildHeaderCard(invoice, l10n, colorScheme, textTheme),
        const SizedBox(height: AppSpacing.lg),
        // Lines section
        _buildLinesSection(
          invoice,
          l10n,
          colorScheme,
          textTheme,
          cur,
          isMobile: isMobile,
        ),
        const SizedBox(height: AppSpacing.lg),
        // Totals section
        _buildTotalsSection(invoice, l10n, colorScheme, textTheme, cur),
      ],
    );
  }

  Widget _buildHeaderCard(
    Invoice invoice,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: AppOpacity.medium,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.docNumber,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                InvoiceStatusChip(status: invoice.status ?? ''),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildInfoRow(
              l10n.invoiceDetailDate,
              _formatDate(invoice.date),
              textTheme,
              colorScheme,
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildInfoRow(
              l10n.invoiceDetailClient,
              invoice.contactName ?? '—',
              textTheme,
              colorScheme,
            ),
            if (invoice.currency != null && invoice.currency!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _buildInfoRow(
                l10n.invoiceDetailCurrency,
                invoice.currency!,
                textTheme,
                colorScheme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: textTheme.bodyMedium)),
      ],
    );
  }

  Widget _buildLinesSection(
    Invoice invoice,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    String cur, {
    bool isMobile = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.invoiceDetailLines,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (invoice.lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                l10n.invoiceDetailNoLines,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else if (isMobile)
          _buildMobileLineCards(
            invoice.lines,
            l10n,
            colorScheme,
            textTheme,
            cur,
          )
        else
          _buildLinesTable(invoice.lines, l10n, colorScheme, textTheme, cur),
      ],
    );
  }

  Widget _buildLinesTable(
    List<InvoiceLine> lines,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    String cur,
  ) {
    final headerStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );
    final border = BorderSide(
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.small),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            color: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    l10n.invoiceDetailLineDescription,
                    style: headerStyle,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    l10n.invoiceDetailLineQuantity,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    l10n.invoiceDetailLinePrice,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    l10n.invoiceDetailLineTax,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    l10n.invoiceDetailLineTotal,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...lines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            final isLast = index == lines.length - 1;
            return Container(
              decoration: BoxDecoration(
                border: isLast ? null : Border(bottom: border),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      line.description ?? '—',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      line.quantity?.toStringAsFixed(2) ?? '—',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      line.price != null
                          ? '${line.price!.toStringAsFixed(2)} $cur'.trim()
                          : '—',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      line.taxPercentage != null
                          ? '${line.taxPercentage!.toStringAsFixed(0)}%'
                          : '—',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      line.total != null
                          ? '${line.total!.toStringAsFixed(2)} $cur'.trim()
                          : '—',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMobileLineCards(
    List<InvoiceLine> lines,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    String cur,
  ) {
    return Column(
      children: lines.map((line) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.description ?? '—',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileLineField(
                        l10n.invoiceDetailLineQuantity,
                        line.quantity?.toStringAsFixed(2) ?? '—',
                        textTheme,
                        colorScheme,
                      ),
                    ),
                    Expanded(
                      child: _buildMobileLineField(
                        l10n.invoiceDetailLinePrice,
                        line.price != null
                            ? '${line.price!.toStringAsFixed(2)} $cur'.trim()
                            : '—',
                        textTheme,
                        colorScheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileLineField(
                        l10n.invoiceDetailLineTax,
                        line.taxPercentage != null
                            ? '${line.taxPercentage!.toStringAsFixed(0)}%'
                            : '—',
                        textTheme,
                        colorScheme,
                      ),
                    ),
                    Expanded(
                      child: _buildMobileLineField(
                        l10n.invoiceDetailLineTotal,
                        line.total != null
                            ? '${line.total!.toStringAsFixed(2)} $cur'.trim()
                            : '—',
                        textTheme,
                        colorScheme,
                        isBold: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileLineField(
    String label,
    String value,
    TextTheme textTheme,
    ColorScheme colorScheme, {
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsSection(
    Invoice invoice,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    String cur,
  ) {
    final taxTotal = invoice.total != null && invoice.subtotal != null
        ? invoice.total! - invoice.subtotal!
        : null;

    return Card(
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: AppOpacity.medium,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _buildTotalRow(
              l10n.invoiceDetailSubtotal,
              invoice.subtotal,
              cur,
              textTheme,
              colorScheme,
            ),
            if (taxTotal != null && taxTotal != 0) ...[
              const SizedBox(height: AppSpacing.xs),
              _buildTotalRow(
                l10n.invoiceDetailTaxBreakdown,
                taxTotal,
                cur,
                textTheme,
                colorScheme,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: AppSpacing.sm),
            _buildTotalRow(
              l10n.invoiceDetailTotal,
              invoice.total,
              cur,
              textTheme,
              colorScheme,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double? amount,
    String currency,
    TextTheme textTheme,
    ColorScheme colorScheme, {
    bool isBold = false,
  }) {
    final style = isBold
        ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : textTheme.bodyMedium;
    final labelStyle = isBold
        ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(
          amount != null
              ? '${amount.toStringAsFixed(2)} $currency'.trim()
              : '—',
          style: style,
        ),
      ],
    );
  }

  // ─── Error state ─────────────────────────────────────────────────────

  Widget _buildError(
    InvoiceDetailError state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final message = switch (state.errorType) {
      InvoiceDetailErrorType.configNotFound => l10n.fdConfigNotFound,
      InvoiceDetailErrorType.network => l10n.fdNetworkError,
      InvoiceDetailErrorType.server => l10n.fdServerError,
      InvoiceDetailErrorType.unknown => l10n.fdUnknownError,
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: AppIconSizes.xl,
            color: colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => _cubit.retry(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.fdRetry),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.invoices),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(l10n.invoiceDetailGoBack),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _displayDateFmt.format(parsed);
  }
}
