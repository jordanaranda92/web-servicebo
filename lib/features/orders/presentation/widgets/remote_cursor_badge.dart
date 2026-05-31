import 'package:flutter/material.dart';

import '../../domain/entities/remote_cursor.dart';

/// Small circle badge showing the initial letter of a remote user's name,
/// rendered in the user's assigned color.
class RemoteCursorBadge extends StatelessWidget {
  const RemoteCursorBadge({super.key, required this.cursor});

  final RemoteCursor cursor;

  @override
  Widget build(BuildContext context) {
    final initial = cursor.userName.isNotEmpty
        ? cursor.userName[0].toUpperCase()
        : '?';
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: cursor.color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Theme.of(context).colorScheme.surface,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
