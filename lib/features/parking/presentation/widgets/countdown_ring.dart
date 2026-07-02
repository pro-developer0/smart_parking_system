import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';

/// A circular progress ring with the remaining time in the center.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.progress,
    required this.remaining,
    this.size = 200,
  });

  /// 0..1 fraction elapsed.
  final double progress;
  final Duration remaining;
  final double size;

  @override
  Widget build(BuildContext context) {
    final almostDone = remaining.inMinutes < 10;
    final ringColor = almostDone ? AppColors.occupied : AppColors.primary;

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: size,
            width: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (1 - progress).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                backgroundColor: context.semantic.border,
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Time left',
                style: TextStyle(
                  color: context.semantic.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.remaining(remaining),
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ringColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
