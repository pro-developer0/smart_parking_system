import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/settings_providers.dart';
import '../../features/parking/application/parking_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Wraps the Home / History / Profile tabs in a floating, pill-styled
/// bottom navigation bar. Each tab keeps its own navigation stack and
/// scroll position when switching away and back (via [StatefulShellRoute]).
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (
      icon: Icons.local_parking_outlined,
      selectedIcon: Icons.local_parking_rounded,
      label: 'Home',
    ),
    (
      icon: Icons.history_rounded,
      selectedIcon: Icons.history_rounded,
      label: 'History',
    ),
    (
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the "booking ends soon" notification in sync while signed in.
    ref.watch(bookingNotificationProvider);
    // Prompts for notification permission on first reaching the app's
    // signed-in area, if it hasn't been granted yet.
    ref.watch(notificationPermissionPromptProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: context.semantic.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: context.semantic.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _destinations[i].icon,
                    selectedIcon: _destinations[i].selectedIcon,
                    label: _destinations[i].label,
                    selected: navigationShell.currentIndex == i,
                    onTap: () => navigationShell.goBranch(
                      i,
                      initialLocation: i == navigationShell.currentIndex,
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.semantic.muted;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 16 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(18),
          ),
          // FittedBox guarantees this never overflows its slot even on the
          // narrowest devices or with larger system font scales — it
          // shrinks the icon+label together instead of clipping/erroring.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 22),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : const SizedBox(width: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
