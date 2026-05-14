// Utility for converting between RTDB cell keys and entity IDs.

/// Creates a cell key for a quantity cell: `"{productId}_{clientId}"`.
String cellKey(String productId, String clientId) => '${productId}_$clientId';

/// Creates a cell key for a stock cell: `"stock_{productId}"`.
String stockKey(String productId) => 'stock_$productId';

/// Returns `true` if [key] represents a stock cell.
bool isStockKey(String key) => key.startsWith('stock_');

/// Parses a cell key into product and client IDs.
/// For stock keys (`"stock_prodABC"`), returns `(productId: "prodABC", clientId: null)`.
/// For quantity keys (`"prodABC_cliXYZ"`), returns `(productId: "prodABC", clientId: "cliXYZ")`.
({String productId, String? clientId}) parseCellKey(String key) {
  if (isStockKey(key)) {
    final productId = key.substring(6);
    return (productId: productId, clientId: null);
  }
  final idx = key.indexOf('_');
  return (productId: key.substring(0, idx), clientId: key.substring(idx + 1));
}
