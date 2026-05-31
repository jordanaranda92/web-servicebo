import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/presentation/bloc/feedback_cubit.dart';
import '../../../../core/presentation/widgets/feedback_banner.dart';
import '../../../../core/presentation/widgets/page_header.dart';
import '../../../../core/utils/category_color_utils.dart';
import '../../../clients/domain/entities/client.dart';
import '../../../clients/domain/entities/client_category.dart';
import '../../../clients/domain/usecases/save_clients_batch.dart';
import '../../../clients/domain/usecases/watch_clients.dart';
import '../bloc/client_categories_cubit.dart';
import '../bloc/client_categories_state.dart';
import '../widgets/associate_clients_dialog.dart';
import '../widgets/client_category_card.dart';
import '../widgets/no_color_painter.dart';

class ClientCategoriesPage extends StatefulWidget {
  const ClientCategoriesPage({super.key});

  @override
  State<ClientCategoriesPage> createState() => _ClientCategoriesPageState();
}

class _ClientCategoriesPageState extends State<ClientCategoriesPage> {
  late final ClientCategoriesCubit _cubit;
  late final FeedbackCubit _feedbackCubit;
  final _searchController = TextEditingController();

  Map<String, int> _clientCountByCategory = {};
  StreamSubscription<Either<Failure, List<Client>>>? _clientsSub;

  @override
  void initState() {
    super.initState();
    _cubit = sl<ClientCategoriesCubit>();
    _feedbackCubit = FeedbackCubit();
    _cubit.watchCategoriesStream();
    _watchClientCounts();
  }

  void _watchClientCounts() {
    final watchClients = sl<WatchClients>();
    _clientsSub = watchClients().listen((result) {
      result.fold((_) {}, (clients) {
        final counts = <String, int>{};
        for (final client in clients) {
          final catId = client.clientCategoryId;
          if (catId != null) {
            counts[catId] = (counts[catId] ?? 0) + 1;
          }
        }
        if (mounted) {
          setState(() => _clientCountByCategory = counts);
        }
      });
    });
  }

