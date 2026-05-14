import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../bloc/invoices_state.dart';

class InvoiceFiltersDialog extends StatefulWidget {
  const InvoiceFiltersDialog({
    super.key,
    required this.currentFilters,
    required this.availableClients,
  });

  final InvoiceFilters currentFilters;
  final List<String> availableClients;

  @override
  State<InvoiceFiltersDialog> createState() => _InvoiceFiltersDialogState();
}

class _InvoiceFiltersDialogState extends State<InvoiceFiltersDialog> {
  static const _allStatuses = ['paid', 'pending', 'overdue', 'draft', 'voided'];
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  late Set<String> _selectedStatuses;
  late Set<String> _selectedClients;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _clientSearchController = TextEditingController();
  List<String> _filteredClients = [];

  @override
  void initState() {
    super.initState();
    _selectedStatuses = Set.from(widget.currentFilters.statuses);
    _selectedClients = Set.from(widget.currentFilters.clients);
    _dateFrom = widget.currentFilters.dateFrom;
    _dateTo = widget.currentFilters.dateTo;
    _filteredClients = widget.availableClients;
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  bool get _hasDateError {
    if (_dateFrom != null && _dateTo != null) {
      return _dateFrom!.isAfter(_dateTo!);
    }
    return false;
  }

  void _filterClients(String query) {
    final trimmed = query.trim().toLowerCase();
    setState(() {
      if (trimmed.isEmpty) {
        _filteredClients = widget.availableClients;
      } else {
        _filteredClients = widget.availableClients
            .where((c) => c.toLowerCase().contains(trimmed))
            .toList();
      }
    });
  }

  void _clearAll() {
    setState(() {
      _selectedStatuses.clear();
      _selectedClients.clear();
      _dateFrom = null;
      _dateTo = null;
      _clientSearchController.clear();
      _filteredClients = widget.availableClients;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      InvoiceFilters(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        statuses: _selectedStatuses,
        clients: _selectedClients,
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    return switch (status) {
      'paid' => l10n.invoiceStatusPaid,
      'pending' => l10n.invoiceStatusPending,
      'overdue' => l10n.invoiceStatusOverdue,
      'draft' => l10n.invoiceStatusDraft,
      'voided' => l10n.invoiceStatusVoided,
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isMobile =
        MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint;

    return AlertDialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xl,
            )
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: Text(l10n.invoicesFilterTitle),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Status section ────────────────────────────────────
              Text(
                l10n.invoicesFilterStatus,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _allStatuses.map((status) {
                  final selected = _selectedStatuses.contains(status);
                  return FilterChip(
                    label: Text(_statusLabel(status, l10n)),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedStatuses.add(status);
                        } else {
                          _selectedStatuses.remove(status);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ─── Dates section ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.invoicesFilterDateFrom,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _DateField(
                          date: _dateFrom,
                          hint: l10n.invoicesFilterDateFrom,
                          onTap: () => _pickDate(isFrom: true),
                          onClear: () => setState(() => _dateFrom = null),
                          dateFmt: _dateFmt,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.invoicesFilterDateTo,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _DateField(
                          date: _dateTo,
                          hint: l10n.invoicesFilterDateTo,
                          onTap: () => _pickDate(isFrom: false),
                          onClear: () => setState(() => _dateTo = null),
                          dateFmt: _dateFmt,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_hasDateError) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.invoicesFilterDateError,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // ─── Clients section ───────────────────────────────────
              if (widget.availableClients.isNotEmpty) ...[
                Text(
                  l10n.invoicesFilterClients,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _clientSearchController,
                    onChanged: _filterClients,
                    decoration: InputDecoration(
                      hintText: l10n.invoicesFilterSearchClients,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.small),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.small),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.small),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ScrollbarTheme(
                      data: ScrollbarThemeData(
                        thumbColor: WidgetStatePropertyAll(colorScheme.primary),
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredClients.length,
                          itemBuilder: (context, index) {
                            final client = _filteredClients[index];
                            final selected = _selectedClients.contains(client);
                            return CheckboxListTile(
                              value: selected,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                client,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedClients.add(client);
                                  } else {
                                    _selectedClients.remove(client);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        Row(
          children: [
            TextButton(
              onPressed: _clearAll,
              child: Text(l10n.invoicesFilterClear),
            ),
            const Spacer(),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.primary),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.invoicesFilterCancel),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: _hasDateError ? null : _apply,
              child: Text(l10n.invoicesFilterApply),
            ),
          ],
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.hint,
    required this.onTap,
    required this.onClear,
    required this.dateFmt,
  });

  final DateTime? date;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: TextField(
        readOnly: true,
        onTap: onTap,
        controller: TextEditingController(
          text: date != null ? dateFmt.format(date!) : '',
        ),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          suffixIcon: date != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
