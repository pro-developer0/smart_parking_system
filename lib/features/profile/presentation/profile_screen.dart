import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.occupied),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
    // Router redirect returns us to /login automatically.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () => context.push(Routes.editProfile),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    profile?.initials ?? '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 14),
                Text(profile?.name ?? '—',
                    style: context.text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(profile?.email ?? '',
                    style: TextStyle(color: context.semantic.muted)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.directions_car_outlined,
                label: 'Vehicle number',
                value: (profile?.vehicleNumber.isNotEmpty ?? false)
                    ? profile!.vehicleNumber
                    : 'Not set',
              ),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: (profile?.phone.isNotEmpty ?? false)
                    ? profile!.phone
                    : 'Not set',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MenuTile(
            icon: Icons.history_rounded,
            label: 'Booking history',
            onTap: () => context.go(Routes.history),
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => context.push(Routes.settings),
          ),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.logout_rounded,
            label: 'Log out',
            color: AppColors.occupied,
            onTap: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.semantic.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.semantic.border),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.semantic.muted),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: context.semantic.muted)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.text.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: context.semantic.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.semantic.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: c),
                const SizedBox(width: 14),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: c)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    color: context.semantic.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
