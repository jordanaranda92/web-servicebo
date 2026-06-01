import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/prevent_context_menu_stub.dart'
    if (dart.library.js_interop) '../../../../core/utils/prevent_context_menu_web.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/utils/app_date_formats.dart';
import '../../../../core/utils/cell_key_utils.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../clients/domain/usecases/get_clients.dart';
import '../../domain/entities/order_sheet.dart';
import '../../domain/entities/remote_cursor.dart';
import '../bloc/orders_presence_cubit.dart';
import '../bloc/orders_presence_state.dart';
import 'order_sheet_pdf_dialog.dart';
import 'client_note_dialog.dart';
import 'orders_info_accordion.dart';
import 'orders_note_dialog.dart';
import 'orders_refund_dialog.dart';
import 'orders_table_footer.dart';
import 'remote_cursor_badge.dart';

/// Orders table with frozen first column, frozen header row, and frozen
/// summary columns. Supports cell editing for client quantity cells.
class OrdersTable extends StatefulWidget {
  const OrdersTable({
    super.key,
    required this.orderSheet,
    this.readOnly = false,
    this.searchFilter = '',
    this.selectedCategoryIds = const {},
    this.clientCategoryIdMap = const {},
    this.onCellUpdated,
    this.onCellFlagUpdated,
    this.onCellNoteUpdated,
    this.onCellRefundUpdated,
    this.onDeleteClients,
    this.onDeleteProducts,
    this.onResetOrders,
    this.onAddClient,
    this.onAddProduct,
    this.onGenerateProvisionalInvoice,
    this.onClientNoteUpdated,
    this.onChangeClient,
    this.footerTrailing,
    this.selectedDate,
    this.onDateSelectorTap,
  });

  final OrderSheet orderSheet;
  final bool readOnly;
  final String searchFilter;

  /// IDs of selected categories. Empty = no filter (show all).
  final Set<String> selectedCategoryIds;

  /// Map of clientId → clientCategoryId (null if client has no category).
  final Map<String, String?> clientCategoryIdMap;

  /// Called when a cell value is committed.
  /// Parameters: productIndex, clientIndex, newValue.
  final void Function(int productRow, int clientCol, num value)? onCellUpdated;

  /// Called when a cell flag is toggled via context menu.
  /// [clientCol] is `null` for strict-stock flag.
  /// [flagType] is `null` to remove a flag.
  final void Function(int productRow, int? clientCol, String? flagType)?
  onCellFlagUpdated;

  /// Called when a cell note is added/edited/removed via context menu.
  /// [note] is `null` to remove.
  final void Function(int productRow, int clientCol, String? note)?
  onCellNoteUpdated;

  /// Called when a cell refund is added/edited/removed via context menu.
  /// [quantity] is `null` to remove.
  final void Function(int productRow, int clientCol, num? quantity)?
  onCellRefundUpdated;

  /// Called when the user requests to delete the selected client columns.
  final void Function(List<int> clientIndices)? onDeleteClients;

  /// Called when the user requests to delete the selected product rows.
  final void Function(List<int> productIndices)? onDeleteProducts;

  /// Called when the user requests to reset orders for selected clients.
  final void Function(List<int> clientIndices)? onResetOrders;

  /// Called when the user requests to add a new client.
  final VoidCallback? onAddClient;

  /// Called when the user requests to add a new product.
  final VoidCallback? onAddProduct;

  /// Called when the user requests to generate a provisional invoice.
  final void Function(int clientCol)? onGenerateProvisionalInvoice;

  /// Called when a client-level note is added/edited/removed.
  /// [note] is `null` to remove.
  final void Function(int clientCol, String? note)? onClientNoteUpdated;

  /// Called when the user requests to change the client in a column.
  final void Function(int clientCol)? onChangeClient;

  /// Widget opcional que se muestra a la derecha del footer.
  final Widget? footerTrailing;

  /// Fecha activa a mostrar. Si es `null` se usa la fecha actual.
  final DateTime? selectedDate;

  /// Callback cuando el usuario pulsa el botón de selección de fecha.
  final VoidCallback? onDateSelectorTap;

  @override
  State<OrdersTable> createState() => _OrdersTableState();
}

class _OrdersTableState extends State<OrdersTable> {
  // ── Scroll controllers ──────────────────────────────────────────
  final _headerHorizontalController = ScrollController();
  final _dataHorizontalController = ScrollController();
  final _verticalController = ScrollController();
  final _frozenVerticalController = ScrollController();
  final _summaryVerticalController = ScrollController();

  bool _syncingHorizontal = false;
  bool _syncingVertical = false;

  // ── Constants ───────────────────────────────────────────────────
  static const double _dataColWidth = 48;
  static const double _minHeaderHeight = 180;
  static const double _maxHeaderHeight = 250;
  static const double _rowHeight = 32;
  static const double _defaultHeaderHeight = _minHeaderHeight;
  static const String _headerHeightKey = 'orders_table_header_height';

  static const double _defaultProductColWidth = 200;
  static const double _minProductColWidth = 220;
  static const double _maxProductColWidth = 260;
  static const String _productColWidthKey = 'orders_table_product_col_width';

  final ValueNotifier<double> _headerHeight = ValueNotifier<double>(
    _defaultHeaderHeight,
  );

  final ValueNotifier<double> _productColWidth = ValueNotifier<double>(
    _defaultProductColWidth,
  );

  // ── Editing state ───────────────────────────────────────────────
  int? _editingRow;
  int? _editingCol;
  final _editController = TextEditingController();
  final _editFocusNode = FocusNode();

  // ── Cached filtered indices ─────────────────────────────────────
  List<int> _filteredIndices = [];

  // ── Cached filtered client (column) indices ─────────────────────
  List<int> _filteredClientIndices = [];

  // ── Cached orderSheet references (avoid repeated property access) ──
  late List<List<num>> _quantities;
  late List<String> _clientIds;
  late List<String> _productIds;
  late List<num> _pedidos;
  late List<num> _stocks;
  late List<num> _quedan;
  late List<Map<String, String>> _cellFlags;
  late List<bool> _strictStocks;
  late List<Map<String, String>> _cellNotes;
  late List<Map<String, num>> _cellRefunds;
  late Map<String, InvoicedByInfo> _invoicedBy;
  late Map<String, String> _clientNotes;

  // ── Client category colors & names ────────────────────────────
  Map<String, String?> _clientCategoryColors = const {};
  Map<String, String?> _clientCategoryNames = const {};

  // ── Remote cursor state (rebuilt on presence changes) ──────
  StreamSubscription<OrdersPresenceState>? _presenceSub;

  /// Maps "productId:clientId" → RemoteCursor for O(1) lookup per cell.
  Map<String, RemoteCursor> _remoteCursorMap = const {};

  // ── Cached theme values (updated in didChangeDependencies) ──────
  late ColorScheme _colorScheme;
  late TextTheme _textTheme;
  late Color _headerColor;
  late Color _highlightColor;
  late BorderSide _borderSide;
  late BorderSide _strongBorder;
  CustomColors? _customColors;

  // ── Cached date strings (recomputed when selectedDate changes) ──
  late String _dayNameCapitalized;
  late String _datePart;
  bool _isSelectedDateToday = true;

  @override
  void initState() {
    super.initState();

    // Date formatting
    _updateDateStrings(widget.selectedDate ?? DateTime.now());

    // Key event handler for cell editing navigation
    _editFocusNode.onKeyEvent = _handleEditKeyEvent;

    // Restore persisted header height
    final prefs = sl<SharedPreferences>();
    final savedHeight = prefs.getDouble(_headerHeightKey);
    if (savedHeight != null) {
      _headerHeight.value = savedHeight.clamp(
        _minHeaderHeight,
        _maxHeaderHeight,
      );
    }

    // Restore persisted product column width
    final savedWidth = prefs.getDouble(_productColWidthKey);
    if (savedWidth != null) {
      _productColWidth.value = savedWidth.clamp(
        _minProductColWidth,
        _maxProductColWidth,
      );
    }

    // Scroll sync
    _verticalController.addListener(_syncFromData);
    _frozenVerticalController.addListener(_syncFromFrozen);
    _summaryVerticalController.addListener(_syncFromSummary);
    _headerHorizontalController.addListener(_syncDataHorizontal);
    _dataHorizontalController.addListener(_syncHeaderHorizontal);
    _updateFilteredIndices();
    _updateFilteredClientIndices();
    _cacheOrderSheetRefs();

    // Subscribe to cursor changes for remote cursor rendering
    _initPresenceSubscription();

    // Disable browser context menu (direct JS listener, immune to counter
    // de-sync caused by EditableText focus changes)
    preventBrowserContextMenu();

    _loadCategoryColors();
  }

