import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/formatters.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/parking/domain/booking.dart';
import '../../features/profile/data/profile_photo_repository.dart';
import '../05_profile/widgets/user_avatar.dart';
import '../../features/admin/application/admin_controller.dart';
import '../../features/admin/application/admin_providers.dart';

/// Tab 4: every registered user, with search. Tap a user to see their
/// details and bookings, suspend them from booking, or remove their photo.
class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  String _query = '';

  bool _matches(AppUser u) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return u.name.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        u.vehicleNumber.toLowerCase().contains(q) ||
        u.phone.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search name, email, vehicle or phone',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(mapAdminError(e), textAlign: TextAlign.center),
              ),
            ),
            data: (users) {
              final shown = users.where(_matches).toList();
              if (shown.isEmpty) {
                return Center(
                  child: Text(
                    'No users found.',
                    style: TextStyle(color: context.semantic.muted),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: shown.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Text(
                      '${shown.length} of ${users.length} users',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.semantic.muted,
                      ),
                    );
                  }
                  final user = shown[i - 1];
                  return _UserTile(
                    user: user,
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => _UserDetailsSheet(uid: user.uid),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});
  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.semantic.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.semantic.border),
          ),
          child: Row(
            children: [
              UserAvatar(uid: user.uid, initials: user.initials, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name.isEmpty ? 'No name' : user.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (user.isAdmin) ...[
                          const SizedBox(width: 6),
                          const _Badge(label: 'Admin', color: AppColors.primary),
                        ],
                        if (user.suspended) ...[
                          const SizedBox(width: 6),
                          const _Badge(
                              label: 'Suspended', color: AppColors.occupied),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.semantic.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _MiniInfo(
                          icon: Icons.directions_car_outlined,
                          value: user.vehicleNumber.isEmpty
                              ? 'No vehicle'
                              : user.vehicleNumber,
                        ),
                        _MiniInfo(
                          icon: Icons.phone_outlined,
                          value: user.phone.isEmpty ? 'No phone' : user.phone,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.semantic.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.semantic.muted),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Live details of one user. Watches the users list so the "Suspended"
/// switch updates as soon as Firestore confirms the change.
class _UserDetailsSheet extends ConsumerWidget {
  const _UserDetailsSheet({required this.uid});
  final String uid;

  Future<void> _setSuspended(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final ok = await ref
        .read(adminControllerProvider.notifier)
        .setUserSuspended(uid, value);
    if (!context.mounted) return;
    ok
        ? AppSnackbar.success(
            context, value ? 'User suspended from booking.' : 'User can book again.')
        : AppSnackbar.error(
            context, mapAdminError(ref.read(adminControllerProvider).error));
  }

  Future<void> _removePhoto(BuildContext context, WidgetRef ref) async {
    final ok =
        await ref.read(adminControllerProvider.notifier).removeUserPhoto(uid);
    if (!context.mounted) return;
    ok
        ? AppSnackbar.success(context, 'Profile photo removed.')
        : AppSnackbar.error(
            context, mapAdminError(ref.read(adminControllerProvider).error));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(allUsersProvider).value ?? const <AppUser>[];
    final user = users.where((u) => u.uid == uid).firstOrNull;
    if (user == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final busy = ref.watch(adminControllerProvider).isLoading;
    final hasPhoto = ref.watch(userPhotoProvider(uid)).value != null;
    final now = DateTime.now();
    final bookings = (ref.watch(recentBookingsProvider).value ?? const <Booking>[])
        .where((b) => b.userId == uid)
        .toList();
    final current = bookings
        .where((b) => b.status == BookingStatus.active && b.endTime.isAfter(now))
        .firstOrNull;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: UserAvatar(
                uid: user.uid,
                initials: user.initials,
                radius: 40,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.name.isEmpty ? 'No name' : user.name,
              textAlign: TextAlign.center,
              style:
                  context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.semantic.muted),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.directions_car_outlined,
              label: 'Vehicle',
              value: user.vehicleNumber.isEmpty ? 'Not set' : user.vehicleNumber,
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user.phone.isEmpty ? 'Not set' : user.phone,
            ),
            _InfoRow(
              icon: Icons.history_rounded,
              label: 'Recent bookings',
              value: '${bookings.length}',
            ),
            _InfoRow(
              icon: Icons.local_parking_rounded,
              label: 'Current booking',
              value: current == null
                  ? 'None'
                  : 'Slot ${current.slotId} until ${Formatters.smartTime(current.endTime)}',
            ),
            const SizedBox(height: 8),
            if (user.isAdmin)
              Text(
                'This account is an admin. Admin accounts are managed in the '
                'Firebase console.',
                style: TextStyle(fontSize: 12.5, color: context.semantic.muted),
              )
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: user.suspended,
                onChanged:
                    busy ? null : (v) => _setSuspended(context, ref, v),
                title: const Text('Suspend from booking'),
                subtitle: const Text(
                  'The user can still log in but cannot book a slot.',
                ),
              ),
              if (hasPhoto)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: !busy,
                  leading: const Icon(Icons.hide_image_outlined,
                      color: AppColors.occupied),
                  title: const Text('Remove profile photo'),
                  onTap: () => _removePhoto(context, ref),
                ),
            ],
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.semantic.muted),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: context.semantic.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
