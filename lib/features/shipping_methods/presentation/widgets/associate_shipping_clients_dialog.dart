import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/utils/day_utils.dart';
import '../../../clients/domain/entities/client.dart';
import '../../../clients/domain/usecases/save_clients_batch.dart';
import '../../../clients/domain/usecases/watch_clients.dart';
import '../../domain/entities/shipping_method.dart';

class AssociateShippingClientsDialog extends StatefulWidget {
  final ShippingMethod method;
  final WatchClients watchClients;
  final SaveClientsBatch saveClientsBatch;
  final AppLocalizations l10n;
  final ValueChanged<bool> onSaved;

  const AssociateShippingClientsDialog({
    super.key,
    required this.method,
    required this.watchClients,
    required this.saveClientsBatch,
    required this.l10n,
    required this.onSaved,
  });

  @override
  State<AssociateShippingClientsDialog> createState() =>
      _AssociateShippingClientsDialogState();
}

class _AssociateShippingClientsDialogState
    extends State<AssociateShippingClientsDialog> {
  List<Client>? _allClients;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSaving = false;

  /// Days selected at the top (applies to all checked clients).
  final Map<String, bool> _selectedDays = {for (final d in dayOrder) d: false};

  /// Clients checked to receive the shipping method for the selected days.
  final Set<String> _selectedClientIds = {};

  /// Snapshot of which clients already had this method on each day.
  final Map<String, Map<String, bool>> _initialDaySelections = {};

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final result = await widget.watchClients().first;
      if (!mounted) return;
      result.fold(
        (_) =>
            setState(() => _error = widget.l10n.shippingMethodsAssociateError),
        (clients) {
          for (final client in clients) {
            final days = <String, bool>{};
            for (final day in dayOrder) {
              days[day] = client.shippingMethodsByDay[day] == widget.method.id;
            }
            _initialDaySelections[client.id] = days;
          }
          setState(() => _allClients = clients);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = widget.l10n.shippingMethodsAssociateError);
      }
    }
  }

  List<Client> get _filteredClients {
    if (_allClients == null) return [];
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _allClients!;
    return _allClients!
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
  }

  bool get _anyDayChecked => dayOrder.any((d) => _selectedDays[d]!);

  bool get _canSave =>
      _anyDayChecked && _selectedClientIds.isNotEmpty && !_isSaving;

  void _toggleDay(String day) {
    setState(() {
      _selectedDays[day] = !_selectedDays[day]!;
    });
  }

  void _toggleClient(String clientId) {
    setState(() {
      if (_selectedClientIds.contains(clientId)) {
        _selectedClientIds.remove(clientId);
      } else {
        _selectedClientIds.add(clientId);
      }
    });
  }

  void _toggleAllClients() {
    setState(() {
      final filtered = _filteredClients;
      final allSelected = filtered.every(
        (c) => _selectedClientIds.contains(c.id),
      );
      if (allSelected) {
        for (final c in filtered) {
          _selectedClientIds.remove(c.id);
        }
      } else {
        for (final c in filtered) {
          _selectedClientIds.add(c.id);
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final activeDays = dayOrder.where((d) => _selectedDays[d]!).toList();

    final changes = <String, Map<String, String?>>{};

    for (final clientId in _selectedClientIds) {
      final initial = _initialDaySelections[clientId]!;
      final clientChanges = <String, String?>{};

      for (final day in activeDays) {
        // Only write if the client didn't already have this method on this day
        if (initial[day] != true) {
          clientChanges[day] = widget.method.id;
        }
      }

      if (clientChanges.isNotEmpty) {
        changes[clientId] = clientChanges;
      }
    }

    if (changes.isEmpty) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      return;
    }

    final result = await widget.saveClientsBatch(
      SaveClientsBatchParams(shippingMethodsByDayChanges: changes),
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    widget.onSaved(result.isRight());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isMobile =
        MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint;

    return AlertDialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: Text(
        l10n.shippingMethodsAssociateTitle(widget.method.name),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 500,
        height: 500,
        child: _buildContent(l10n, colorScheme, textTheme),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(l10n.settingsCancel),
        ),
        if (_allClients != null && _allClients!.isNotEmpty)
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.surface,
                    ),
                  )
                : Text(l10n.settingsSave),
          ),
      ],
    );
  }

  Widget _buildContent(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: AppIconSizes.xl,
              color: colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      );
    }

    if (_allClients == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.shippingMethodsAssociateLoading),
          ],
        ),
      );
    }

    if (_allClients!.isEmpty) {
      return Center(
        child: Text(
          l10n.shippingMethodsAssociateNoClients,
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
        ),
      );
    }

    final filtered = _filteredClients;
    final allClientsSelected =
        filtered.isNotEmpty &&
        filtered.every((c) => _selectedClientIds.contains(c.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Step 1: Day selector ──
        Text(
          l10n.shippingMethodsAssociateDaysLabel,
          style: textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final day in dayOrder)
              FilterChip(
                label: Text(
                  localizedDay(day, l10n),
                  style: textTheme.labelSmall,
                ),
                selected: _selectedDays[day]!,
                onSelected: (_) => _toggleDay(day),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Divider(
          height: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: AppSpacing.sm),
        // ── Step 2: Client list ──
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: l10n.shippingMethodsAssociateSearch,
            prefixIcon: const Icon(Icons.search_rounded),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Client list
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Column(
              children: [
                // Select all clients
                InkWell(
                  onTap: _toggleAllClients,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.small),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: allClientsSelected,
                            onChanged: (_) => _toggleAllClients(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          l10n.shippingMethodsAssociateSelectAllClients,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                // Scrollable client list
                Expanded(
                  child: RawScrollbar(
                    thumbVisibility: true,
                    thumbColor: colorScheme.primary,
                    radius: const Radius.circular(AppRadii.small),
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final client = filtered[index];
                          final isSelected = _selectedClientIds.contains(
                            client.id,
                          );
                          return Column(
                            children: [
                              InkWell(
                                onTap: () => _toggleClient(client.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm,
                                    horizontal: AppSpacing.xs,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: isSelected,
                                          onChanged: (_) =>
                                              _toggleClient(client.id),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          client.name,
                                          style: textTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (index < filtered.length - 1)
                                Divider(
                                  height: 1,
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