  Future<void> _loadCategoryColors() async {
    final result = await sl<GetClients>()(NoParams());
    result.fold((_) {}, (clients) {
      final colorMap = <String, String?>{};
      final nameMap = <String, String?>{};
      for (final client in clients) {
        colorMap[client.id] = client.categoryColor;
        nameMap[client.id] = client.categoryName;
      }
      if (mounted) {
        setState(() {
          _clientCategoryColors = colorMap;
          _clientCategoryNames = nameMap;
        });
      }
    });
  }

  void _initPresenceSubscription() {
    final cubit = _tryGetPresenceCubit();
    if (cubit == null) return;
    _rebuildCursorMap(cubit.state);
    _presenceSub = cubit.stream.listen((state) {
      final newMap = _buildCursorMap(state);
      if (!_cursorMapsEqual(_remoteCursorMap, newMap)) {
        setState(() => _remoteCursorMap = newMap);
      }
    });
  }

  void _rebuildCursorMap(OrdersPresenceState state) {
    _remoteCursorMap = _buildCursorMap(state);
  }

  Map<String, RemoteCursor> _buildCursorMap(OrdersPresenceState state) {
    final map = <String, RemoteCursor>{};
    for (final cursor in state.cursors.values) {
      if (cursor.productId != null && cursor.clientId != null) {
        map['${cursor.productId}:${cursor.clientId}'] = cursor;
      } else if (cursor.productId != null) {
        // Stock cell cursor (no clientId)
        map['${cursor.productId}:__stock__'] = cursor;
      }
    }
    return map;
  }

  bool _cursorMapsEqual(
    Map<String, RemoteCursor> a,
    Map<String, RemoteCursor> b,
  ) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  void _cacheOrderSheetRefs() {
    final sheet = widget.orderSheet;
    _quantities = sheet.quantities;
    _clientIds = sheet.clientIds;
    _productIds = sheet.productIds;
    _pedidos = sheet.pedidos;
    _stocks = sheet.stocks;
    _quedan = sheet.quedan;
    _cellFlags = sheet.cellFlags;
    _strictStocks = sheet.strictStocks;
    _cellNotes = sheet.cellNotes;
    _cellRefunds = sheet.cellRefunds;
    _invoicedBy = sheet.invoicedBy;
    _clientNotes = sheet.clientNotes;
  }

  void _updateDateStrings(DateTime date) {
    final dayName = AppDateFormats.dayName().format(date);
    _dayNameCapitalized = dayName[0].toUpperCase() + dayName.substring(1);
    _datePart = AppDateFormats.dayMonth().format(date);
    final now = DateTime.now();
    _isSelectedDateToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    _colorScheme = theme.colorScheme;
    _textTheme = theme.textTheme;
    _customColors = theme.extension<CustomColors>();
    _headerColor = _colorScheme.surfaceContainerHighest;
    _highlightColor = _colorScheme.outlineVariant.withValues(alpha: 0.7);
    _borderSide = BorderSide(
      color: _colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
    _strongBorder = BorderSide(color: _colorScheme.outlineVariant, width: 2);
  }

  @override
  void didUpdateWidget(covariant OrdersTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderSheet != widget.orderSheet) {
      _cacheOrderSheetRefs();
    }
    // Update date strings when selectedDate changes
    final oldDate = oldWidget.selectedDate;
    final newDate = widget.selectedDate;
    if (oldDate != newDate) {
      _updateDateStrings(newDate ?? DateTime.now());
    }
    if (oldWidget.searchFilter != widget.searchFilter ||
        oldWidget.orderSheet.products != widget.orderSheet.products) {
      _updateFilteredIndices();
    }
    if (oldWidget.selectedCategoryIds != widget.selectedCategoryIds ||
        oldWidget.clientCategoryIdMap != widget.clientCategoryIdMap ||
        oldWidget.orderSheet.clientIds != widget.orderSheet.clientIds) {
      _updateFilteredClientIndices();
      // Clear editing when client columns change due to filter
      if (oldWidget.selectedCategoryIds != widget.selectedCategoryIds) {
        _editingRow = null;
        _editingCol = null;
        _releaseLockIfNeeded();
      }
    }
    // Clear selections and editing when structure changes (e.g. remote update)
    if (oldWidget.orderSheet.clients.length !=
            widget.orderSheet.clients.length ||
        oldWidget.orderSheet.products.length !=
            widget.orderSheet.products.length) {
      _editingRow = null;
      _editingCol = null;
      _releaseLockIfNeeded();
    } else if (_lockedCellKey != null) {
      // Check if the locked cell references an ID that was removed or reordered
      final parsed = parseCellKey(_lockedCellKey!);
      final productIds = widget.orderSheet.productIds;
      final clientIds = widget.orderSheet.clientIds;
      final isOrphan =
          !productIds.contains(parsed.productId) ||
          (parsed.clientId != null && !clientIds.contains(parsed.clientId));
      if (isOrphan) {
        _editingRow = null;
        _editingCol = null;
        _releaseLockIfNeeded();
      }
    }
  }

  // ── Scroll synchronization ──────────────────────────────────────

  void _syncFromData() {
    if (_syncingVertical) return;
    _syncingVertical = true;
    final offset = _verticalController.offset;
    _jumpVerticalIfNeeded(_frozenVerticalController, offset);
    _jumpVerticalIfNeeded(_summaryVerticalController, offset);
    _syncingVertical = false;
  }

  void _syncFromFrozen() {
    if (_syncingVertical) return;
    _syncingVertical = true;
    final offset = _frozenVerticalController.offset;
    _jumpVerticalIfNeeded(_verticalController, offset);
    _jumpVerticalIfNeeded(_summaryVerticalController, offset);
    _syncingVertical = false;
  }

  void _syncFromSummary() {
    if (_syncingVertical) return;
    _syncingVertical = true;
    final offset = _summaryVerticalController.offset;
    _jumpVerticalIfNeeded(_verticalController, offset);
    _jumpVerticalIfNeeded(_frozenVerticalController, offset);
    _syncingVertical = false;
  }

