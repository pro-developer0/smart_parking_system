import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/parking_config.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cctv_widgets.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/stat_card.dart';
import '../../parking/application/parking_providers.dart';
import '../../parking/domain/booking.dart';
import '../../parking/domain/slot_condition.dart';
import '../application/admin_controller.dart';
import '../application/admin_providers.dart';
import 'widgets/admin_card.dart';

/// Tab 1: live numbers, section occupancy, the notice for users, and
/// quick actions (reopen everything / emergency close).
class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  /// Shows [success] if [ok], otherwise the controller's last error.
  void _report(BuildContext context, WidgetRef ref, bool ok, String success) {
    ok
        ? AppSnackbar.success(context, success)
        : AppSnackbar.error(
            context, mapAdminError(ref.read(adminControllerProvider).error));
  }

  Future<void> _editAnnouncement(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _AnnouncementDialog(initial: current),
    );
    if (message == null || !context.mounted) return;
    final controller = ref.read(adminControllerProvider.notifier);
    final ok = message.trim().isEmpty
        ? await controller.clearAnnouncement()
        : await controller.postAnnouncement(message);
    if (context.mounted) _report(context, ref, ok, 'Notice updated for all users.');
  }

  Future<void> _clearAnnouncement(BuildContext context, WidgetRef ref) async {
    final ok =
        await ref.read(adminControllerProvider.notifier).clearAnnouncement();
    if (context.mounted) _report(context, ref, ok, 'Notice removed.');
  }

  Future<void> _reopenAll(BuildContext context, WidgetRef ref) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Reopen all slots?',
      message: 'Every closed slot (construction, maintenance, reserved, '
          'closed) becomes open for booking again.',
      action: 'Reopen all',
      color: AppColors.available,
    );
    if (!confirm || !context.mounted) return;
    final ok = await ref.read(adminControllerProvider.notifier).reopenAllSlots();
    if (context.mounted) _report(context, ref, ok, 'All slots are open again.');
  }

  Future<void> _closeAll(BuildContext context, WidgetRef ref) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Close the whole parking?',
      message: 'All ${ParkingConfig.slots.length} slots will be closed and '
          'users cannot book. Existing bookings stay valid.',
      action: 'Close all',
      color: AppColors.occupied,
    );
    if (!confirm || !context.mounted) return;
    final ok = await ref.read(adminControllerProvider.notifier).updateSlots(
          slotIds: [for (final s in ParkingConfig.slots) s.id],
          condition: SlotCondition.closed,
          note: 'The parking is temporarily closed.',
        );
    if (context.mounted) _report(context, ref, ok, 'All slots closed.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now();
    final counts = ref.watch(slotCountsProvider);
    final views = ref.watch(slotViewsProvider);
    final active = ref.watch(adminActiveBookingsProvider);
    final recent = ref.watch(recentBookingsProvider).value ?? const <Booking>[];
    final announcement = ref.watch(announcementProvider).value;
    final busy = ref.watch(adminControllerProvider).isLoading;

    final parkedNow = active.where((b) => b.isLive(now)).length;
    final upcoming = active.where((b) => b.isUpcoming(now)).length;
    final today = recent
        .where((b) => DateUtils.isSameDay(b.createdAt, now))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        // ── Camera surveillance status ────────────────────────────────
        const CctvStatusCard(forAdmin: true),
        const SizedBox(height: 16),

        // ── Live slot numbers ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Available',
                value: counts.available,
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.available,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Occupied',
                value: counts.occupied,
                icon: Icons.directions_car_rounded,
                color: AppColors.occupied,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Closed by admin',
                value: counts.blocked,
                icon: Icons.construction_rounded,
                color: AppColors.construction,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Total slots',
                value: counts.total,
                icon: Icons.local_parking_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Bookings ──────────────────────────────────────────────────
        AdminCard(
          title: 'Bookings',
          icon: Icons.event_note_rounded,
          child: Row(
            children: [
              _MiniNumber(label: 'Parked now', value: parkedNow),
              _MiniNumber(label: 'Upcoming', value: upcoming),
              _MiniNumber(label: 'Made today', value: today),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Occupancy per section ─────────────────────────────────────
        AdminCard(
          title: 'Sections',
          icon: Icons.grid_view_rounded,
          child: Column(
            children: [
              for (final section in ParkingConfig.sections)
                _SectionBar(
                  section: section,
                  total: views.where((v) => v.slot.section == section).length,
                  occupied: views
                      .where((v) =>
                          v.slot.section == section &&
                          !v.isAvailable &&
                          !v.isBlocked)
                      .length,
                  blocked: views
                      .where((v) => v.slot.section == section && v.isBlocked)
                      .length,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Notice shown on every user's home screen ──────────────────
        AdminCard(
          title: 'Notice for users',
          icon: Icons.campaign_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                announcement?.message ??
                    'No notice. Post one to show a message at the top of '
                        "every user's home screen.",
                style: TextStyle(
                  color: announcement == null ? context.semantic.muted : null,
                ),
              ),
              if (announcement?.updatedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Posted ${Formatters.dateTime(announcement!.updatedAt!)}',
                  style: TextStyle(fontSize: 12, color: context.semantic.muted),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => _editAnnouncement(
                              context, ref, announcement?.message ?? ''),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(announcement == null ? 'Post notice' : 'Edit'),
                    ),
                  ),
                  if (announcement != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            busy ? null : () => _clearAnnouncement(context, ref),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Quick actions ─────────────────────────────────────────────
        AdminCard(
          title: 'Quick actions',
          icon: Icons.bolt_rounded,
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_open_rounded,
                    color: AppColors.available),
                title: const Text('Reopen all closed slots'),
                subtitle: Text('${counts.blocked} closed right now'),
                enabled: !busy && counts.blocked > 0,
                onTap: () => _reopenAll(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.block_rounded, color: AppColors.occupied),
                title: const Text('Emergency: close all slots'),
                subtitle: const Text('Stops all new bookings'),
                enabled: !busy,
                onTap: () => _closeAll(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniNumber extends StatelessWidget {
  const _MiniNumber({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style:
                context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.semantic.muted),
          ),
        ],
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar({
    required this.section,
    required this.total,
    required this.occupied,
    required this.blocked,
  });

  final String section;
  final int total;
  final int occupied;
  final int blocked;

  @override
  Widget build(BuildContext context) {
    final free = total - occupied - blocked;
    final used = total == 0 ? 0.0 : (occupied + blocked) / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Both texts may shrink and wrap, so long section names like
          // "Motor Car / Jeep" never overflow on narrow phones.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  ParkingConfig.sectionName(section),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$occupied occupied · $blocked closed · $free free',
                  textAlign: TextAlign.end,
                  style:
                      TextStyle(fontSize: 12, color: context.semantic.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: used,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: AppColors.available.withValues(alpha: 0.18),
            color: used >= 0.9 ? AppColors.occupied : AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Owns its own TextEditingController so it is disposed safely.
class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({required this.initial});
  final String initial;

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notice for users'),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'e.g. Motor Bike parking is closed on Friday for floor painting.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: const Text('Publish'),
        ),
      ],
    );
  }
}
