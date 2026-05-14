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
import '../bloc/invoices_cubit.dart';
import '../bloc/invoices_state.dart';
import '../widgets/invoice_card.dart';
import '../widgets/invoice_filters_dialog.dart';
import '../widgets/invoice_status_chip.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  late final InvoicesCubit _cubit;
  final _searchController = TextEditingController();
  final _mobileScrollController = ScrollController();
  final Set<String> _selectedInvoiceIds = {};
  static final _displayDateFmt = DateFormat('dd-MM-yyyy');

  @override
  void initState() {
    super.initState();
    _cubit = sl<InvoicesCubit>();
    _cubit.loadInvoices(filters: InvoiceFilters.defaultFilters());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mobileScrollController.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _showFiltersDialog(InvoicesLoaded state) async {
    final result = await showDialog<InvoiceFilters>(
      context: context,
      builder: (_) => InvoiceFiltersDialog(
        currentFilters: state.filters,
        availableClients: state.availableClients,
      ),
    );
    if (result != null) {
      _cubit.applyFilters(result);
    }
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
      child: isMobile
          ? _buildMobileLayout(l10n, colorScheme, textTheme)
          : _buildDesktopLayout(l10n, colorScheme, textTheme),
    );
  }

  // ─── Desktop layout ──────────────────────────────────────────────────

  Widget _buildDesktopLayout(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(title: l10n.menuInvoices),
        BlocBuilder<InvoicesCubit, InvoicesState>(
          buildWhen: (previous, current) {
            if (previous.runtimeType != current.runtimeType) return true;
            final prev = previous is InvoicesLoaded ? previous : null;
            final curr = current is InvoicesLoaded ? current : null;
            if (prev != null && curr != null) {
              return prev.filters.activeFilterCount !=
                  curr.filters.activeFilterCount;
            }
            return false;
          },
          builder: (context, state) {
            if (state is! InvoicesLoaded) return const SizedBox.shrink();
            final filterCount = state.filters.activeFilterCount;
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: AppDimensions.searchBoxHeight,
                      child: _buildSearchField(l10n, colorScheme),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    height: AppDimensions.searchBoxHeight,
                    child: FilledButton.icon(
                      onPressed: () => _showFiltersDialog(state),
                      icon: const Icon(Icons.filter_list, size: 20),
                      label: Text(
                        filterCount > 0
                            ? '${l10n.invoicesFilter} ($filterCount)'
                            : l10n.invoicesFilter,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        BlocBuilder<InvoicesCubit, InvoicesState>(
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType ||
              (previous is InvoicesLoaded &&
                  current is InvoicesLoaded &&
                  previous != current),
          builder: (context, state) {
            if (state is! InvoicesLoaded) return const SizedBox.shrink();
            final invoices = state.filteredInvoices;
            final selectedCount = _selectedInvoiceIds
                .where((id) => invoices.any((inv) => inv.id == id))
                .length;
            if (selectedCount == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildSelectionActionBar(
                invoices,
                selectedCount,
                l10n,
                colorScheme,
                textTheme,
              ),
            );
          },
        ),
        Expanded(
          child: _buildContent(l10n, colorScheme, textTheme, isMobile: false),
        ),
      ],
    );
  }

  // ─── Mobile layout ───────────────────────────────────────────────────

  Widget _buildMobileLayout(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        _buildMobileSearchBar(l10n, colorScheme),
        Expanded(
          child: _buildContent(l10n, colorScheme, textTheme, isMobile: true),
        ),
      ],
    );
  }

  Widget _buildMobileSearchBar(AppLocalizations l10n, ColorScheme colorScheme) {
    return BlocBuilder<InvoicesCubit, InvoicesState>(
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        final prev = previous is InvoicesLoaded ? previous : null;
        final curr = current is InvoicesLoaded ? current : null;
        if (prev != null && curr != null) {
          return prev.filters.activeFilterCount !=
              curr.filters.activeFilterCount;
        }
        return false;
      },
      builder: (context, state) {
        if (state is! InvoicesLoaded) return const SizedBox.shrink();
        final filterCount = state.filters.activeFilterCount;
        return Container(
          color: colorScheme.primary,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSearchField(l10n, colorScheme, onPrimary: true),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                height: AppDimensions.searchBoxHeight,
                child: Badge(
                  isLabelVisible: filterCount > 0,
                  label: Text('$filterCount'),
                  child: IconButton(
                    onPressed: () => _showFiltersDialog(state),
                    icon: Icon(Icons.filter_list, color: colorScheme.onPrimary),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.onPrimary.withValues(
                        alpha: 0.15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────────────

  Widget _buildSearchField(
    AppLocalizations l10n,
    ColorScheme colorScheme, {
    bool onPrimary = false,
  }) {
    final fillColor = onPrimary ? colorScheme.surface : null;
    final iconColor = onPrimary ? colorScheme.onSurfaceVariant : null;
    final textColor = onPrimary ? colorScheme.onSurface : null;
    final hintColor = onPrimary ? colorScheme.onSurfaceVariant : null;
    final borderColor = onPrimary
        ? Colors.transparent
        : colorScheme.outlineVariant;
    final focusedBorderColor = onPrimary
        ? colorScheme.onPrimary
        : colorScheme.primary;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        return TextField(
          controller: _searchController,
          style: onPrimary ? TextStyle(color: textColor) : null,
          onChanged: (v) => _cubit.filterByText(v),
          decoration: InputDecoration(
            hintText: l10n.invoicesSearchClient,
            hintStyle: hintColor != null ? TextStyle(color: hintColor) : null,
            prefixIcon: Icon(Icons.search, size: 20, color: iconColor),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: iconColor),
                    onPressed: () {
                      _searchController.clear();
                      _cubit.filterByText('');
                    },
                  )
                : null,
            isDense: true,
            filled: onPrimary,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.small),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.small),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.small),
              borderSide: BorderSide(color: focusedBorderColor, width: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required bool isMobile,
  }) {
    return BlocBuilder<InvoicesCubit, InvoicesState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          (previous is InvoicesLoaded &&
              current is InvoicesLoaded &&
              previous != current),
      builder: (context, state) {
        if (state is InvoicesLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is InvoicesError) {
          return _buildError(state, l10n, colorScheme, textTheme);
        }

        if (state is InvoicesLoaded) {
          if (state.filteredInvoices.isEmpty) {
            return Center(
              child: Text(
                l10n.invoicesEmpty,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          if (isMobile) {
            return RefreshIndicator(
              onRefresh: () => _cubit.loadInvoices(),
              child: _buildCardList(state, l10n),
            );
          }

          return _buildTable(state, l10n, colorScheme, textTheme);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCardList(InvoicesLoaded state, AppLocalizations l10n) {
    return ListView.builder(
      controller: _mobileScrollController,
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
      itemCount: state.filteredInvoices.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.filteredInvoices.length) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: state.isLoadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: () {
                        // loadMore not implemented yet (PA-04)
                      },
                      child: Text(l10n.invoicesLoadMore),
                    ),
            ),
          );
        }
        return InvoiceCard(
          invoice: state.filteredInvoices[index],
          onTap: () => context.go(
            '${AppRoutes.invoices}/${state.filteredInvoices[index].id}/detail',
          ),
        );
      },
    );
  }

  Widget _buildError(
    InvoicesError state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final message = switch (state.errorType) {
      InvoicesErrorType.configNotFound => l10n.fdConfigNotFound,
      InvoicesErrorType.network => l10n.fdNetworkError,
      InvoicesErrorType.server => l10n.fdServerError,
      InvoicesErrorType.unknown => l10n.fdUnknownError,
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
          const SizedBox(height: AppSpacing.md),
          if (state.errorType != InvoicesErrorType.configNotFound)
            FilledButton.icon(
              onPressed: () => _cubit.loadInvoices(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.fdRetry),
            ),
        ],
      ),
    );
  }

  Widget _buildTable(
    InvoicesLoaded state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final invoices = state.filteredInvoices;
    final headerStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );

    final border = BorderSide(
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
    final outerBorder = BorderSide(color: colorScheme.outlineVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          // Fixed header
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadii.small),
                topRight: Radius.circular(AppRadii.small),
              ),
              border: Border(
                top: outerBorder,
                left: outerBorder,
                right: outerBorder,
                bottom: outerBorder,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: SizedBox(
                    width: 48,
                    child: Checkbox(
                      value:
                          invoices.isNotEmpty &&
                              invoices.every(
                                (inv) => _selectedInvoiceIds.contains(inv.id),
                              )
                          ? true
                          : invoices.any(
                              (inv) => _selectedInvoiceIds.contains(inv.id),
                            )
                          ? null
                          : false,
                      tristate: true,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedInvoiceIds.addAll(
                              invoices.map((inv) => inv.id),
                            );
                          } else {
                            _selectedInvoiceIds.removeAll(
                              invoices.map((inv) => inv.id),
                            );
                          }
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(l10n.invoicesColumnNumber, style: headerStyle),
                ),
                SizedBox(
                  width: 110,
                  child: Text(l10n.invoicesColumnDate, style: headerStyle),
                ),
                Expanded(
                  flex: 3,
                  child: Text(l10n.invoicesColumnClient, style: headerStyle),
                ),
                SizedBox(
                  width: 80,
                  child: Text(l10n.invoicesColumnStatus, style: headerStyle),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    l10n.invoicesColumnSubtotal,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    l10n.invoicesColumnTotal,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Scrollable body
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadii.small),
                  bottomRight: Radius.circular(AppRadii.small),
                ),
                border: Border(
                  left: outerBorder,
                  right: outerBorder,
                  bottom: outerBorder,
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadii.small),
                  bottomRight: Radius.circular(AppRadii.small),
                ),
                child: ListView.separated(
                  itemCount: invoices.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: border.color),
                  itemBuilder: (context, index) {
                    final invoice = invoices[index];
                    final cur = invoice.currency ?? '';
                    final subtotalText = invoice.subtotal != null
                        ? '${invoice.subtotal!.toStringAsFixed(2)} $cur'.trim()
                        : '';
                    final totalText = invoice.total != null
                        ? '${invoice.total!.toStringAsFixed(2)} $cur'.trim()
                        : '';
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        hoverColor: colorScheme.surfaceContainerLow,
                        onTap: () => context.go(
                          '${AppRoutes.invoices}/${invoice.id}/detail',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 2,
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.md,
                                ),
                                child: SizedBox(
                                  width: 48,
                                  child: Checkbox(
                                    value: _selectedInvoiceIds.contains(
                                      invoice.id,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedInvoiceIds.add(invoice.id);
                                        } else {
                                          _selectedInvoiceIds.remove(
                                            invoice.id,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  invoice.docNumber,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(_formatDate(invoice.date)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  invoice.contactName ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: InvoiceStatusChip(
                                  status: invoice.status ?? '',
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  subtotalText,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  totalText,
                                  textAlign: TextAlign.right,
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
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionActionBar(
    List<Invoice> invoices,
    int selectedCount,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final selectedInvoices = invoices
        .where((inv) => _selectedInvoiceIds.contains(inv.id))
        .toList();
    final allProvisional = selectedInvoices.every((inv) => inv.isDraft);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.small),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Text(
              l10n.invoicesSelectedCount(selectedCount),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.close, size: AppIconSizes.sm),
              onPressed: () => setState(() => _selectedInvoiceIds.clear()),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(
                height: 24,
                child: VerticalDivider(
                  width: 1,
                  color: colorScheme.outlineVariant,
                ),
              ),
            ),
            if (allProvisional)
              TextButton(
                onPressed: () {
                  // TODO: implement convert to definitive
                },
                child: Text(
                  l10n.invoicesActionConvertDefinitive,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else
              Text(
                l10n.invoicesNoActionsAvailable,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _displayDateFmt.format(parsed);
  }
}
