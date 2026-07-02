import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Consistent snackbars for success / error / info feedback.
abstract class AppSnackbar {
  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.available, Icons.check_circle_rounded);

  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.occupied, Icons.error_rounded);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.primary, Icons.info_rounded);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
