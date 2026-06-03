/// Model for a subdocument at `orders/{YYYY-MM-DD}/rows/{productId}`.
class OrderRowModel {
  static const String limitedMark = 'limited';
  static const String outOfBonusMark = 'outOfBonus';

  final String productId;
  final Map<String, num> quantities;
  final num stock;

  /// Sparse map of `clientId → flagType` where flagType is
  /// `"compensation"` or `"reservation"`. Only cells with an active flag
  /// are present.
  final Map<String, String> flags;

  /// Whether this product's stock is marked as strict (cannot be exceeded).
  final bool strictStock;

  /// Sparse map of `clientId → noteText` for cell notes.
  /// Only cells with a note are present.
  final Map<String, String> notes;

  /// Sparse map of `clientId → quantity` for refunds/credits.
  /// Only cells with a refund are present.
  final Map<String, num> refunds;

  /// Product-level mark used to style the product cell in UI.
  /// Allowed values: `limited`, `outOfBonus`, or `null`.
  final String? productMark;

  const OrderRowModel({
    required this.productId,
    required this.quantities,
    required this.stock,
    this.flags = const {},
    this.strictStock = false,
    this.notes = const {},
    this.refunds = const {},
    this.productMark,
  });

  factory OrderRowModel.fromFirestore(String id, Map<String, dynamic> data) {
    final rawQuantities = data['quantities'] as Map<String, dynamic>? ?? {};
    final quantities = rawQuantities.map<String, num>(
      (key, value) => MapEntry(key, (value as num?) ?? 0),
    );

    final rawFlags = data['flags'] as Map<String, dynamic>? ?? {};
    final flags = rawFlags.map<String, String>(
      (key, value) => MapEntry(key, (value as String?) ?? ''),
    );

    final rawNotes = data['notes'] as Map<String, dynamic>? ?? {};
    final notes = rawNotes.map<String, String>(
      (key, value) => MapEntry(key, (value as String?) ?? ''),
    );

    final rawRefunds = data['refunds'] as Map<String, dynamic>? ?? {};
    final refunds = rawRefunds.map<String, num>(
      (key, value) => MapEntry(key, (value as num?) ?? 0),
    );

    final rawProductMark = data['productMark'] as String?;

    return OrderRowModel(
      productId: id,
      quantities: quantities,
      stock: (data['stock'] as num?) ?? 0,
      flags: flags,
      strictStock: (data['strictStock'] as bool?) ?? false,
      notes: notes,
      refunds: refunds,
      productMark: _sanitizeProductMark(rawProductMark),
    );
  }

  static String? _sanitizeProductMark(String? value) {
    if (value == limitedMark || value == outOfBonusMark) return value;
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'quantities': quantities,
      'stock': stock,
      'flags': flags,
      'strictStock': strictStock,
      'notes': notes,
      'refunds': refunds,
      if (productMark != null) 'productMark': productMark,
    };
  }
}
