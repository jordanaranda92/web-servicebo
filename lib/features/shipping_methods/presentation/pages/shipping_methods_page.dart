import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/presentation/bloc/feedback_cubit.dart';
import '../../../../core/presentation/widgets/feedback_banner.dart';
import '../../../../core/presentation/widgets/page_header.dart';
import '../../../../core/utils/day_utils.dart';
import '../../../clients/domain/entities/client.dart';
import '../../../clients/domain/usecases/save_clients_batch.dart';
import '../../../clients/domain/usecases/watch_clients.dart';
import '../../domain/entities/shipping_method.dart';
import '../bloc/shipping_methods_cubit.dart';
import '../bloc/shipping_methods_state.dart';
import '../widgets/shipping_method_card.dart';

class ShippingMethodsPage extends StatefulWidget {
  const ShippingMethodsPage({super.key});

  @override
  State<ShippingMethodsPage> createState() => _ShippingMethodsPageState();
}

class _ShippingMethodsPageState extends State<ShippingMethodsPage> {
  late final ShippingMethodsCubit _cubit;
  late final FeedbackCubit _feedbackCubit;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cubit = sl<ShippingMethodsCubit>();
    _feedbackCubit = FeedbackCubit();
    _cubit.watchMethodsStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _feedbackCubit.close();
    _cubit.close();
    super.dispose();
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
        PageHeader(title: l10n.menuShippingMethods),
        const SizedBox(height: AppSpacing.md),
        BlocBuilder<ShippingMethodsCubit, ShippingMethodsState>(
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          builder: (context, state) {
            if (state is! ShippingMethodsLoaded) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
                    onPressed: () => _showAddDialog(context, l10n),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.shippingMethodsAdd),
                  ),
                  const FeedbackBanner(),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
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
        BlocBuilder<ShippingMethodsCubit, ShippingMethodsState>(
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          builder: (context, state) {
            if (state is! ShippingMethodsLoaded) return const SizedBox.shrink();
            return Positioned(
              bottom: AppSpacing.md,
              right: AppSpacing.md,
              child: FloatingActionButton(
                onPressed: () => _showAddDialog(context, l10n),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                child: const Icon(Icons.add_rounded),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileSearchBar(AppLocalizations l10n, ColorScheme colorScheme) {
    return BlocBuilder<ShippingMethodsCubit, ShippingMethodsState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      builder: (context, state) {
        if (state is! ShippingMethodsLoaded) return const SizedBox.shrink();
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

    return TextField(
      controller: _searchController,
      style: onPrimary ? TextStyle(color: textColor) : null,
      onChanged: (value) {
        _cubit.filterByName(value);
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: l10n.shippingMethodsSearch,
        hintStyle: hintColor != null ? TextStyle(color: hintColor) : null,
        prefixIcon: Icon(Icons.search, size: 20, color: iconColor),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: 18, color: iconColor),
                onPressed: () {
                  _searchController.clear();
                  _cubit.filterByName('');
                  setState(() {});
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
  }

  Widget _buildContent(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required bool isMobile,
  }) {
    return BlocBuilder<ShippingMethodsCubit, ShippingMethodsState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          (previous is ShippingMethodsLoaded &&
              current is ShippingMethodsLoaded &&
              previous != current),
      builder: (context, state) {
        if (state is ShippingMethodsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ShippingMethodsError) {
          return _buildError(state, l10n, colorScheme, textTheme);
        }

        if (state is ShippingMethodsLoaded) {
          if (state.methods.isEmpty) {
            return Center(
              child: Text(
                l10n.shippingMethodsEmpty,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          if (isMobile) {
            return _buildCardList(state.methods, l10n);
          }

          return _buildTable(state.methods, l10n, colorScheme, textTheme);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCardList(List<ShippingMethod> methods, AppLocalizations l10n) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 80),
      itemCount: methods.length,
      itemBuilder: (context, index) {
        final method = methods[index];
        return ShippingMethodCard(
          method: method,
          onEditName: () => _showEditNameDialog(context, l10n, method),
          onEditPhone: () => _showEditPhoneDialog(context, l10n, method),
          onAssociateClients: () =>
              _showAssociateClientsDialog(context, l10n, method),
          onDelete: () => _showDeleteConfirmation(context, l10n, method),
        );
      },
    );
  }

  Widget _buildError(
    ShippingMethodsError state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final message = switch (state.errorType) {
      ShippingMethodsErrorType.network => l10n.fdNetworkError,
      ShippingMethodsErrorType.server => l10n.fdServerError,
      ShippingMethodsErrorType.unknown => l10n.fdUnknownError,
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
            onPressed: () => _cubit.watchMethodsStream(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.fdRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    List<ShippingMethod> methods,
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
                Expanded(
                  flex: 3,
                  child: Text(
                    l10n.shippingMethodsColumnName,
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    l10n.shippingMethodsColumnPhone,
                    style: headerStyle,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    l10n.shippingMethodsColumnActions,
                    style: headerStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
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
                  shrinkWrap: true,
                  itemCount: methods.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: border.color),
                  itemBuilder: (context, index) {
                    final method = methods[index];

                    return Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                method.name,
                                style: textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              flex: 2,
                              child: Text(
                                method.phone.isNotEmpty ? method.phone : '—',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: method.phone.isEmpty
                                      ? colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 32,
                                    width: 32,
                                    child: IconButton.filled(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            colorScheme.primaryContainer,
                                        foregroundColor:
                                            colorScheme.onPrimaryContainer,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.small,
                                          ),
                                        ),
                                      ),
                                      tooltip: l10n.shippingMethodsEdit,
                                      onPressed: () => _showEditDialog(
                                        context,
                                        l10n,
                                        method,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                  SizedBox(
                                    height: 32,
                                    width: 32,
                                    child: IconButton.filled(
                                      icon: const Icon(
                                        Icons.people_outline_rounded,
                                        size: 16,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(context)
                                                .extension<CustomColors>()
                                                ?.success
                                                ?.withValues(alpha: 0.15) ??
                                            Colors.green.shade50,
                                        foregroundColor:
                                            Theme.of(context)
                                                .extension<CustomColors>()
                                                ?.success ??
                                            Colors.green.shade800,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.small,
                                          ),
                                        ),
                                      ),
                                      tooltip:
                                          l10n.shippingMethodsAssociateClients,
                                      onPressed: () =>
                                          _showAssociateClientsDialog(
                                            context,
                                            l10n,
                                            method,
                                          ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                  SizedBox(
                                    height: 32,
                                    width: 32,
                                    child: IconButton.filled(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            colorScheme.errorContainer,
                                        foregroundColor:
                                            colorScheme.onErrorContainer,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.small,
                                          ),
                                        ),
                                      ),
                                      tooltip: l10n.shippingMethodsDelete,
                                      onPressed: () => _showDeleteConfirmation(
                                        context,
                                        l10n,
                                        method,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  void _showAddDialog(BuildContext context, AppLocalizations l10n) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.shippingMethodsAdd,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shippingMethodsColumnName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: controller,
                autofocus: true,
                maxLength: 50,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.shippingMethodsNameRequired;
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() ?? false) {
                    final name = controller.text.trim();
                    Navigator.of(dialogContext).pop();
                    _runWithProgress(
                      progressMessage: l10n.shippingMethodsProgressSaving,
                      operation: () => _cubit.addMethod(name),
                      successMessage: l10n.shippingMethodsSuccessCreated,
                    );
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final name = controller.text.trim();
                Navigator.of(dialogContext).pop();
                _runWithProgress(
                  progressMessage: l10n.shippingMethodsProgressSaving,
                  operation: () => _cubit.addMethod(name),
                  successMessage: l10n.shippingMethodsSuccessCreated,
                );
              }
            },
            child: Text(l10n.settingsSave),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AppLocalizations l10n,
    ShippingMethod method,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.shippingMethodsDeleteTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(l10n.shippingMethodsDeleteMessage(method.name)),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _runWithProgress(
                progressMessage: l10n.shippingMethodsProgressDeleting,
                operation: () => _cubit.deleteMethod(method.id),
                successMessage: l10n.shippingMethodsSuccessDeleted,
              );
            },
            child: Text(l10n.shippingMethodsDelete),
          ),
        ],
      ),
    );
  }

  Future<void> _runWithProgress({
    required String progressMessage,
    required Future<bool> Function() operation,
    required String successMessage,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          content: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: AppSpacing.lg),
                Text(progressMessage),
              ],
            ),
          ),
        ),
      ),
    );

    final stopwatch = Stopwatch()..start();

    final success = await operation();

    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 500) {
      await Future.delayed(Duration(milliseconds: 500 - elapsed));
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _showFeedback(
        success ? successMessage : l10n.shippingMethodsErrorOperation,
        success: success,
      );
    }
  }