  /// Syncs [target] to [offset], clamping to valid scroll extents to prevent
  /// overscroll propagation and bounce-back feedback loops.
  void _jumpVerticalIfNeeded(ScrollController target, double offset) {
    if (!target.hasClients) return;
    final position = target.position;
    final clamped = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - clamped).abs() > 0.5) {
      target.jumpTo(clamped);
    }
  }

  void _syncDataHorizontal() {
    if (_syncingHorizontal) return;
    _syncingHorizontal = true;
    if (_dataHorizontalController.hasClients) {
      _dataHorizontalController.jumpTo(_headerHorizontalController.offset);
    }
    _syncingHorizontal = false;
  }

  void _syncHeaderHorizontal() {
    if (_syncingHorizontal) return;
    _syncingHorizontal = true;
    if (_headerHorizontalController.hasClients) {
      _headerHorizontalController.jumpTo(_dataHorizontalController.offset);
    }
    _syncingHorizontal = false;
  }

  @override
  void dispose() {
    _verticalController.removeListener(_syncFromData);
    _frozenVerticalController.removeListener(_syncFromFrozen);
    _summaryVerticalController.removeListener(_syncFromSummary);
    _headerHorizontalController.removeListener(_syncDataHorizontal);
    _dataHorizontalController.removeListener(_syncHeaderHorizontal);
    _headerHorizontalController.dispose();
    _dataHorizontalController.dispose();
    _verticalController.dispose();
    _frozenVerticalController.dispose();
    _summaryVerticalController.dispose();
    _headerHeight.dispose();
    _productColWidth.dispose();
    _presenceSub?.cancel();
    restoreBrowserContextMenu();
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  // ── Editing logic ───────────────────────────────────────────────

  num _parseEditValue() {
    final text = _editController.text.trim();
    return text.isEmpty ? 0 : (num.tryParse(text) ?? 0);
  }

  /// The RTDB cell key currently locked by this user (if any).
  String? _lockedCellKey;

  OrdersPresenceCubit? _tryGetPresenceCubit() {
    try {
      return context.read<OrdersPresenceCubit>();
    } catch (_) {
      return null;
    }
  }

  String _cellKeyForEditing(int productIdx, int visualCol) {
    final sheet = widget.orderSheet;
    final filteredClientCount = _filteredClientIndices.length;
    final isStock = visualCol == filteredClientCount + 1;
    final productId = sheet.productIds[productIdx];
    if (isStock) return stockKey(productId);
    final realCol = _filteredClientIndices[visualCol];
    final clientId = sheet.clientIds[realCol];
    return cellKey(productId, clientId);
  }

  void _startEditing(int rowIdx, int col, num currentValue) {
    final productIdx = _filteredIndices[rowIdx];
    final key = _cellKeyForEditing(productIdx, col);

    // Release previous lock if any
    _releaseLockIfNeeded();

    // Try to acquire lock — only enter edit mode if acquired
    final cubit = _tryGetPresenceCubit();
    if (cubit != null) {
      cubit.acquireLock(key).then((acquired) {
        if (!mounted) return;
        if (!acquired) {
          _showCellLockedSnackBar(key, cubit);
          return;
        }
        _lockedCellKey = key;
        final parsed = parseCellKey(key);
        cubit.updateMyPosition(parsed.productId, parsed.clientId);
        _enterEditMode(rowIdx, col, currentValue);
      });
    } else {
      // No presence system — allow editing directly
      _enterEditMode(rowIdx, col, currentValue);
    }
  }

  void _enterEditMode(int rowIdx, int col, num currentValue) {
    _editFocusNode.unfocus();
    setState(() {
      _editingRow = rowIdx;
      _editingCol = col;
      _editController.text = currentValue == 0 ? '' : _formatNum(currentValue);
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_editFocusNode.canRequestFocus) {
        _editFocusNode.requestFocus();
      }
    });
  }

  /// Shows a snackbar indicating which user holds the lock on [cellKey].
  void _showCellLockedSnackBar(String cellKey, OrdersPresenceCubit cubit) {
    final lock = cubit.state.locks[cellKey];
    String lockedByName = '';
    if (lock != null) {
      final remoteCursor = cubit.state.cursors[lock.user];
      lockedByName = remoteCursor?.userName ?? lock.user;
    }
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.ordersCellLocked(lockedByName))),
    );
  }

  void _releaseLockIfNeeded() {
    if (_lockedCellKey != null) {
      _tryGetPresenceCubit()?.releaseLock(_lockedCellKey!);
      _lockedCellKey = null;
    }
  }

  void _commitEditing() {
    if (_editingRow == null || _editingCol == null) return;
    final value = _parseEditValue();
    final productIdx = _filteredIndices[_editingRow!];
    final filteredClientCount = _filteredClientIndices.length;
    final realCol = _editingCol! < filteredClientCount
        ? _filteredClientIndices[_editingCol!]
        : _editingCol! - filteredClientCount + widget.orderSheet.clients.length;
    widget.onCellUpdated?.call(productIdx, realCol, value);
    _releaseLockIfNeeded();
    _tryGetPresenceCubit()?.updateMyPosition(null, null);
    setState(() {
      _editingRow = null;
      _editingCol = null;
    });
  }

  void _commitAndMove(int dRow, int dCol) {
    if (_editingRow == null || _editingCol == null) return;

    // Commit current cell
    final value = _parseEditValue();
    final productIdx = _filteredIndices[_editingRow!];
    final filteredClientCount = _filteredClientIndices.length;
    final realEditCol = _editingCol! < filteredClientCount
        ? _filteredClientIndices[_editingCol!]
        : _editingCol! - filteredClientCount + widget.orderSheet.clients.length;
    widget.onCellUpdated?.call(productIdx, realEditCol, value);

    // Calculate new position (in visual indices)
    final newRow = _editingRow! + dRow;
    final newCol = _editingCol! + dCol;
    final stocksCol = filteredClientCount + 1;

    final isNewColEditable =
        (newCol >= 0 && newCol < filteredClientCount) || newCol == stocksCol;

    if (newRow < 0 ||
        newRow >= _filteredIndices.length ||
        !isNewColEditable ||
        newCol > stocksCol) {
      _releaseLockIfNeeded();
      _tryGetPresenceCubit()?.updateMyPosition(null, null);
      setState(() {
        _editingRow = null;
        _editingCol = null;
      });
      return;
    }

    // Skip PEDIDOS column when navigating horizontally
    int effectiveCol = newCol;
    if (newCol == filteredClientCount) {
      effectiveCol = dCol > 0 ? stocksCol : filteredClientCount - 1;
      if (effectiveCol < 0) {
        _releaseLockIfNeeded();
        _tryGetPresenceCubit()?.updateMyPosition(null, null);
        setState(() {
          _editingRow = null;
          _editingCol = null;
        });
        return;
      }
    }

    // Move to the new cell — inline state update to avoid double setState
    final newProductIdx = _filteredIndices[newRow];
    num currentValue;
    if (effectiveCol == stocksCol) {
      final stocks = widget.orderSheet.stocks;
      currentValue = newProductIdx < stocks.length ? stocks[newProductIdx] : 0;
    } else {
      final realNewCol = _filteredClientIndices[effectiveCol];
      final quantities = widget.orderSheet.quantities;
      final rowQ = newProductIdx < quantities.length
          ? quantities[newProductIdx]
          : <num>[];
      currentValue = realNewCol < rowQ.length ? rowQ[realNewCol] : 0;
    }

    // Handle lock transition: release old, acquire new
    final newKey = _cellKeyForEditing(newProductIdx, effectiveCol);
    _releaseLockIfNeeded();
    final cubit = _tryGetPresenceCubit();
    if (cubit != null) {
      cubit.acquireLock(newKey).then((acquired) {
        if (!mounted) return;
        if (!acquired) {
          _showCellLockedSnackBar(newKey, cubit);
          // Exit edit mode — couldn't acquire the next cell
          _tryGetPresenceCubit()?.updateMyPosition(null, null);
          setState(() {
            _editingRow = null;
            _editingCol = null;
          });
          return;
        }
        _lockedCellKey = newKey;
        final parsed = parseCellKey(newKey);
        cubit.updateMyPosition(parsed.productId, parsed.clientId);
        _enterEditMode(newRow, effectiveCol, currentValue);
      });
    } else {
      _enterEditMode(newRow, effectiveCol, currentValue);
    }
  }

  void _updateFilteredIndices() {
    final products = widget.orderSheet.products;
    final indices = <int>[];
    for (var i = 0; i < products.length; i++) {
      if (widget.searchFilter.isEmpty ||
          products[i].toLowerCase().contains(
            widget.searchFilter.toLowerCase(),
          )) {
        indices.add(i);
      }
    }
    _filteredIndices = indices;
  }

  void _updateFilteredClientIndices() {
    final clientIds = widget.orderSheet.clientIds;
    final selected = widget.selectedCategoryIds;
    if (selected.isEmpty) {
      _filteredClientIndices = List.generate(clientIds.length, (i) => i);
      return;
    }
    final indices = <int>[];
    for (var i = 0; i < clientIds.length; i++) {
      final catId = widget.clientCategoryIdMap[clientIds[i]];
      if (catId != null && selected.contains(catId)) {
        indices.add(i);
      } else if (catId == null && selected.contains('__no_category__')) {
        indices.add(i);
      }
    }
    _filteredClientIndices = indices;
  }

  // ── Cell builder methods ────────────────────────────────────────

  Widget _buildProductColResizeHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          _productColWidth.value = (_productColWidth.value + details.delta.dx)
              .clamp(_minProductColWidth, _maxProductColWidth);
        },
        onHorizontalDragEnd: (_) {
          sl<SharedPreferences>().setDouble(
            _productColWidthKey,
            _productColWidth.value,
          );
        },
        child: Container(
          width: 8,
          color: _colorScheme.outlineVariant.withValues(alpha: 0.3),
          child: Center(
            child: Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: _colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: _productColWidth.value,
      decoration: BoxDecoration(
        color: _headerColor,
        border: Border(bottom: _borderSide, right: _strongBorder),
      ),
      child: Column(
        children: [
          // Top: date + add client column
          Expanded(
            child: Row(
              children: [
                // Date text
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSelectedDateToday)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                )!.ordersDateSelectorToday,
                                style: _textTheme.labelSmall?.copyWith(
                                  color: _colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        Text(
                          '$_dayNameCapitalized,',
                          style: _textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _datePart,
                          style: _textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (widget.onDateSelectorTap != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Material(
                              color: _colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: widget.onDateSelectorTap,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_month_rounded,
                                        size: 13,
                                        color: _colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.ordersDateSelectorChange,
                                        style: _textTheme.labelSmall?.copyWith(
                                          color: _colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Add client column
                if (widget.onAddClient != null)
                  Material(
                    color: _colorScheme.primary,
                    child: InkWell(
                      onTap: widget.onAddClient,
                      child: Container(
                        width: _dataColWidth,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _colorScheme.onPrimary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: -1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 16,
                                  color: _colorScheme.onPrimary,
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                Text(
                                  l10n.ordersAddClient,
                                  style: _textTheme.labelSmall?.copyWith(
                                    color: _colorScheme.onPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Bottom row: add product + empty corner
          if (widget.onAddProduct != null)
            SizedBox(
              height: _dataColWidth,
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: _colorScheme.primary,
                      child: InkWell(
                        onTap: widget.onAddProduct,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: _colorScheme.onPrimary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 16,
                                  color: _colorScheme.onPrimary,
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                Text(
                                  l10n.ordersAddProduct,
                                  style: _textTheme.labelSmall?.copyWith(
                                    color: _colorScheme.onPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.onAddClient != null)
                    SizedBox(
                      width: _dataColWidth,
                      child: Material(
                        color: _colorScheme.primary,
                        child: InkWell(
                          onTap: _showInfoDialog,
                          child: Center(
                            child: Icon(
                              Icons.info_outline,
                              size: 20,
                              color: _colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollableHeader(int col, {AppLocalizations? l10nOverride}) {
    final l10n = l10nOverride ?? AppLocalizations.of(context)!;
    final clients = widget.orderSheet.clients;
    final filteredClientCount = _filteredClientIndices.length;

    final isClient = col < filteredClientCount;
    final isPedidos = col == filteredClientCount;
    final isStocks = col == filteredClientCount + 1;
    final isEditingStocks = _editingCol == filteredClientCount + 1;
    final isColHighlighted =
        _editingCol != null && _editingCol == col && !isEditingStocks;

    Color headerCellColor;
    if (isColHighlighted) {
      headerCellColor = _highlightColor;
    } else {
      headerCellColor = _headerColor;
    }

    if (isClient) {
      final realCol = _filteredClientIndices[col];
      final orderNum = realCol + 1;
      // Check if this client has been invoiced
      final clientId = realCol < _clientIds.length ? _clientIds[realCol] : null;
      final invoiceInfo = clientId != null ? _invoicedBy[clientId] : null;
      Color? invoicedColor;
      if (invoiceInfo != null && invoiceInfo.color.isNotEmpty) {
        final hex = invoiceInfo.color.replaceFirst('#', '');
        invoicedColor = Color(int.parse('FF$hex', radix: 16));
      }

      return GestureDetector(
        onSecondaryTapDown: widget.readOnly
            ? null
            : (details) =>
                  _showClientContextMenu(details.globalPosition, realCol),
        onLongPressStart: widget.readOnly
            ? null
            : (details) =>
                  _showClientContextMenu(details.globalPosition, realCol),
        child: SizedBox(
          width: _dataColWidth,
          child: Material(
            color: headerCellColor,
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: _borderSide, right: _borderSide),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: invoicedColor != null
                        ? BoxDecoration(color: invoicedColor)
                        : null,
                    child: Text(
                      '$orderNum',
                      textAlign: TextAlign.center,
                      style: _textTheme.labelMedium?.copyWith(
                        color: invoicedColor != null
                            ? _colorScheme.surface
                            : _colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Category color stripe
                  Builder(
                    builder: (_) {
                      final catHex = clientId != null
                          ? _clientCategoryColors[clientId]
                          : null;
                      final catName = clientId != null
                          ? _clientCategoryNames[clientId]
                          : null;
                      Color? catColor;
                      if (catHex != null && catHex.isNotEmpty) {
                        final hex = catHex.replaceFirst('#', '');
                        catColor = Color(int.parse('FF$hex', radix: 16));
                      }
                      final stripe = Container(
                        width: double.infinity,
                        height: 12,
                        color: catColor,
                      );
                      if (catName != null && catName.isNotEmpty) {
                        return Tooltip(message: catName, child: stripe);
                      }
                      return stripe;
                    },
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: _colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  // Client note indicator
                  if (clientId != null &&
                      _clientNotes[clientId] != null &&
                      _clientNotes[clientId]!.isNotEmpty)
                    Tooltip(
                      message: _clientNotes[clientId]!,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: Text(
                            clients[realCol],
                            style: _textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // PEDIDOS / STOCKS / QUEDAN
    final label = isPedidos
        ? l10n.ordersColumnPedidos
        : isStocks
        ? l10n.ordersColumnStocks
        : l10n.ordersColumnQuedan;
    Color summaryHeaderColor;
    Color summaryTextColor;
    if (isColHighlighted) {
      summaryHeaderColor = _highlightColor;
      summaryTextColor = _colorScheme.onTertiary;
    } else if (isPedidos) {
      summaryHeaderColor = _colorScheme.tertiary.withValues(alpha: 1);
      summaryTextColor = _colorScheme.onTertiary;
    } else if (isStocks) {
      summaryHeaderColor = const Color(0xFFD32F2F);
      summaryTextColor = _colorScheme.onPrimary;
    } else {
      // QUEDAN column
      summaryHeaderColor = const Color(0xFF00ACC1);
      summaryTextColor = _colorScheme.onPrimary;
    }

    return Container(
      width: _dataColWidth,
      decoration: BoxDecoration(
        color: summaryHeaderColor,
        border: Border(
          bottom: _borderSide,
          right: _borderSide,
          left: isPedidos ? _strongBorder : BorderSide.none,
        ),
      ),
      child: RotatedBox(
        quarterTurns: -1,
        child: Center(
          child: Text(
            label,
            style: _textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: summaryTextColor,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCell(int rowIdx) {
    final productIdx = _filteredIndices[rowIdx];
    final isRowHighlighted = _editingRow == rowIdx;

    return GestureDetector(
      onSecondaryTapDown: !widget.readOnly && widget.onDeleteProducts != null
          ? (details) =>
                _showProductContextMenu(details.globalPosition, productIdx)
          : null,
      onLongPressStart: !widget.readOnly && widget.onDeleteProducts != null
          ? (details) =>
                _showProductContextMenu(details.globalPosition, productIdx)
          : null,
      child: Container(
        width: _productColWidth.value,
        height: _rowHeight,
        padding: const EdgeInsets.only(left: AppSpacing.md),
        decoration: BoxDecoration(
          color: isRowHighlighted
              ? _highlightColor
              : (rowIdx.isEven ? null : _colorScheme.surfaceContainerLow),
          border: Border(bottom: _borderSide, right: _strongBorder),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.orderSheet.products[productIdx],
            style: _textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(int rowIdx, int col, {AppLocalizations? l10nOverride}) {
    final l10n = l10nOverride ?? AppLocalizations.of(context)!;
    final productIdx = _filteredIndices[rowIdx];
    final quantities = _quantities;
    final pedidos = _pedidos;
    final stocks = _stocks;
    final quedan = _quedan;
    final filteredClientCount = _filteredClientIndices.length;

    final productQuantities = productIdx < quantities.length
        ? quantities[productIdx]
        : <num>[];

    final isClient = col < filteredClientCount;
    final isPedidos = col == filteredClientCount;
    final isStocks = col == filteredClientCount + 1;
    final isQuedan = !isClient && !isPedidos && !isStocks;

    // Map visual col to real col for data access
    final realCol = isClient ? _filteredClientIndices[col] : col;

    // Resolve per-cell metadata
    final clientId = isClient && realCol < _clientIds.length
        ? _clientIds[realCol]
        : null;
    final cellFlag = _resolveCellFlag(isClient, productIdx, clientId);
    final isStrictStock = _resolveStrictStock(isStocks, productIdx);
    final cellNote = _resolveCellNote(isClient, productIdx, clientId);
    final cellRefund = _resolveCellRefund(isClient, productIdx, clientId);

    // Resolve value & style
    final (:num value, :TextStyle? style) = _resolveDataCellValueAndStyle(
      isClient: isClient,
      isPedidos: isPedidos,
      isStocks: isStocks,
      productIdx: productIdx,
      col: realCol,
      productQuantities: productQuantities,
      pedidos: pedidos,
      stocks: stocks,
      quedan: quedan,
      isStrictStock: isStrictStock,
    );

    // ── ReadOnly: consolidar abono en el valor mostrado ──
    final displayValue = widget.readOnly && isClient
        ? value + (cellRefund ?? 0)
        : value;
    final effectiveStyle = widget.readOnly && isClient && displayValue != value
        ? style?.copyWith(fontSize: 12, fontWeight: FontWeight.bold)
        : style;

    final isEditing = _editingRow == rowIdx && _editingCol == col;
    final isEditable = !widget.readOnly && (isClient || isStocks);
    final isSelected = isEditing && isEditable;
    final isRowHighlighted =
        _editingRow == rowIdx && _editingCol != null && col < _editingCol!;
    final isColHighlighted =
        _editingCol != null &&
        _editingCol == col &&
        _editingCol != filteredClientCount + 1 &&
        _editingRow != null &&
        rowIdx < _editingRow!;

    // Remote cursor lookup
    final remoteCursor = _resolveRemoteCursor(
      isClient,
      isStocks,
      productIdx,
      realCol,
    );

    // Build inner content
    final child = _buildCellContent(
      isSelected: isSelected,
      isClient: isClient,
      isStocks: isStocks,
      productIdx: productIdx,
      col: realCol,
      value: displayValue,
      style: effectiveStyle,
      cellFlag: cellFlag,
      isStrictStock: isStrictStock,
      cellNote: cellNote,
      cellRefund: cellRefund,
    );

    // Tooltip
    final tooltipMessage = _dataCellTooltip(
      l10n,
      cellFlag,
      isStrictStock,
      widget.readOnly ? null : cellNote,
      widget.readOnly ? null : cellRefund,
    );

    // Wrap in GestureDetector + Container
    return _wrapDataCell(
      child: child,
      rowIdx: rowIdx,
      col: col,
      realCol: realCol,
      value: displayValue,
      isQuedan: isQuedan,
      isPedidos: isPedidos,
      isSelected: isSelected,
      isEditable: isEditable,
      isRowHighlighted: isRowHighlighted,
      isColHighlighted: isColHighlighted,
      cellFlag: cellFlag,
      isStrictStock: isStrictStock,
      cellNote: cellNote,
      cellRefund: cellRefund,
      isClient: isClient,
      isStocks: isStocks,
      productIdx: productIdx,
      remoteCursor: remoteCursor,
      tooltipMessage: tooltipMessage,
    );
  }

  // ── Data cell helpers ───────────────────────────────────────────

  String? _resolveCellFlag(bool isClient, int productIdx, String? clientId) {
    if (!isClient || productIdx >= _cellFlags.length || clientId == null) {
      return null;
    }
    return _cellFlags[productIdx][clientId];
  }

  bool _resolveStrictStock(bool isStocks, int productIdx) {
    return isStocks &&
        productIdx < _strictStocks.length &&
        _strictStocks[productIdx];
  }

  String? _resolveCellNote(bool isClient, int productIdx, String? clientId) {
    if (!isClient || productIdx >= _cellNotes.length || clientId == null) {
      return null;
    }
    return _cellNotes[productIdx][clientId];
  }

  num? _resolveCellRefund(bool isClient, int productIdx, String? clientId) {
    if (!isClient || productIdx >= _cellRefunds.length || clientId == null) {
      return null;
    }
    return _cellRefunds[productIdx][clientId];
  }

  ({num value, TextStyle? style}) _resolveDataCellValueAndStyle({
    required bool isClient,
    required bool isPedidos,
    required bool isStocks,
    required int productIdx,
    required int col,
    required List<num> productQuantities,
    required List<num> pedidos,
    required List<num> stocks,
    required List<num> quedan,
    required bool isStrictStock,
  }) {
    if (isClient) {
      final value = col < productQuantities.length ? productQuantities[col] : 0;
      return (
        value: value,
        style: _textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    } else if (isPedidos) {
      return (
        value: productIdx < pedidos.length ? pedidos[productIdx] : 0,
        style: _textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    } else if (isStocks) {
      return (
        value: productIdx < stocks.length ? stocks[productIdx] : 0,
        style: _textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isStrictStock
              ? (_customColors?.danger ?? _colorScheme.error)
              : null,
        ),
      );
    } else {
      return (
        value: productIdx < quedan.length ? quedan[productIdx] : 0,
        style: _textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: _colorScheme.onError,
        ),
      );
    }
  }

  RemoteCursor? _resolveRemoteCursor(
    bool isClient,
    bool isStocks,
    int productIdx,
    int col,
  ) {
    if (isClient &&
        productIdx < _productIds.length &&
        col < _clientIds.length) {
      return _remoteCursorMap['${_productIds[productIdx]}:${_clientIds[col]}'];
    } else if (isStocks && productIdx < _productIds.length) {
      return _remoteCursorMap['${_productIds[productIdx]}:__stock__'];
    }
    return null;
  }

  Widget _buildCellContent({
    required bool isSelected,
    required bool isClient,
    required bool isStocks,
    required int productIdx,
    required int col,
    required num value,
    required TextStyle? style,
    required String? cellFlag,
    required bool isStrictStock,
    required String? cellNote,
    required num? cellRefund,
  }) {
    if (isSelected) {
      return GestureDetector(
        onLongPressStart: (details) {
          _showCellContextMenu(
            details.globalPosition,
            productIdx,
            col,
            isClient: isClient,
            isStocks: isStocks,
            cellFlag: cellFlag,
            isStrictStock: isStrictStock,
            cellNote: cellNote,
            cellRefund: cellRefund,
          );
        },
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons == kSecondaryButton) {
              _showCellContextMenu(
                event.position,
                productIdx,
                col,
                isClient: isClient,
                isStocks: isStocks,
                cellFlag: cellFlag,
                isStrictStock: isStrictStock,
                cellNote: cellNote,
                cellRefund: cellRefund,
              );
            }
          },
          child: _buildEditingCell(),
        ),
      );
    }

    final hasNote = !widget.readOnly && cellNote != null && cellNote.isNotEmpty;
    final hasRefund = !widget.readOnly && cellRefund != null && cellRefund > 0;
    final cellContent = isClient && value == 0
        ? const SizedBox.shrink()
        : Text(_formatNum(value), style: style);

    if (!hasNote && !hasRefund) return cellContent;

    return Stack(
      children: [
        Center(child: cellContent),
        if (hasNote)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        if (hasRefund)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _customColors?.refund ?? _colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  String? _dataCellTooltip(
    AppLocalizations l10n,
    String? cellFlag,
    bool isStrictStock,
    String? cellNote,
    num? cellRefund,
  ) {
    final parts = <String>[];
    if (cellFlag == 'compensation') {
      parts.add(l10n.ordersTooltipCompensation);
    } else if (cellFlag == 'reservation') {
      parts.add(l10n.ordersTooltipReservation);
    } else if (isStrictStock) {
      parts.add(l10n.ordersTooltipStrictStock);
    }
    if (cellNote != null && cellNote.isNotEmpty) {
      parts.add('${l10n.ordersNoteDialogTitle}: $cellNote');
    }
    if (cellRefund != null && cellRefund > 0) {
      parts.add('${l10n.ordersTooltipRefund}: ${_formatNum(cellRefund)}');
    }
    return parts.isNotEmpty ? parts.join('\n') : null;
  }

  Widget _wrapDataCell({
    required Widget child,
    required int rowIdx,
    required int col,
    required int realCol,
    required num value,
    required bool isQuedan,
    required bool isPedidos,
    required bool isSelected,
    required bool isEditable,
    required bool isRowHighlighted,
    required bool isColHighlighted,
    required String? cellFlag,
    required bool isStrictStock,
    required String? cellNote,
    required num? cellRefund,
    required bool isClient,
    required bool isStocks,
    required int productIdx,
    required RemoteCursor? remoteCursor,
    required String? tooltipMessage,
  }) {
    final hasRemoteCursor = remoteCursor != null;
    final successColor = _customColors?.success;

    final cellWidget = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isEditable ? () => _startEditing(rowIdx, col, value) : null,
      onSecondaryTapUp: isEditable
          ? (details) => _showCellContextMenu(
              details.globalPosition,
              productIdx,
              realCol,
              isClient: isClient,
              isStocks: isStocks,
              cellFlag: cellFlag,
              isStrictStock: isStrictStock,
              cellNote: cellNote,
              cellRefund: cellRefund,
            )
          : null,
      onLongPressStart: isEditable
          ? (details) => _showCellContextMenu(
              details.globalPosition,
              productIdx,
              realCol,
              isClient: isClient,
              isStocks: isStocks,
              cellFlag: cellFlag,
              isStrictStock: isStrictStock,
              cellNote: cellNote,
              cellRefund: cellRefund,
            )
          : null,
      child: Container(
        width: _dataColWidth,
        height: _rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hasRemoteCursor
              ? remoteCursor.color.withValues(alpha: 0.10)
              : _dataCellColor(
                  isQuedan: isQuedan,
                  isPedidos: isPedidos,
                  isSelected: isSelected,
                  isRowHighlighted: isRowHighlighted,
                  isColHighlighted: isColHighlighted,
                  quedanValue: isQuedan ? value : 0,
                  rowIdx: rowIdx,
                  successColor: successColor,
                  cellFlag: cellFlag,
                ),
          border: isSelected
              ? Border.all(color: _colorScheme.primary, width: 2)
              : hasRemoteCursor
              ? Border.all(color: remoteCursor.color, width: 2)
              : Border(
                  bottom: _borderSide,
                  right: _borderSide,
                  left: isPedidos ? _strongBorder : BorderSide.none,
                ),
        ),
        child: hasRemoteCursor && !isSelected
            ? Stack(
                children: [
                  Center(child: child),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: RemoteCursorBadge(cursor: remoteCursor),
                  ),
                ],
              )
            : child,
      ),
    );

    if (tooltipMessage != null) {
      return Tooltip(message: tooltipMessage, child: cellWidget);
    }
    return cellWidget;
  }

  // ── Cell flag colors ────────────────────────────────────────────

  Color get _compensationColor =>
      _customColors?.compensation ?? const Color(0xFFC8E6C9);
  Color get _reservationColor =>
      _customColors?.reservation ?? const Color(0xFFBBDEFB);

  Color? _dataCellColor({
    required bool isQuedan,
    required bool isPedidos,
    required bool isSelected,
    required bool isRowHighlighted,
    required bool isColHighlighted,
    required num quedanValue,
    required int rowIdx,
    Color? successColor,
    String? cellFlag,
  }) {
    if (isQuedan) {
      return quedanValue < 0
          ? _colorScheme.error
          : (successColor ?? _colorScheme.tertiary);
    }
    if (isPedidos) {
      final warningColor = _customColors?.warning ?? const Color(0xFFFFC107);
      return warningColor.withValues(alpha: 0.4);
    }
    if (isSelected) {
      // Keep flag color even while editing
      if (cellFlag == 'compensation') return _compensationColor;
      if (cellFlag == 'reservation') return _reservationColor;
      return null;
    }
    // Cell flag colors take priority over highlight and alternation
    if (cellFlag == 'compensation') return _compensationColor;
    if (cellFlag == 'reservation') return _reservationColor;
    if (isRowHighlighted || isColHighlighted) return _highlightColor;
    return rowIdx.isEven ? null : _colorScheme.surfaceContainerLow;
  }

  void _showCellContextMenu(
    Offset globalPosition,
    int productIdx,
    int col, {
    required bool isClient,
    required bool isStocks,
    String? cellFlag,
    bool isStrictStock = false,
    String? cellNote,
    num? cellRefund,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final items = <PopupMenuEntry<String>>[];

    if (isClient) {
      // Note option (always first)
      final hasNote = cellNote != null && cellNote.isNotEmpty;
      items.add(
        PopupMenuItem<String>(
          value: 'note',
          child: Row(
            children: [
              Icon(
                hasNote ? Icons.edit_note : Icons.note_add_outlined,
                size: 20,
                color: _colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(hasNote ? l10n.ordersEditNote : l10n.ordersAddNote),
            ],
          ),
        ),
      );
      if (hasNote) {
        items.add(
          PopupMenuItem<String>(
            value: 'remove_note',
            child: Row(
              children: [
                Icon(
                  Icons.remove_circle_outline,
                  size: 20,
                  color: _colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(l10n.ordersRemoveNote),
              ],
            ),
          ),
        );
      }
      items.add(const PopupMenuDivider());
      // Refund option
      final hasRefund = cellRefund != null && cellRefund > 0;
      items.add(
        PopupMenuItem<String>(
          value: 'refund',
          child: Row(
            children: [
              Icon(
                hasRefund ? Icons.edit : Icons.currency_exchange,
                size: 20,
                color: _colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(hasRefund ? l10n.ordersEditRefund : l10n.ordersAddRefund),
            ],
          ),
        ),
      );
      if (hasRefund) {
        items.add(
          PopupMenuItem<String>(
            value: 'remove_refund',
            child: Row(
              children: [
                Icon(
                  Icons.remove_circle_outline,
                  size: 20,
                  color: _colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(l10n.ordersRemoveRefund),
              ],
            ),
          ),
        );
      }
      items.add(const PopupMenuDivider());
      // Compensation toggle
      final isCompensation = cellFlag == 'compensation';
      items.add(
        PopupMenuItem<String>(
          value: isCompensation ? 'remove_compensation' : 'compensation',
          child: Row(
            children: [
              Icon(
                isCompensation
                    ? Icons.remove_circle_outline
                    : Icons.bookmark_outline,
                size: 20,
                color: isCompensation
                    ? _colorScheme.error
                    : _colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isCompensation
                    ? l10n.ordersUnmarkCompensation
                    : l10n.ordersMarkCompensation,
              ),
            ],
          ),
        ),
      );
      // Reservation toggle
      final isReservation = cellFlag == 'reservation';
      items.add(
        PopupMenuItem<String>(
          value: isReservation ? 'remove_reservation' : 'reservation',
          child: Row(
            children: [
              Icon(
                isReservation
                    ? Icons.remove_circle_outline
                    : Icons.bookmark_outline,
                size: 20,
                color: isReservation
                    ? _colorScheme.error
                    : _colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isReservation
                    ? l10n.ordersUnmarkReservation
                    : l10n.ordersMarkReservation,
              ),
            ],
          ),
        ),
      );
    } else if (isStocks) {
      items.add(
        PopupMenuItem<String>(
          value: isStrictStock ? 'remove_strict' : 'strict',
          child: Row(
            children: [
              Icon(
                isStrictStock ? Icons.lock_open : Icons.lock_outline,
                size: 20,
                color: isStrictStock
                    ? _colorScheme.error
                    : _colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isStrictStock
                    ? l10n.ordersUnmarkStrictStock
                    : l10n.ordersMarkStrictStock,
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) return;

    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & Size.zero,
        overlay.localToGlobal(Offset.zero) & overlay.size,
      ),
      items: items,
    ).then((selected) {
      if (selected == null) return;
      // Commit any in-progress editing and release focus
      _commitEditing();
      switch (selected) {
        case 'note':
          _showNoteDialog(productIdx, col, cellNote);
        case 'remove_note':
          widget.onCellNoteUpdated?.call(productIdx, col, null);
        case 'refund':
          _showRefundDialog(productIdx, col, cellRefund);
        case 'remove_refund':
          widget.onCellRefundUpdated?.call(productIdx, col, null);
        case 'compensation':
          widget.onCellFlagUpdated?.call(productIdx, col, 'compensation');
        case 'remove_compensation':
          widget.onCellFlagUpdated?.call(productIdx, col, null);
        case 'reservation':
          widget.onCellFlagUpdated?.call(productIdx, col, 'reservation');
        case 'remove_reservation':
          widget.onCellFlagUpdated?.call(productIdx, col, null);
        case 'strict':
          widget.onCellFlagUpdated?.call(productIdx, null, 'strictStock');
        case 'remove_strict':
          widget.onCellFlagUpdated?.call(productIdx, null, null);
      }
    });
  }

  void _showNoteDialog(int productIdx, int col, String? existingNote) {
    showOrderNoteDialog(context, existingNote: existingNote).then((note) {
      if (note == null && existingNote != null) return; // cancelled
      widget.onCellNoteUpdated?.call(productIdx, col, note);
    });
  }

  void _showRefundDialog(int productIdx, int col, num? existingRefund) {
    showOrderRefundDialog(context, existingRefund: existingRefund).then((
      quantity,
    ) {
      if (quantity == null && existingRefund != null) return; // cancelled
      widget.onCellRefundUpdated?.call(productIdx, col, quantity);
    });
  }

  Widget _buildEditingCell() {
    return TextField(
      controller: _editController,
      focusNode: _editFocusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      textAlign: TextAlign.center,
      showCursor: false,
      style: _textTheme.bodySmall?.copyWith(fontSize: 11),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      onSubmitted: (_) => _commitEditing(),
      onTapOutside: (_) => _commitEditing(),
    );
  }

  KeyEventResult _handleEditKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _commitAndMove(-1, 0);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _commitAndMove(1, 0);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_editController.selection.baseOffset == 0) {
        _commitAndMove(0, -1);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_editController.selection.baseOffset == _editController.text.length) {
        _commitAndMove(0, 1);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _editingRow = null;
        _editingCol = null;
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.tab) {
      _commitAndMove(0, 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Dialogs ─────────────────────────────────────────────────────

  Future<void> _showDeleteConfirmation(
    List<int> sortedIndices,
    int selectedCount, {
    required bool isProducts,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final title = isProducts
        ? l10n.ordersDeleteProductsConfirmTitle
        : l10n.ordersDeleteConfirmTitle;
    final message = isProducts
        ? l10n.ordersDeleteProductsConfirmMessage(selectedCount)
        : l10n.ordersDeleteConfirmMessage(selectedCount);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: _colorScheme.error),
        title: Text(title),
        content: Text(message),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _colorScheme.error,
              foregroundColor: _colorScheme.onError,
            ),
            child: Text(l10n.ordersDeleteConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (isProducts) {
        widget.onDeleteProducts!(sortedIndices);
      } else {
        widget.onDeleteClients!(sortedIndices);
      }
    }
  }

  Future<void> _showResetConfirmation(
    List<int> clientIndices,
    int selectedCount,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: _colorScheme.error),
        title: Text(l10n.ordersResetConfirmTitle),
        content: Text(l10n.ordersResetConfirmMessage(selectedCount)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _colorScheme.error,
              foregroundColor: _colorScheme.onError,
            ),
            child: Text(l10n.ordersResetConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.onResetOrders!(clientIndices);
    }
  }

  void _showInfoDialog() {
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final entries = <({IconData icon, String title, String subtitle})>[
      (
        icon: Icons.person_add_outlined,
        title: l10n.ordersInfoAddClientTitle,
        subtitle: l10n.ordersInfoAddClientDesc,
      ),
      (
        icon: Icons.add_box_outlined,
        title: l10n.ordersInfoAddProductTitle,
        subtitle: l10n.ordersInfoAddProductDesc,
      ),
      (
        icon: Icons.inventory_2_outlined,
        title: l10n.ordersInfoEditStockTitle,
        subtitle: l10n.ordersInfoEditStockDesc,
      ),
      (
        icon: Icons.lock_outline,
        title: l10n.ordersInfoStrictStockTitle,
        subtitle: l10n.ordersInfoStrictStockDesc,
      ),
      (
        icon: Icons.grid_on,
        title: l10n.ordersInfoAssignQtyTitle,
        subtitle: l10n.ordersInfoAssignQtyDesc,
      ),
      (
        icon: Icons.note_add_outlined,
        title: l10n.ordersInfoCellNoteTitle,
        subtitle: l10n.ordersInfoCellNoteDesc,
      ),
      (
        icon: Icons.bookmark_outline,
        title: l10n.ordersInfoCompensationTitle,
        subtitle: l10n.ordersInfoCompensationDesc,
      ),
      (
        icon: Icons.bookmark_added_outlined,
        title: l10n.ordersInfoReservationTitle,
        subtitle: l10n.ordersInfoReservationDesc,
      ),
      (
        icon: Icons.person_remove_outlined,
        title: l10n.ordersInfoRemoveClientTitle,
        subtitle: l10n.ordersInfoRemoveClientDesc,
      ),
      (
        icon: Icons.delete_outline,
        title: l10n.ordersInfoRemoveProductTitle,
        subtitle: l10n.ordersInfoRemoveProductDesc,
      ),
      (
        icon: Icons.restart_alt,
        title: l10n.ordersInfoResetOrderTitle,
        subtitle: l10n.ordersInfoResetOrderDesc,
      ),
      (
        icon: Icons.receipt_long_outlined,
        title: l10n.ordersInfoOrderSheetTitle,
        subtitle: l10n.ordersInfoOrderSheetDesc,
      ),
      (
        icon: Icons.description_outlined,
        title: l10n.ordersInfoProvisionalInvoiceTitle,
        subtitle: l10n.ordersInfoProvisionalInvoiceDesc,
      ),
    ];

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.ordersInfoDialogTitle,
          style: _textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: screenHeight * 0.7,
          ),
          child: SizedBox(width: 480, child: InfoAccordion(entries: entries)),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ordersInfoDialogClose),
          ),
        ],
      ),
    );
  }

  void _showClientContextMenu(Offset globalPosition, int col) {
    final l10n = AppLocalizations.of(context)!;
    final clientId = col < _clientIds.length ? _clientIds[col] : null;
    final existingNote = clientId != null ? _clientNotes[clientId] : null;
    final hasNote = existingNote != null && existingNote.isNotEmpty;

    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'generate_order_sheet',
        child: Row(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 20,
              color: _colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(l10n.ordersContextMenuGenerateOrderSheet),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'generate_provisional_invoice',
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 20,
              color: _colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(l10n.ordersContextMenuGenerateProvisionalInvoice),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'add_edit_client_note',
        child: Row(
          children: [
            Icon(
              hasNote ? Icons.edit_note : Icons.note_add_outlined,
              size: 20,
              color: _colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              hasNote
                  ? l10n.ordersContextMenuEditClientNote
                  : l10n.ordersContextMenuAddClientNote,
            ),
          ],
        ),
      ),
      if (hasNote)
        PopupMenuItem<String>(
          value: 'delete_client_note',
          child: Row(
            children: [
              Icon(
                Icons.note_alt_outlined,
                size: 20,
                color: _colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(l10n.ordersContextMenuDeleteClientNote),
            ],
          ),
        ),
      const PopupMenuDivider(),
      if (widget.onChangeClient != null) ...[
        PopupMenuItem<String>(
          value: 'change_client',
          child: Row(
            children: [
              Icon(Icons.swap_horiz, size: 20, color: _colorScheme.onSurface),
              const SizedBox(width: 8),
              Text(l10n.ordersContextMenuChangeClient),
            ],
          ),
        ),
        const PopupMenuDivider(),
      ],
      if (widget.onResetOrders != null)
        PopupMenuItem<String>(
          value: 'reset_order',
          child: Row(
            children: [
              Icon(Icons.restart_alt, size: 20, color: _colorScheme.error),
              const SizedBox(width: 8),
              Text(l10n.ordersContextMenuResetOrder),
            ],
          ),
        ),
      if (widget.onDeleteClients != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete_client',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: _colorScheme.error),
              const SizedBox(width: 8),
              Text(l10n.ordersContextMenuDeleteClient),
            ],
          ),
        ),
      ],
    ];

    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & Size.zero,
        overlay.localToGlobal(Offset.zero) & overlay.size,
      ),
      items: items,
    ).then((selected) {
      if (selected == null) return;
      switch (selected) {
        case 'generate_order_sheet':
          _generateOrderSheetPdf(col);
        case 'generate_provisional_invoice':
          widget.onGenerateProvisionalInvoice?.call(col);
        case 'add_edit_client_note':
          _showClientNoteDialog(col, existingNote);
        case 'delete_client_note':
          widget.onClientNoteUpdated?.call(col, null);
        case 'change_client':
          widget.onChangeClient?.call(col);
        case 'reset_order':
          _showResetConfirmation([col], 1);
        case 'delete_client':
          _showDeleteConfirmation([col], 1, isProducts: false);
      }
    });
  }

  Future<void> _generateOrderSheetPdf(int col) async {
    await showOrderSheetPdfDialog(
      context,
      orderSheet: widget.orderSheet,
      col: col,
      formatNum: _formatNum,
    );
  }

  Future<void> _showClientNoteDialog(int col, String? existingNote) async {
    final result = await showClientNoteDialog(
      context,
      existingNote: existingNote,
    );
    if (result == null) return; // cancelled — keep existing note unchanged
    // Empty string means the user wants to clear the note
    final note = result.isEmpty ? null : result;
    widget.onClientNoteUpdated?.call(col, note);
  }

  void _showProductContextMenu(Offset globalPosition, int productIdx) {
    final l10n = AppLocalizations.of(context)!;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & Size.zero,
        overlay.localToGlobal(Offset.zero) & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'delete_product',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: _colorScheme.error),
              const SizedBox(width: 8),
              Text(l10n.ordersContextMenuDeleteProduct),
            ],
          ),
        ),
      ],
    ).then((selected) {
      if (selected == null) return;
      if (selected == 'delete_product') {
        _showDeleteConfirmation([productIdx], 1, isProducts: true);
      }
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────

  String _formatNum(num value) {
    if (value == value.toInt()) return value.toInt().toString();
    return value.toString();
  }

  // ── Build ───────────────────────────────────────────────────────

  Widget _buildHeaderResizeHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          _headerHeight.value = (_headerHeight.value + details.delta.dy).clamp(
            _minHeaderHeight,
            _maxHeaderHeight,
          );
        },
        onVerticalDragEnd: (_) {
          sl<SharedPreferences>().setDouble(
            _headerHeightKey,
            _headerHeight.value,
          );
        },
        child: Container(
          height: 8,
          color: _colorScheme.outlineVariant.withValues(alpha: 0.3),
          child: Center(
            child: Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: _colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrozenProductColumn(List<int> filteredIndices) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(_colorScheme.primary),
        thickness: const WidgetStatePropertyAll(15),
        radius: const Radius.circular(AppRadii.small),
        minThumbLength: 48,
      ),
      child: SizedBox(
        width: _productColWidth.value,
        child: Scrollbar(
          controller: _frozenVerticalController,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _frozenVerticalController,
            itemCount: filteredIndices.length,
            itemExtent: _rowHeight,
            itemBuilder: (_, i) => _buildProductCell(i),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyClientsPlaceholder(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.ordersNoClients,
            style: _textTheme.bodyLarge?.copyWith(
              color: _colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.ordersNoClientsHint,
            style: _textTheme.bodyMedium?.copyWith(
              color: _colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableDataArea(
    int scrollColCount,
    List<int> filteredIndices,
    AppLocalizations l10n,
  ) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(_colorScheme.primary),
        thickness: const WidgetStatePropertyAll(15),
        radius: const Radius.circular(AppRadii.small),
        minThumbLength: 48,
      ),
      child: Scrollbar(
        controller: _dataHorizontalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _dataHorizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: scrollColCount * _dataColWidth,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ListView.builder(
                controller: _verticalController,
                itemCount: filteredIndices.length,
                itemExtent: _rowHeight,
                itemBuilder: (_, rowIdx) {
                  return Row(
                    children: List.generate(
                      scrollColCount,
                      (col) => _buildDataCell(rowIdx, col, l10nOverride: l10n),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrozenSummaryColumns(
    int summaryColCount,
    int clientCount,
    List<int> filteredIndices,
    AppLocalizations l10n,
  ) {
    return SizedBox(
      width: summaryColCount * _dataColWidth,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          controller: _summaryVerticalController,
          itemCount: filteredIndices.length,
          itemExtent: _rowHeight,
          itemBuilder: (_, rowIdx) {
            return Row(
              children: List.generate(
                summaryColCount,
                (i) =>
                    _buildDataCell(rowIdx, clientCount + i, l10nOverride: l10n),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filteredIndices = _filteredIndices;
    final filteredClientIndices = _filteredClientIndices;
    final scrollColCount = filteredClientIndices.length;
    const summaryColCount = 3; // PEDIDOS, STOCKS, QUEDAN

    // ── Layout: 6 quadrants ────────────────────────────────────────
    // ┌───────────┬──────────────────────┬─────────────────┐
    // │ Product   │ Scrollable headers   │ Summary headers │ ← frozen
    // │ header    │ (horizontal scroll)  │ (PED/STK/QUE)   │
    // ├───────────┼──────────────────────┼─────────────────┤
    // │ Product   │ Data cells           │ Summary cells   │ ← v-scroll
    // │ names     │ (h+v scroll)         │ (v-scroll only) │
    // └───────────┴──────────────────────┴─────────────────┘

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: widget.readOnly
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: widget.readOnly
                    ? BorderRadius.zero
                    : BorderRadius.circular(AppRadii.small),
                border: Border.all(color: _colorScheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: widget.readOnly
                    ? BorderRadius.zero
                    : BorderRadius.circular(AppRadii.small),
                child: ValueListenableBuilder<double>(
                  valueListenable: _productColWidth,
                  builder: (context, productW, _) {
                    return Column(
                      children: [
                        // ── Top row: frozen header + resize handle ──
                        ValueListenableBuilder<double>(
                          valueListenable: _headerHeight,
                          builder: (context, headerH, _) {
                            return SizedBox(
                              height: headerH,
                              child: Row(
                                children: [
                                  _buildProductHeader(),
                                  _buildProductColResizeHandle(),
                                  Expanded(
                                    child: filteredClientIndices.isEmpty
                                        ? Container(color: _headerColor)
                                        : SingleChildScrollView(
                                            controller:
                                                _headerHorizontalController,
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: List.generate(
                                                scrollColCount,
                                                (visCol) =>
                                                    _buildScrollableHeader(
                                                      visCol,
                                                      l10nOverride: l10n,
                                                    ),
                                              ),
                                            ),
                                          ),
                                  ),
                                  ...List.generate(
                                    summaryColCount,
                                    (i) => _buildScrollableHeader(
                                      scrollColCount + i,
                                      l10nOverride: l10n,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        _buildHeaderResizeHandle(),
                        // ── Bottom row: scrollable data ──
                        Expanded(
                          child: Row(
                            children: [
                              _buildFrozenProductColumn(filteredIndices),
                              _buildProductColResizeHandle(),
                              Expanded(
                                child: filteredClientIndices.isEmpty
                                    ? _buildEmptyClientsPlaceholder(l10n)
                                    : _buildScrollableDataArea(
                                        scrollColCount,
                                        filteredIndices,
                                        l10n,
                                      ),
                              ),
                              _buildFrozenSummaryColumns(
                                summaryColCount,
                                scrollColCount,
                                filteredIndices,
                                l10n,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        OrdersTableFooter(
          trailing: widget.footerTrailing,
          compact: widget.readOnly,
        ),
      ],
    );
  }
}
