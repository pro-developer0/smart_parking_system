import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/parking_slot.dart';

/// A single tappable slot in the parking grid, colored by status.
class SlotTile extends StatelessWidget {
  const SlotTile({super.key, required this.view, required this.onTap});

  final SlotView view;
  final VoidCallback onTap;

  Color get _color => switch (view.status) {
        SlotStatus.available => AppColors.available,
        SlotStatus.occupied => AppColors.occupied,
        SlotStatus.mine => AppColors.mine,
      };

  @override
  Widget build(BuildContext context) {
    final isAvailable = view.status == SlotStatus.available;
    final isMine = view.status == SlotStatus.mine;
    final bg = _color.withValues(alpha: isAvailable ? 0.10 : 0.14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _color.withValues(alpha: isMine ? 1 : 0.35),
              width: isMine ? 2 : 1.2,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAvailable
                          ? Icons.local_parking_rounded
                          : Icons.directions_car_rounded,
                      color: _color,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      view.slot.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _color,
                      ),
                    ),
                  ],
                ),
              ),
              if (isMine)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.mine,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'YOU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
