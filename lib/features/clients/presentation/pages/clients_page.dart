import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/presentation/bloc/feedback_cubit.dart';
import '../../../../core/presentation/widgets/feedback_banner.dart';
import '../../../../core/presentation/widgets/page_header.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/fd_new_contact.dart';
import '../bloc/clients_cubit.dart';
import '../bloc/clients_state.dart';
import '../widgets/client_card.dart';
import '../widgets/category_badge.dart';
import '../widgets/select_fd_contacts_dialog.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  late final ClientsCubit _cubit;
  late final FeedbackCubit _feedbackCubit;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cubit = sl<ClientsCubit>();
    _feedbackCubit = FeedbackCubit();
    _cubit.watchClientsStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _feedbackCubit.close();
    _cubit.close();
    super.dispose();
  }

  Future<void> _addFromFd(AppLocalizations l10n) async {
    // Show loading dialog while fetching contacts
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: Text(l10n.clientsAddFromFdLoading)),
            ],
          ),
        ),
      ),
    );

    final result = await _cubit.fetchNewContacts();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    result.fold(
      (_) => _showFeedback(l10n.clientsAddFromFdError, success: false),
      (newContacts) async {
        if (newContacts.isEmpty) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              icon: Icon(
                Icons.check_circle_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: AppIconSizes.xl,
              ),
              title: Text(l10n.clientsAddFromFdNoNewTitle),
              content: Text(l10n.clientsAddFromFdNoNew),
              actions: [
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: Text(l10n.clientsAddFromFdNoNewOk),
                ),
              ],
            ),
          );
          return;
        }

        final selected = await showDialog<List<FdNewContact>>(
          context: context,
          builder: (_) => SelectFdContactsDialog(contacts: newContacts),
        );

        if (selected == null || selected.isEmpty || !mounted) return;

        // Show loading dialog while adding
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: Text(l10n.clientsAddFromFdAdding)),
                ],
              ),
            ),
          ),
        );

        final success = await _cubit.addSelectedContacts(selected);

        if (success) {
          await _cubit.reloadFiscalIds();
        }

        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();

        _showFeedback(
          success
              ? l10n.clientsAddFromFdSuccess(selected.length)
              : l10n.clientsAddFromFdError,
          success: success,
        );
      },
    );
  }

  void _showFeedback(String message, {required bool success}) {
    final isMobile =
        MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint;
    if (isMobile) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } else {
      _feedbackCubit.show(message, isSuccess: success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isMobile =
        MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
        BlocProvider.value(value: _feedbackCubit),
      ],
      child: isMobile
          ? _buildMobileLayout(l10n, colorScheme, textTheme)
          : _buildDesktopLayout(l10n, colorScheme, textTheme),
    );
  }

  // ─── Desktop layout (unchanged) ──────────────────────────────────────

  Widget _buildDesktopLayout(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(title: l10n.menuClients),
        BlocBuilder<ClientsCubit, ClientsState>(
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          builder: (context, state) {
            if (state is! ClientsLoaded) return const SizedBox.shrink();
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
                  const SizedBox(width: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: () => _addFromFd(l10n),
                    icon: const Icon(Icons.person_add_rounded),
                    label: Text(l10n.clientsAddFromFd),
                  ),
                  const FeedbackBanner(),
                ],
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
    return Stack(
      children: [
        Column(
          children: [
            _buildMobileSearchBar(l10n, colorScheme),
            Expanded(
              child: _buildContent(
                l10n,
                colorScheme,
                textTheme,
                isMobile: true,
              ),
            ),
          ],
        ),
        // FAB — only visible when clients are loaded
        BlocBuilder<ClientsCubit, ClientsState>(
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          builder: (context, state) {
            if (state is! ClientsLoaded) return const SizedBox.shrink();
            return Positioned(
              bottom: AppSpacing.md,
              right: AppSpacing.md,
              child: FloatingActionButton(
                onPressed: () => _addFromFd(l10n),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                child: const Icon(Icons.person_add_rounded),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileSearchBar(AppLocalizations l10n, ColorScheme colorScheme) {
    return BlocBuilder<ClientsCubit, ClientsState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      builder: (context, state) {
        if (state is! ClientsLoaded) return const SizedBox.shrink();
        return Container(
          color: colorScheme.primary,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: _buildSearchField(l10n, colorScheme, onPrimary: true),
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
          onChanged: (v) => _cubit.filterByName(v),
          decoration: InputDecoration(
            hintText: l10n.clientsSearch,
            hintStyle: hintColor != null ? TextStyle(color: hintColor) : null,
            prefixIcon: Icon(Icons.search, size: 20, color: iconColor),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: iconColor),
                    onPressed: () {
                      _searchController.clear();
                      _cubit.filterByName('');
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
    return BlocBuilder<ClientsCubit, ClientsState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          (previous is ClientsLoaded &&
              current is ClientsLoaded &&
              previous != current),
      builder: (context, state) {
        if (state is ClientsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ClientsError) {
          return _buildError(state, l10n, colorScheme, textTheme);
        }

        if (state is ClientsLoaded) {
          if (state.filteredClients.isEmpty) {
            return Center(
              child: Text(
                l10n.clientsEmpty,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          if (isMobile) {
            return _buildCardList(state.filteredClients, state.fiscalIdsByUuid);
          }

          return _buildTable(
            state.filteredClients,
            l10n,
            colorScheme,
            textTheme,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCardList(
    List<Client> clients,
    Map<String, String> fiscalIdsByUuid,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 80),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        return ClientCard(
          client: client,
          fiscalId: fiscalIdsByUuid[client.facturaDirectaUuid],
          onTap: () =>
              context.push('/clients/${client.id}/detail', extra: client),
        );
      },
    );
  }

  Widget _buildError(
    ClientsError state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final message = switch (state.errorType) {
      ClientsErrorType.network => l10n.fdNetworkError,
      ClientsErrorType.server => l10n.fdServerError,
      ClientsErrorType.unknown => l10n.fdUnknownError,
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
          FilledButton.icon(
            onPressed: () => _cubit.watchClientsStream(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.fdRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    List<Client> clients,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
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
                SizedBox(
                  width: 120,
                  child: Text(l10n.clientsColumnFiscalId, style: headerStyle),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 3,
                  child: Text(l10n.clientsColumnName, style: headerStyle),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: Text(l10n.clientsColumnNameFd, style: headerStyle),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: Text(l10n.clientsColumnCategory, style: headerStyle),
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
                  itemCount: clients.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: border.color),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    final loadedState = _cubit.state as ClientsLoaded;
                    return _buildRow(
                      client,
                      loadedState.fiscalIdsByUuid,
                      l10n,
                      colorScheme,
                      textTheme,
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

  Widget _buildRow(
    Client client,
    Map<String, String> fiscalIdsByUuid,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final categoryName = client.categoryName;
    final hasCategory = categoryName != null && categoryName.isNotEmpty;
    final fiscalId = fiscalIdsByUuid[client.facturaDirectaUuid];

    return InkWell(
      onTap: () => context.push('/clients/${client.id}/detail', extra: client),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                fiscalId ?? '—',
                style: textTheme.bodyMedium?.copyWith(
                  color: fiscalId != null ? null : colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 3,
              child: Text(
                client.name,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(
                client.facturaDirectaName,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: hasCategory
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: CategoryBadge(
                        name: categoryName,
                        color: client.categoryColor,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
