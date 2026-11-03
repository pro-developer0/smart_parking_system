import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Small color legend explaining slot statuses.
class LegendBar extends StatelessWidget {
  const LegendBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: const [
        _LegendDot(color: AppColors.available, label: 'Available'),
        _LegendDot(color: AppColors.occupied, label: 'Occupied'),
        _LegendDot(color: AppColors.mine, label: 'Your spot'),
        _LegendDot(color: AppColors.construction, label: 'Construction'),
        _LegendDot(color: AppColors.closed, label: 'Closed'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 12,
          width: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
