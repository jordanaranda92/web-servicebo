import 'package:flutter/material.dart';

/// Predefined color palette for client categories.
const List<String> kCategoryColors = [
  '#E53935', // rojo
  '#FB8C00', // naranja
  '#43A047', // verde
  '#00ACC1', // cian
  '#1E88E5', // azul
  '#5E35B1', // morado
  '#D81B60', // rosa
  '#6D4C41', // marrón
  '#546E7A', // gris azulado
];

/// Tries to parse a hex color string (e.g. '#FF5733') into a [Color].
/// Returns null if the format is invalid.
Color? tryParseHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return null;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

/// Returns [Colors.white] or [Colors.black] depending on the luminance
/// of [background], ensuring readable text contrast.
Color contrastTextColor(Color background) {
  return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
