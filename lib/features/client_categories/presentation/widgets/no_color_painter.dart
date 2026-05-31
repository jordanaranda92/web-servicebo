import 'package:flutter/material.dart';

class NoColorPainter extends CustomPainter {
  final Color color;

  NoColorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, paint);

    // Diagonal line from top-right to bottom-left
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final dx = radius * 0.707; // cos(45°)
    canvas.drawLine(
      Offset(center.dx + dx, center.dy - dx),
      Offset(center.dx - dx, center.dy + dx),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant NoColorPainter oldDelegate) =>
      color != oldDelegate.color;
}
