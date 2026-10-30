import 'package:flutter/material.dart';

import '../../shared/app_theme.dart';

class SelectionBadge extends StatelessWidget {
  const SelectionBadge({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: selected ? AppTheme.ink : Colors.white,
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? AppTheme.ink : AppTheme.muted,
        width: 1.5,
      ),
    ),
    child: selected
        ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
        : null,
  );
}