  @override
  void dispose() {
    _clientsSub?.cancel();
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
        PageHeader(title: l10n.menuClientCategories),
        const SizedBox(height: AppSpacing.md),
        BlocBuilder<ClientCategoriesCubit, ClientCategoriesState>(
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          builder: (context, state) {
            if (state is! ClientCategoriesLoaded) {
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
                    onPressed: () => _showAddCategoryDialog(context, l10n),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.clientCategoriesAdd),
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
        // FAB — only visible when categories are loaded
        BlocBuilder<ClientCategoriesCubit, ClientCategoriesState>(
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          builder: (context, state) {
            if (state is! ClientCategoriesLoaded) {
              return const SizedBox.shrink();
            }
            return Positioned(
              bottom: AppSpacing.md,
              right: AppSpacing.md,
              child: FloatingActionButton(
                onPressed: () => _showAddCategoryDialog(context, l10n),
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
    return BlocBuilder<ClientCategoriesCubit, ClientCategoriesState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      builder: (context, state) {
        if (state is! ClientCategoriesLoaded) return const SizedBox.shrink();
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

    return ListenableBuilder(
      listenable: _searchController,
      builder: (context, _) => TextField(
        controller: _searchController,
        style: onPrimary ? TextStyle(color: textColor) : null,
        onChanged: (value) => _cubit.filterByName(value),
        decoration: InputDecoration(
          hintText: l10n.clientCategoriesSearch,
          hintStyle: hintColor != null ? TextStyle(color: hintColor) : null,
          prefixIcon: Icon(Icons.search, size: 20, color: iconColor),
          suffixIcon: _searchController.text.isNotEmpty
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
      ),
    );
  }

  Widget _buildContent(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required bool isMobile,
  }) {
    return BlocBuilder<ClientCategoriesCubit, ClientCategoriesState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          (previous is ClientCategoriesLoaded &&
              current is ClientCategoriesLoaded &&
              previous != current),
      builder: (context, state) {
        if (state is ClientCategoriesLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ClientCategoriesError) {
          return _buildError(state, l10n, colorScheme, textTheme);
        }

        if (state is ClientCategoriesLoaded) {
          if (state.categories.isEmpty) {
            return Center(
              child: Text(
                l10n.clientCategoriesEmpty,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          if (isMobile) {
            return _buildCardList(state.categories, l10n);
          }

          return _buildTable(state.categories, l10n, colorScheme, textTheme);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCardList(
    List<ClientCategory> categories,
    AppLocalizations l10n,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 80),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return ClientCategoryCard(
          category: category,
          clientCount: _clientCountByCategory[category.id] ?? 0,
          onEditName: () => _showEditNameDialog(context, l10n, category),
          onEditColor: () => _showEditColorDialog(context, l10n, category),
          onAssociateClients: () =>
              _showAssociateClientsDialog(context, l10n, category),
          onDelete: () => _showDeleteConfirmation(context, l10n, category),
        );
      },
    );
  }

  Widget _buildError(
    ClientCategoriesError state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final message = switch (state.errorType) {
      ClientCategoriesErrorType.configNotFound => l10n.fdConfigNotFound,
      ClientCategoriesErrorType.network => l10n.fdNetworkError,
      ClientCategoriesErrorType.server => l10n.fdServerError,
      ClientCategoriesErrorType.unknown => l10n.fdUnknownError,
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
          if (state.errorType != ClientCategoriesErrorType.configNotFound)
            FilledButton.icon(
              onPressed: () => _cubit.watchCategoriesStream(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.fdRetry),
            ),
        ],
      ),
    );
  }

  Widget _buildTable(
    List<ClientCategory> categories,
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
          _buildTableHeader(headerStyle, outerBorder, l10n),
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
                  itemCount: categories.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: border.color),
                  itemBuilder: (context, index) {
                    return _buildCategoryRow(
                      categories[index],
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

  Widget _buildTableHeader(
    TextStyle? headerStyle,
    BorderSide outerBorder,
    AppLocalizations l10n,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
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
            child: Text(l10n.clientCategoriesColumnName, style: headerStyle),
          ),
          SizedBox(
            width: 150,
            child: Text(
              l10n.clientCategoriesColumnAssociatedClients,
              style: headerStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          SizedBox(
            width: 60,
            child: Text(
              l10n.clientCategoriesColumnColor,
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          SizedBox(
            width: 120,
            child: Text(
              l10n.clientCategoriesColumnActions,
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    ClientCategory category,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
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
                category.name,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 150,
              child: Text(
                '${_clientCountByCategory[category.id] ?? 0}',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            SizedBox(
              width: 60,
              child: Center(
                child: category.color != null
                    ? Container(
                        width: 28,
                        height: 18,
                        decoration: BoxDecoration(
                          color: tryParseHex(category.color),
                          borderRadius: BorderRadius.circular(AppRadii.small),
                        ),
                      )
                    : SizedBox(
                        width: 20,
                        height: 20,
                        child: CustomPaint(
                          painter: NoColorPainter(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            _buildCategoryActions(category, l10n, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryActions(
    ClientCategory category,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      width: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 32,
            width: 32,
            child: IconButton.filled(
              icon: const Icon(Icons.edit_outlined, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
              ),
              tooltip: l10n.clientCategoriesEdit,
              onPressed: () => _showEditDialog(context, l10n, category),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          SizedBox(
            height: 32,
            width: 32,
            child: IconButton.filled(
              icon: const Icon(Icons.people_outline_rounded, size: 16),
              style: IconButton.styleFrom(
                backgroundColor:
                    Theme.of(context)
                        .extension<CustomColors>()
                        ?.success
                        ?.withValues(alpha: 0.15) ??
                    Colors.green.shade50,
                foregroundColor:
                    Theme.of(context).extension<CustomColors>()?.success ??
                    Colors.green.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
              ),
              tooltip: l10n.clientCategoriesAssociateClients,
              onPressed: () =>
                  _showAssociateClientsDialog(context, l10n, category),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          SizedBox(
            height: 32,
            width: 32,
            child: IconButton.filled(
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
              ),
              tooltip: l10n.clientCategoriesDelete,
              onPressed: () => _showDeleteConfirmation(context, l10n, category),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, AppLocalizations l10n) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedColor;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            l10n.clientCategoriesAdd,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.clientCategoriesColumnName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.clientCategoriesNameRequired;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      final name = controller.text.trim();
                      Navigator.of(dialogContext).pop();
                      _runWithProgress(
                        progressMessage: l10n.clientCategoriesProgressSaving,
                        operation: () =>
                            _cubit.addCategory(name, color: selectedColor),
                        successMessage: l10n.clientCategoriesSuccessCreated,
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.clientCategoriesColorLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    GestureDetector(
                      onTap: () => setDialogState(() {
                        selectedColor = null;
                      }),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: selectedColor == null
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 2.5,
                                )
                              : Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                        ),
                        child: CustomPaint(
                          painter: NoColorPainter(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    ...kCategoryColors.map((hex) {
                      final color = tryParseHex(hex)!;
                      final isSelected = selectedColor == hex;
                      return GestureDetector(
                        onTap: () => setDialogState(() {
                          selectedColor = isSelected ? null : hex;
                        }),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    width: 2.5,
                                  )
                                : null,
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: contrastTextColor(color),
                                )
                              : null,
                        ),
                      );
                    }),
                  ],
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
                    progressMessage: l10n.clientCategoriesProgressSaving,
                    operation: () =>
                        _cubit.addCategory(name, color: selectedColor),
                    successMessage: l10n.clientCategoriesSuccessCreated,
                  );
                }
              },
              child: Text(l10n.settingsSave),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AppLocalizations l10n,
    ClientCategory category,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.clientCategoriesDeleteTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(l10n.clientCategoriesDeleteMessage(category.name)),
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
                progressMessage: l10n.clientCategoriesProgressDeleting,
                operation: () => _cubit.deleteCategory(category.id),
                successMessage: l10n.clientCategoriesSuccessDeleted,
              );
            },
            child: Text(l10n.clientCategoriesDelete),
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
        success ? successMessage : l10n.clientCategoriesErrorOperation,
        success: success,
      );
    }
  }

  void _showEditNameDialog(
    BuildContext context,
    AppLocalizations l10n,
    ClientCategory category,
  ) {
    final nameController = TextEditingController(text: category.name);
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.clientCategoriesEditName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.clientCategoriesColumnName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.clientCategoriesNameRequired;
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
                if (newName != category.name) {
                  _runWithProgress(
                    progressMessage: l10n.clientCategoriesProgressSaving,
                    operation: () => _cubit.updateCategory(
                      category.id,
                      newName,
                      color: category.color,
                    ),
                    successMessage: l10n.clientCategoriesSuccessSaved,
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

  void _showEditColorDialog(
    BuildContext context,
    AppLocalizations l10n,
    ClientCategory category,
  ) {
    String? selectedColor = category.color;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            l10n.clientCategoriesEditColor,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.clientCategoriesColorLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  GestureDetector(
                    onTap: () => setDialogState(() {
                      selectedColor = null;
                    }),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: selectedColor == null
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 2.5,
                              )
                            : Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                      ),
                      child: CustomPaint(
                        painter: NoColorPainter(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  ...kCategoryColors.map((hex) {
                    final color = tryParseHex(hex)!;
                    final isSelected = selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setDialogState(() {
                        selectedColor = isSelected ? null : hex;
                      }),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 2.5,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: contrastTextColor(color),
                              )
                            : null,
                      ),
                    );
                  }),
                ],
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
                Navigator.of(dialogContext).pop();
                if (selectedColor != category.color) {
                  _runWithProgress(
                    progressMessage: l10n.clientCategoriesProgressSaving,
                    operation: () => _cubit.updateCategory(
                      category.id,
                      category.name,
                      color: selectedColor,
                    ),
                    successMessage: l10n.clientCategoriesSuccessSaved,
                  );
                }
              },
              child: Text(l10n.settingsSave),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    AppLocalizations l10n,
    ClientCategory category,
  ) {
    final nameController = TextEditingController(text: category.name);
    final formKey = GlobalKey<FormState>();
    String? selectedColor = category.color;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            l10n.clientCategoriesEditTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.clientCategoriesColumnName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.clientCategoriesNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.clientCategoriesColorLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    GestureDetector(
                      onTap: () => setDialogState(() {
                        selectedColor = null;
                      }),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: selectedColor == null
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 2.5,
                                )
                              : Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                        ),
                        child: CustomPaint(
                          painter: NoColorPainter(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    ...kCategoryColors.map((hex) {
                      final color = tryParseHex(hex)!;
                      final isSelected = selectedColor == hex;
                      return GestureDetector(
                        onTap: () => setDialogState(() {
                          selectedColor = isSelected ? null : hex;
                        }),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    width: 2.5,
                                  )
                                : null,
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: contrastTextColor(color),
                                )
                              : null,
                        ),
                      );
                    }),
                  ],
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
                  if (newName != category.name ||
                      selectedColor != category.color) {
                    _runWithProgress(
                      progressMessage: l10n.clientCategoriesProgressSaving,
                      operation: () => _cubit.updateCategory(
                        category.id,
                        newName,
                        color: selectedColor,
                      ),
                      successMessage: l10n.clientCategoriesSuccessSaved,
                    );
                  }
                }
              },
              child: Text(l10n.settingsSave),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssociateClientsDialog(
    BuildContext context,
    AppLocalizations l10n,
    ClientCategory category,
  ) {
    final watchClients = sl<WatchClients>();
    final saveClientsBatch = sl<SaveClientsBatch>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AssociateClientsDialog(
        category: category,
        watchClients: watchClients,
        saveClientsBatch: saveClientsBatch,
        l10n: l10n,
        onSaved: (bool success) {
          _showFeedback(
            success
                ? l10n.clientCategoriesAssociateSuccess
                : l10n.clientCategoriesErrorOperation,
            success: success,
          );
        },
      ),
    );
  }
}
