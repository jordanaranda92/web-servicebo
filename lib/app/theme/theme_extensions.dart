import 'package:flutter/material.dart';

/// Custom theme extensions for app-specific styling.
///
/// Usage:
/// ```dart
/// final customColors = Theme.of(context).extension<CustomColors>();
/// ```
class CustomColors extends ThemeExtension<CustomColors> {
  final Color? success;
  final Color? warning;
  final Color? info;
  final Color? danger;
  final Color? refund;
  final Color? compensation;
  final Color? reservation;
  final Color? productLimited;
  final Color? productOutOfBonus;
  final Color? warningHeader;

  const CustomColors({
    this.success,
    this.warning,
    this.info,
    this.danger,
    this.refund,
    this.compensation,
    this.reservation,
    this.productLimited,
    this.productOutOfBonus,
    this.warningHeader,
  });

  @override
  CustomColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? danger,
    Color? refund,
    Color? compensation,
    Color? reservation,
    Color? productLimited,
    Color? productOutOfBonus,
    Color? warningHeader,
  }) {
    return CustomColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      danger: danger ?? this.danger,
      refund: refund ?? this.refund,
      compensation: compensation ?? this.compensation,
      reservation: reservation ?? this.reservation,
      productLimited: productLimited ?? this.productLimited,
      productOutOfBonus: productOutOfBonus ?? this.productOutOfBonus,
      warningHeader: warningHeader ?? this.warningHeader,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) return this;
    return CustomColors(
      success: Color.lerp(success, other.success, t),
      warning: Color.lerp(warning, other.warning, t),
      info: Color.lerp(info, other.info, t),
      danger: Color.lerp(danger, other.danger, t),
      refund: Color.lerp(refund, other.refund, t),
      compensation: Color.lerp(compensation, other.compensation, t),
      reservation: Color.lerp(reservation, other.reservation, t),
      productLimited: Color.lerp(productLimited, other.productLimited, t),
      productOutOfBonus: Color.lerp(
        productOutOfBonus,
        other.productOutOfBonus,
        t,
      ),
      warningHeader: Color.lerp(warningHeader, other.warningHeader, t),
    );
  }

  /// Light theme custom colors.
  static const light = CustomColors(
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFC107),
    info: Color(0xFF2196F3),
    danger: Color(0xFFFF1744),
    refund: Color(0xFFFF9800),
    compensation: Color(0xFFC8E6C9),
    reservation: Color(0xFFBBDEFB),
    productLimited: Color(0xFFF527DD),
    productOutOfBonus: Color(0xFF6F96F7),
    warningHeader: Color.fromARGB(190, 217, 121, 53),
  );
}