  void _showEditNameDialog(
    BuildContext context,
    AppLocalizations l10n,
    ShippingMethod method,
  ) {
    final nameController = TextEditingController(text: method.name);
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.shippingMethodsEditName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shippingMethodsColumnName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: nameController,
                autofocus: true,
                maxLength: 50,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.shippingMethodsNameRequired;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final newName = nameController.text.trim();
                Navigator.of(dialogContext).pop();
                if (newName != method.name) {
                  _runWithProgress(
                    progressMessage: l10n.shippingMethodsProgressSaving,
                    operation: () => _cubit.updateName(method.id, newName),
                    successMessage: l10n.shippingMethodsSuccessSaved,
                  );
                }
              }
            },
            child: Text(l10n.settingsSave),
          ),
        ],
      ),
    );
  }

  void _showEditPhoneDialog(
    BuildContext context,
    AppLocalizations l10n,
    ShippingMethod method,
  ) {
    final phoneController = TextEditingController(text: method.phone);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.shippingMethodsEditPhone,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shippingMethodsColumnPhone,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: phoneController,
              autofocus: true,
              maxLength: 9,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: l10n.shippingMethodsPhoneHint,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            onPressed: () {
              final newPhone = phoneController.text.trim();
              Navigator.of(dialogContext).pop();
              if (newPhone != method.phone &&
                  (newPhone.isEmpty || newPhone.length == 9)) {
                _runWithProgress(
                  progressMessage: l10n.shippingMethodsProgressSaving,
                  operation: () => _cubit.updatePhone(method.id, newPhone),
                  successMessage: l10n.shippingMethodsSuccessSaved,
                );
              }
            },
            child: Text(l10n.settingsSave),
          ),
        ],
      ),
    );
  }

  void _showAssociateClientsDialog(
    BuildContext context,
    AppLocalizations l10n,
    ShippingMethod method,
  ) {
    final watchClients = sl<WatchClients>();
    final saveClientsBatch = sl<SaveClientsBatch>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => _AssociateShippingClientsDialog(
        method: method,
        watchClients: watchClients,
        saveClientsBatch: saveClientsBatch,
        l10n: l10n,
        onSaved: (success) {
          _showFeedback(
            success
                ? l10n.shippingMethodsSuccessSaved
                : l10n.shippingMethodsErrorOperation,
            success: success,
          );
        },
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    AppLocalizations l10n,
    ShippingMethod method,
  ) {
    final nameController = TextEditingController(text: method.name);
    final phoneController = TextEditingController(text: method.phone);
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.shippingMethodsEditTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shippingMethodsColumnName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: nameController,
                autofocus: true,
                maxLength: 50,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.shippingMethodsNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.shippingMethodsColumnPhone,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: phoneController,
                maxLength: 9,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: l10n.shippingMethodsPhoneHint,
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final newName = nameController.text.trim();
                final newPhone = phoneController.text.trim();
                Navigator.of(dialogContext).pop();
                _saveEdit(method, newName, newPhone);
              }
            },
            child: Text(l10n.settingsSave),
          ),
        ],
      ),
    );
  }

  void _saveEdit(ShippingMethod method, String newName, String newPhone) {
    final l10n = AppLocalizations.of(context)!;
    final nameChanged = newName != method.name;
    final phoneChanged = newPhone != method.phone;

    if (!nameChanged && !phoneChanged) return;

    _runWithProgress(
      progressMessage: l10n.shippingMethodsProgressSaving,
      operation: () async {
        var success = true;
        if (nameChanged) {
          success = await _cubit.updateName(method.id, newName);
        }
        if (success && phoneChanged) {
          if (newPhone.isEmpty || newPhone.length == 9) {
            success = await _cubit.updatePhone(method.id, newPhone);
          }
        }
        return success;
      },
      successMessage: l10n.shippingMethodsSuccessSaved,
    );
  }
}

// ─── Associate Clients Dialog ────────────────────────────────────────

class _AssociateShippingClientsDialog extends StatefulWidget {
  final ShippingMethod method;
  final WatchClients watchClients;
  final SaveClientsBatch saveClientsBatch;
  final AppLocalizations l10n;
  final ValueChanged<bool> onSaved;

  const _AssociateShippingClientsDialog({
    required this.method,
    required this.watchClients,
    required this.saveClientsBatch,
    required this.l10n,
    required this.onSaved,
  });

  @override
  State<_AssociateShippingClientsDialog> createState() =>
      _AssociateShippingClientsDialogState();
}

class _AssociateShippingClientsDialogState
    extends State<_AssociateShippingClientsDialog> {
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
