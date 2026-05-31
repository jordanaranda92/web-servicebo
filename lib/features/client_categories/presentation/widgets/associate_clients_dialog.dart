import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../clients/domain/entities/client.dart';
import '../../../clients/domain/entities/client_category.dart';
import '../../../clients/domain/usecases/save_clients_batch.dart';
import '../../../clients/domain/usecases/watch_clients.dart';

class AssociateClientsDialog extends StatefulWidget {
  final ClientCategory category;
  final WatchClients watchClients;
  final SaveClientsBatch saveClientsBatch;
  final AppLocalizations l10n;
  final ValueChanged<bool> onSaved;

  const AssociateClientsDialog({
    super.key,
    required this.category,
    required this.watchClients,
    required this.saveClientsBatch,
    required this.l10n,
    required this.onSaved,
  });

  @override
  State<AssociateClientsDialog> createState() => _AssociateClientsDialogState();
}

class _AssociateClientsDialogState extends State<AssociateClientsDialog> {
  List<Client>? _allClients;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedClientIds = {};
  Set<String> _initialClientIds = {};
  bool _isSaving = false;

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
            setState(() => _error = widget.l10n.clientCategoriesAssociateError),
        (clients) {
          final initialIds = clients
              .where((c) => c.clientCategoryId == widget.category.id)
              .map((c) => c.id)
              .toSet();
          setState(() {
            _allClients = clients;
            _selectedClientIds.addAll(initialIds);
            _initialClientIds = Set.from(initialIds);
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = widget.l10n.clientCategoriesAssociateError);
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

  bool get _hasChanges => !_setEquals(_selectedClientIds, _initialClientIds);

  bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final categoryChanges = <String, String?>{};

    // Clients newly associated
    for (final id in _selectedClientIds) {
      if (!_initialClientIds.contains(id)) {
        categoryChanges[id] = widget.category.id;
      }
    }

    // Clients disassociated
    for (final id in _initialClientIds) {
      if (!_selectedClientIds.contains(id)) {
        categoryChanges[id] = null;
      }
    }

    if (categoryChanges.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final result = await widget.saveClientsBatch(
      SaveClientsBatchParams(categoryChanges: categoryChanges),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSaved(result.isRight());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borderColor = colorScheme.outlineVariant;

    return AlertDialog(
      title: Text(l10n.clientCategoriesAssociateTitle(widget.category.name)),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: 500,
        height: 500,
        child: _buildContent(l10n, colorScheme, textTheme, borderColor),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.settingsCancel),
        ),
        if (_allClients != null && _allClients!.isNotEmpty)
          FilledButton(
            onPressed: _isSaving || !_hasChanges ? null : _save,
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
    Color borderColor,
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_allClients == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allClients!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: AppIconSizes.xl,
              color: colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.clientCategoriesAssociateNoClients,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final filtered = _filteredClients;

    return Column(
      children: [
        // ── Search field ──
        SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: l10n.clientCategoriesAssociateSearch,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
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
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // ── Table header ──
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadii.small),
              topRight: Radius.circular(AppRadii.small),
            ),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: Text(
                  l10n.clientCategoriesColumnName,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Table body ──
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppRadii.small),
                bottomRight: Radius.circular(AppRadii.small),
              ),
              border: Border(
                left: BorderSide(color: borderColor),
                right: BorderSide(color: borderColor),
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      l10n.clientCategoriesAssociateNoClients,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: borderColor.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (context, index) {
                      final client = filtered[index];
                      final isSelected = _selectedClientIds.contains(client.id);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          hoverColor: colorScheme.surfaceContainerLow,
                          onTap: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedClientIds.remove(client.id);
                                    } else {
                                      _selectedClientIds.add(client.id);
                                    }
                                  });
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: _isSaving
                                        ? null
                                        : (_) {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedClientIds.remove(
                                                  client.id,
                                                );
                                              } else {
                                                _selectedClientIds.add(
                                                  client.id,
                                                );
                                              }
                                            });
                                          },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    client.name,
                                    overflow: TextOverflow.ellipsis,
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
    );
  }
}
