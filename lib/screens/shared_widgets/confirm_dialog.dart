import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Yes/no dialog used before destructive actions. Returns true on confirm.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String cancel = 'Cancel',
  Color color = AppColors.occupied,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result == true;
}
