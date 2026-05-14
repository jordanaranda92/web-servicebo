import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/presentation/bloc/feedback_cubit.dart';
import '../../../../core/presentation/widgets/feedback_banner.dart';
import '../../../../core/presentation/widgets/page_header.dart';
import '../../domain/entities/fd_product.dart';
import '../../domain/entities/product.dart';
import '../bloc/products_cubit.dart';
import '../bloc/products_state.dart';
import '../widgets/fd_product_selector_dialog.dart';
import '../widgets/expandable_fab.dart';
import '../widgets/product_card.dart';
import '../widgets/product_edit_dialog.dart';
import '../widgets/product_reorder_dialog.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late final ProductsCubit _cubit;
  late final FeedbackCubit _feedbackCubit;
  final _searchController = TextEditingController();
  final _fabKey = GlobalKey<ExpandableFabState>();
  bool _fabOpen = false;

  // Persistent controllers for text fields
  final Map<String, TextEditingController> _nameControllers = {};

  // Cached FD products loaded once on init
  List<FdProduct>? _cachedFdProducts;
  Map<String, FdProduct> _fdProductMap = {};
  bool _fdLoaded = false;

  @override
  void initState() {
    super.initState();
    _cubit = sl<ProductsCubit>();
    _feedbackCubit = FeedbackCubit();
    _cubit.watchProductsStream();
    _loadFdProducts();
  }

  @override
  void dispose() {
    _savePendingChangesAndClose();
    _searchController.dispose();
    for (final c in _nameControllers.values) {
      c.dispose();
    }
    _feedbackCubit.close();
    super.dispose();
  }

  Future<void> _savePendingChangesAndClose() async {
    final state = _cubit.state;
    if (state is ProductsLoaded) {
      final productMap = {for (final p in state.allProducts) p.id: p};
      final nameChanges = <String, String>{};

      for (final entry in _nameControllers.entries) {
        final product = productMap[entry.key];
        if (product == null) continue;
        final trimmed = entry.value.text.trim();
        if (trimmed.isNotEmpty && trimmed != product.name) {
          nameChanges[entry.key] = trimmed;
        }
      }

      if (nameChanges.isNotEmpty) {
        await _cubit.saveBatchChanges(nameChanges: nameChanges);
      }
    }
    await _cubit.close();
  }

  Future<void> _saveField(
    String productId, {
    String? name,
    bool? isActive,
    int? order,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    await _runWithProgress(
      action: () => _cubit.saveBatchChanges(
        nameChanges: name != null ? {productId: name} : const {},
        activeToggles: isActive != null ? {productId: isActive} : const {},
        orderChanges: order != null ? {productId: order} : const {},
      ),
      successMessage: l10n.productsSuccessSaved,
      errorMessage: l10n.productsErrorSaving,
    );
  }

  Future<void> _runWithProgress({
    required Future<bool> Function() action,
    required String successMessage,
    required String errorMessage,
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
                Text(l10n.productsSaving),
              ],
            ),
          ),
        ),
      ),
    );

    final stopwatch = Stopwatch()..start();
    final success = await action();

    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 500) {
      await Future.delayed(Duration(milliseconds: 500 - elapsed));
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _showFeedback(success ? successMessage : errorMessage, success: success);
    }
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
        PageHeader(title: l10n.menuProducts),
        BlocBuilder<ProductsCubit, ProductsState>(
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          builder: (context, state) {
            if (state is! ProductsLoaded) return const SizedBox.shrink();
            final hasProducts = state.allProducts.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  if (hasProducts) ...[
                    Expanded(
                      child: SizedBox(
                        height: AppDimensions.searchBoxHeight,
                        child: _buildSearchField(l10n, colorScheme),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  FilledButton.icon(
                    onPressed: () => _showAddProductDialog(context, l10n),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.productsAdd),
                  ),
                  if (hasProducts) ...[
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () {
                        final currentState = _cubit.state;
                        if (currentState is ProductsLoaded) {
                          _showReorderDialog(
                            context,
                            currentState.allProducts,
                            l10n,
                          );
                        }
                      },
                      icon: const Icon(Icons.swap_vert_rounded),
                      label: Text(l10n.productsReorder),
                    ),
                  ],
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
        // Barrier to close FAB on outside tap
        if (_fabOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _fabKey.currentState?.close(),
              behavior: HitTestBehavior.opaque,
            ),
          ),
        // FAB — only visible when products are loaded
        BlocBuilder<ProductsCubit, ProductsState>(
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          builder: (context, state) {
            if (state is! ProductsLoaded) return const SizedBox.shrink();
            return Positioned(
              bottom: AppSpacing.md,
              right: AppSpacing.md,
              child: ExpandableFab(
                key: _fabKey,
                colorScheme: colorScheme,
                onOpenChanged: (open) => setState(() => _fabOpen = open),
                items: [
                  FabItem(
                    icon: Icons.add_rounded,
                    label: l10n.productsAdd,
                    onTap: () => _showAddProductDialog(context, l10n),
                  ),
                  FabItem(
                    icon: Icons.swap_vert_rounded,
                    label: l10n.productsReorder,
                    onTap: () {
                      final currentState = _cubit.state;
                      if (currentState is ProductsLoaded) {
                        _showReorderDialog(
                          context,
                          currentState.allProducts,
                          l10n,
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileSearchBar(AppLocalizations l10n, ColorScheme colorScheme) {
    return BlocBuilder<ProductsCubit, ProductsState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      builder: (context, state) {
        if (state is! ProductsLoaded) return const SizedBox.shrink();
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
            hintText: l10n.productsSearch,
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
    return BlocBuilder<ProductsCubit, ProductsState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          (previous is ProductsLoaded &&
              current is ProductsLoaded &&
              previous != current),
      builder: (context, state) {
        if (state is ProductsLoading || !_fdLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ProductsError) {
          return _buildError(state, l10n, colorScheme, textTheme);
        }

        if (state is ProductsLoaded) {
          if (state.filteredProducts.isEmpty) {
            return Center(
              child: Text(
                l10n.productsEmpty,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          if (isMobile) {
            return _buildCardList(state.filteredProducts, l10n);
          }

          return _buildTable(
            state.filteredProducts,
            l10n,
            colorScheme,
            textTheme,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCardList(List<Product> products, AppLocalizations l10n) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 80),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final fdProduct = product.facturaDirectaUuid.isNotEmpty
            ? _fdProductMap[product.facturaDirectaUuid]
            : null;
        return ProductCard(
          product: product,
          fdProduct: fdProduct,
          onEditName: () => _showEditDialog(product, l10n),
          onLink: () => _showFdProductSelector(product),
          onUnlink: () => _unlinkFdProduct(product),
          onToggleActive: () =>
              _saveField(product.id, isActive: !product.isActive),
          onDelete: () => _showDeleteConfirmation(context, l10n, product),
        );
      },
    );
  }

  Future<void> _showEditDialog(Product product, AppLocalizations l10n) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => ProductEditDialog(product: product),
    );

    if (newName == null || !mounted) return;

    await _saveField(product.id, name: newName);
  }

  Widget _buildError(
    ProductsError state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final message = switch (state.errorType) {
      ProductsErrorType.network => l10n.fdNetworkError,
      ProductsErrorType.server => l10n.fdServerError,
      ProductsErrorType.unknown => l10n.fdUnknownError,
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
            onPressed: () => _cubit.watchProductsStream(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.fdRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    List<Product> products,
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
                Expanded(
                  flex: 3,
                  child: Text(l10n.productsColumnName, style: headerStyle),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 3,
                  child: Text(l10n.productsColumnFdProduct, style: headerStyle),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 60,
                  child: Text(
                    l10n.productsColumnActive,
                    style: headerStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 100,
                  child: Text(
                    l10n.productsColumnPrice,
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 80,
                  child: Text(
                    l10n.productsColumnActions,
                    style: headerStyle,
                    textAlign: TextAlign.center,
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
                  itemCount: products.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: border.color),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildRow(product, l10n, colorScheme, textTheme);
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
    Product product,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(height: 40, child: _buildNameField(product)),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            flex: 3,
            child: _buildFdProductButton(product, l10n, colorScheme, textTheme),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 60,
            child: Transform.scale(
              scale: 0.7,
              alignment: Alignment.center,
              child: Switch(
                value: product.isActive,
                activeThumbColor: colorScheme.surface,
                activeTrackColor:
                    Theme.of(context).extension<CustomColors>()?.success ??
                    Colors.green,
                inactiveThumbColor: colorScheme.surface,
                inactiveTrackColor: colorScheme.error,
                onChanged: (value) {
                  _saveField(product.id, isActive: value);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 100,
            child: Builder(
              builder: (_) {
                final fdProduct = _fdProductMap[product.facturaDirectaUuid];
                if (fdProduct == null || fdProduct.salesPrice == null) {
                  return const SizedBox.shrink();
                }
                final price = fdProduct.salesPrice!;
                return Text(
                  '${price.toStringAsFixed(2)} ${fdProduct.currency ?? ''}'
                      .trim(),
                  textAlign: TextAlign.right,
                  style: textTheme.bodySmall,
                );
              },
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 80,
            child: Center(
              child: SizedBox(
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
                  tooltip: l10n.productsDelete,
                  onPressed: () =>
                      _showDeleteConfirmation(context, l10n, product),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Track which fields are focused to avoid overwriting during editing
  final Set<String> _focusedFields = {};

  Widget _buildNameField(Product product) {
    final controller = _nameControllers.putIfAbsent(
      product.id,
      () => TextEditingController(text: product.name),
    );

    // Sync controller text when stream brings a new name (external edit),
    // but only if the field is not currently focused by the user.
    if (controller.text != product.name &&
        !_focusedFields.contains(product.id)) {
      controller.text = product.name;
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _focusedFields.add(product.id);
        } else {
          _focusedFields.remove(product.id);
          final trimmed = controller.text.trim();
          if (trimmed.isNotEmpty && trimmed != product.name) {
            _saveField(product.id, name: trimmed);
          }
        }
      },
      child: TextField(
        controller: controller,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFdProductButton(
    Product product,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final hasLink = product.facturaDirectaUuid.isNotEmpty;
    final fdProduct = hasLink
        ? _fdProductMap[product.facturaDirectaUuid]
        : null;
    final fdName = fdProduct?.name;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showFdProductSelector(product),
            icon: Icon(
              hasLink ? Icons.check_circle_rounded : Icons.link,
              size: 16,
              color: hasLink
                  ? (Theme.of(context).extension<CustomColors>()?.success ??
                        Colors.green)
                  : null,
            ),
            label: Text(
              hasLink ? (fdName ?? '') : l10n.productsSelectFdProduct,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              side: BorderSide(
                color: hasLink
                    ? (Theme.of(context).extension<CustomColors>()?.success ??
                              Colors.green)
                          .withValues(alpha: 0.4)
                    : colorScheme.outline.withValues(alpha: 0.4),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        if (hasLink) ...[
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton.filled(
              icon: const Icon(Icons.link_off, size: 16),
              tooltip: l10n.productsUnlinkFdProduct,
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
              ),
              onPressed: () => _unlinkFdProduct(product),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _unlinkFdProduct(Product product) async {
    final l10n = AppLocalizations.of(context)!;
    final success = await _cubit.unlinkFdProduct(productId: product.id);
    if (!mounted) return;
    _showFeedback(
      success ? l10n.productsSuccessUnlinked : l10n.productsErrorOperation,
      success: success,
    );
  }

  Future<void> _loadFdProducts() async {
    _cachedFdProducts = await _cubit.fetchFdProducts();
    if (_cachedFdProducts != null) {
      _fdProductMap = {for (final fd in _cachedFdProducts!) fd.uuid: fd};
    }
    _fdLoaded = true;
    if (mounted) setState(() {});
  }

  Future<void> _showFdProductSelector(Product product) async {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_cachedFdProducts == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.productsSelectFdError),
          behavior: SnackBarBehavior.floating,
          backgroundColor: colorScheme.error,
        ),
      );
      return;
    }

    final fdProducts = _cachedFdProducts!;

    if (fdProducts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.productsSelectFdEmpty),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selected = await showDialog<FdProduct>(
      context: context,
      builder: (_) => FdProductSelectorDialog(
        fdProducts: fdProducts,
        productName: product.name,
      ),
    );

    if (selected == null || !mounted) return;

    await _runWithProgress(
      action: () =>
          _cubit.linkFdProduct(productId: product.id, fdProduct: selected),
      successMessage: l10n.productsSuccessLinked,
      errorMessage: l10n.productsErrorSaving,
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AppLocalizations l10n,
    Product product,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.productsDeleteTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(l10n.productsDeleteMessage(product.name)),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteProduct(product, l10n);
            },
            child: Text(l10n.productsDelete),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(Product product, AppLocalizations l10n) async {
    await _runWithProgress(
      action: () => _cubit.deleteProduct(product.id),
      successMessage: l10n.productsSuccessDeleted,
      errorMessage: l10n.productsErrorSaving,
    );
    // Clean up controllers for deleted product
    _nameControllers.remove(product.id)?.dispose();
    _focusedFields.remove(product.id);
  }

  Future<void> _showReorderDialog(
    BuildContext context,
    List<Product> allProducts,
    AppLocalizations l10n,
  ) async {
    // Sort: products with order first (ascending), then without order
    final sorted = List<Product>.from(allProducts)
      ..sort((a, b) {
        final orderA = a.order;
        final orderB = b.order;
        if (orderA != null && orderB != null) {
          return orderA.compareTo(orderB);
        }
        if (orderA != null) return -1;
        if (orderB != null) return 1;
        return 0;
      });

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => ProductReorderDialog(products: sorted),
    );

    if (result == null || result.isEmpty || !context.mounted) return;

    await _runWithProgress(
      action: () => _cubit.saveBatchChanges(orderChanges: result),
      successMessage: l10n.productsReorderSaved,
      errorMessage: l10n.productsErrorSaving,
    );
  }

  void _showAddProductDialog(BuildContext context, AppLocalizations l10n) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.productsAddTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.productsColumnName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.productsNameRequired;
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() ?? false) {
                    final name = controller.text.trim();
                    Navigator.of(dialogContext).pop();
                    _addProduct(name, l10n);
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
                _addProduct(name, l10n);
              }
            },
            child: Text(l10n.settingsSave),
          ),
        ],
      ),
    );
  }

  Future<void> _addProduct(String name, AppLocalizations l10n) async {
    await _runWithProgress(
      action: () => _cubit.addProduct(name),
      successMessage: l10n.productsSuccessCreated,
      errorMessage: l10n.productsErrorSaving,
    );
  }
}
