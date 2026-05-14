import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/router/router.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/presentation/widgets/page_header.dart';
import '../../../../core/utils/day_utils.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/fd_contact_data.dart';
import '../../domain/usecases/get_client_fd_data.dart';
import '../../../shipping_methods/domain/entities/shipping_method.dart';
import '../../../shipping_methods/domain/usecases/get_shipping_methods.dart';
import '../../../../core/usecase/usecase.dart';
import '../bloc/clients_cubit.dart';
import '../bloc/clients_state.dart';
import '../widgets/category_badge.dart';
import '../widgets/client_data_edit_dialog.dart';
import '../widgets/shipping_methods_by_day_dialog.dart';

class ClientDetailPage extends StatefulWidget {
  final String clientId;
  final Client? client;

  const ClientDetailPage({super.key, required this.clientId, this.client});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  Client? _client;
  bool _loading = true;
  bool _notFound = false;
  FdContactData? _fdData;
  bool _fdLoading = false;
  bool _fdError = false;
  List<ShippingMethod>? _shippingMethods;
  StreamSubscription<ClientsState>? _clientsStreamSub;

  @override
  void initState() {
    super.initState();
    _resolveClient();
  }

  @override
  void dispose() {
    _clientsStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _resolveClient() async {
    // If the client was passed via extra (in-app navigation), use it directly
    if (widget.client != null) {
      _client = widget.client;
      setState(() => _loading = false);
      _loadFdData();
      _loadShippingMethods();
      return;
    }

    // Deep link: try to find client in cubit cache or fetch
    final cubit = sl<ClientsCubit>();
    final state = cubit.state;
    if (state is ClientsLoaded) {
      final match = state.allClients
          .where((c) => c.id == widget.clientId)
          .firstOrNull;
      if (match != null) {
        _client = match;
        setState(() => _loading = false);
        _loadFdData();
        _loadShippingMethods();
        return;
      }
    }

    // Start watching and wait for first emission
    cubit.watchClientsStream();
    _clientsStreamSub = cubit.stream.listen((s) {
      if (!mounted) {
        _clientsStreamSub?.cancel();
        return;
      }
      if (s is ClientsLoaded) {
        final match = s.allClients
            .where((c) => c.id == widget.clientId)
            .firstOrNull;
        _client = match;
        setState(() {
          _loading = false;
          _notFound = match == null;
        });
        if (match != null) {
          _loadFdData();
          _loadShippingMethods();
        }
        _clientsStreamSub?.cancel();
      }
      if (s is ClientsError) {
        setState(() {
          _loading = false;
          _notFound = true;
        });
        _clientsStreamSub?.cancel();
      }
    });
  }

  Future<void> _loadShippingMethods() async {
    final getShippingMethods = sl<GetShippingMethods>();
    final result = await getShippingMethods(NoParams());
    if (!mounted) return;
    result.fold(
      (_) {},
      (methods) => setState(() => _shippingMethods = methods),
    );
  }

  Future<void> _loadFdData() async {
    final client = _client;
    if (client == null) return;
    final uuid = client.facturaDirectaUuid;
    if (uuid.isEmpty) return;

    setState(() {
      _fdLoading = true;
      _fdError = false;
    });

    final getClientFdData = sl<GetClientFdData>();
    final result = await getClientFdData(uuid);
    if (!mounted) return;

    result.fold(
      (_) => setState(() {
        _fdLoading = false;
        _fdError = true;
      }),
      (data) => setState(() {
        _fdLoading = false;
        _fdData = data;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notFound || _client == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_rounded,
              size: AppIconSizes.xl,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.clientNotFoundMessage,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.clients),
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(l10n.clientNotFoundGoBack),
            ),
          ],
        ),
      );
    }

    final client = _client!;
    final categoryName = client.categoryName;
    final hasCategory = categoryName != null && categoryName.isNotEmpty;
    final isMobile =
        MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint;

    if (isMobile) {
      return _buildMobileBody(
        client,
        l10n,
        colorScheme,
        textTheme,
        hasCategory,
      );
    }

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
                tooltip: l10n.settingsCancel,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.clientsDetailTitle,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: const [],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client data section
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.clientsClientDataSection,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showEditDialog(context, l10n),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l10n.clientsEdit),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        _FdDataRow(
                          icon: Icons.person_outline,
                          label: l10n.clientsColumnName,
                          value: client.name,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                        _fdDivider(colorScheme),
                        _buildCategoryRow(
                          client,
                          l10n,
                          colorScheme,
                          textTheme,
                          hasCategory,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // FD data section
                Text(
                  l10n.clientsFdDataSection,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _buildFdDataContent(
                      client,
                      l10n,
                      colorScheme,
                      textTheme,
                    ),
                  ),
                ),
                ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.clientsColumnShippingMethods,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showShippingEditDialog(context, l10n),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(l10n.clientsEdit),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: _buildShippingRows(
                          client,
                          l10n,
                          colorScheme,
                          textTheme,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final client = _client;
    if (client == null) return;

    final messenger = ScaffoldMessenger.of(context);

    final updated = await showDialog<Client>(
      context: context,
      builder: (_) => ClientDataEditDialog(client: client),
    );

    if (updated != null && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.clientSaveSuccess)));
      setState(() => _client = updated);
    }
  }

  Future<void> _showShippingEditDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final client = _client;
    if (client == null) return;

    final methods = _shippingMethods;
    if (methods == null || methods.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (_) => ShippingMethodsByDayDialog(
        shippingMethods: methods,
        currentAssignments: client.shippingMethodsByDay,
      ),
    );

    if (result != null && mounted) {
      final newAssignments = {
        for (final e in result.entries)
          if (e.value != null) e.key: e.value!,
      };

      final cubit = sl<ClientsCubit>();
      final success = await cubit.saveBatchChanges(
        shippingMethodsByDayChanges: {
          client.id: {
            for (final e in newAssignments.entries) e.key: e.value,
            for (final day in client.shippingMethodsByDay.keys)
              if (!newAssignments.containsKey(day)) day: null,
          },
        },
      );

      if (success && mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.clientSaveSuccess)));
        setState(() {
          _client = client.copyWith(shippingMethodsByDay: newAssignments);
        });
      }
    }
  }

  Widget _buildMobileBody(
    Client client,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool hasCategory,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client data section
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.clientsClientDataSection,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showEditDialog(context, l10n),
                style: TextButton.styleFrom(
                  textStyle: textTheme.labelLarge,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(l10n.clientsEdit),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _FdDataRow(
                    icon: Icons.person_outline,
                    label: l10n.clientsColumnName,
                    value: client.name,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  _fdDivider(colorScheme),
                  _buildCategoryRow(
                    client,
                    l10n,
                    colorScheme,
                    textTheme,
                    hasCategory,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // FD data section
          Text(
            l10n.clientsFdDataSection,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _buildFdDataContent(client, l10n, colorScheme, textTheme),
            ),
          ),
          ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.clientsColumnShippingMethods,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showShippingEditDialog(context, l10n),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs,
                    ),
                    textStyle: textTheme.labelLarge,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(l10n.clientsEdit),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.medium),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: _buildShippingRows(
                    client,
                    l10n,
                    colorScheme,
                    textTheme,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFdDataContent(
    Client client,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (_fdLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_fdError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: colorScheme.onSurfaceVariant,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.clientsFdLoadError,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: _loadFdData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.fdRetry),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _FdDataRow(
          icon: Icons.badge_outlined,
          label: l10n.clientsColumnFiscalId,
          value: _fdData?.fiscalId,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _fdDivider(colorScheme),
        _FdDataRow(
          icon: Icons.person_outline,
          label: l10n.clientsColumnName,
          value: _fdData?.name ?? client.facturaDirectaName,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _fdDivider(colorScheme),
        _FdDataRow(
          icon: Icons.email_outlined,
          label: l10n.clientsColumnEmail,
          value: _fdData?.email,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _fdDivider(colorScheme),
        _FdDataRow(
          icon: Icons.phone_outlined,
          label: l10n.clientsColumnPhone,
          value: _fdData?.phone,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _fdDivider(colorScheme),
        _FdDataRow(
          icon: Icons.location_city_outlined,
          label: l10n.clientsColumnCity,
          value: _fdData?.city,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _fdDivider(colorScheme),
        _FdDataRow(
          icon: Icons.map_outlined,
          label: l10n.clientsColumnProvince,
          value: _fdData?.province,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _fdDivider(colorScheme),
        _FdDataRow(
          icon: Icons.flag_outlined,
          label: l10n.clientsColumnCountry,
          value: _fdData?.country,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _fdDivider(colorScheme),
        _FdDataRow(
          icon: Icons.payment_outlined,
          label: l10n.clientsColumnPaymentMethod,
          value: _fdData?.paymentMethod,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _fdDivider(colorScheme),
        _FdDataRow(
          icon: Icons.euro_outlined,
          label: l10n.clientsColumnCurrency,
          value: _fdData?.currency,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      ],
    );
  }

  Widget _buildCategoryRow(
    Client client,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool hasCategory,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            Icons.label_outline,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 140,
            child: Text(
              l10n.clientsColumnCategory,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: hasCategory
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: CategoryBadge(
                      name: client.categoryName!,
                      color: client.categoryColor,
                    ),
                  )
                : Text(
                    l10n.clientsCategoryUnspecified,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _shippingMethodName(String methodId) {
    final methods = _shippingMethods;
    if (methods == null) return methodId;
    final match = methods.where((m) => m.id == methodId);
    return match.isNotEmpty ? match.first.name : methodId;
  }

  List<Widget> _buildShippingRows(
    Client client,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final assignments = client.shippingMethodsByDay;

    final widgets = <Widget>[];
    for (var i = 0; i < dayOrder.length; i++) {
      if (i > 0) widgets.add(_fdDivider(colorScheme));
      final day = dayOrder[i];
      final methodId = assignments[day];
      final hasMethod = methodId != null && methodId.isNotEmpty;
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Icon(
                Icons.local_shipping_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 140,
                child: Text(
                  localizedDay(day, l10n),
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  hasMethod
                      ? _shippingMethodName(methodId)
                      : l10n.clientsShippingMethodUndefined,
                  style: textTheme.bodyMedium?.copyWith(
                    color: hasMethod ? null : colorScheme.onSurfaceVariant,
                    fontStyle: hasMethod ? null : FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

Widget _fdDivider(ColorScheme colorScheme) {
  return Divider(
    height: AppSpacing.md,
    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
  );
}

class _FdDataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _FdDataRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hasValue ? value! : '—',
              style: textTheme.bodyMedium?.copyWith(
                color: hasValue ? null : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
