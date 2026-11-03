import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/providers/firebase_providers.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/formatters.dart';
import '../shared_widgets/confirm_dialog.dart';
import '../../features/parking/domain/booking.dart';
import '../../features/admin/application/admin_controller.dart';
import '../../features/admin/application/admin_providers.dart';

/// Tab 3: every booking. "Active" = parked now or starting later (the admin
/// can end or cancel them). "All recent" = the last 200 bookings.
class AdminBookingsTab extends ConsumerStatefulWidget {
  const AdminBookingsTab({super.key});

  @override
  ConsumerState<AdminBookingsTab> createState() => _AdminBookingsTabState();
}

class _AdminBookingsTabState extends ConsumerState<AdminBookingsTab> {
  bool _showAll = false;

  Future<void> _act(Booking booking, {required bool end}) async {
    final who = booking.userName.isEmpty ? 'this user' : booking.userName;
    final confirm = await showConfirmDialog(
      context,
      title: end ? 'End booking now?' : 'Cancel booking?',
      message: 'Slot ${booking.slotId} booked by $who will be freed immediately.',
      action: end ? 'End now' : 'Cancel booking',
      cancel: 'Keep it',
    );
    if (!confirm) return;
    final controller = ref.read(adminControllerProvider.notifier);
    final ok = end
        ? await controller.endBooking(booking)
        : await controller.cancelBooking(booking);
    if (!mounted) return;
    ok
        ? AppSnackbar.success(context, 'Slot ${booking.slotId} is free now.')
        : AppSnackbar.error(
            context, mapAdminError(ref.read(adminControllerProvider).error));
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now();
    final active = ref.watch(adminActiveBookingsProvider);
    final recentAsync = ref.watch(recentBookingsProvider);

    final List<Booking> list =
        _showAll ? (recentAsync.value ?? const <Booking>[]) : active;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text('Active (${active.length})'),
                  icon: const Icon(Icons.bolt_rounded),
                ),
                const ButtonSegment(
                  value: true,
                  label: Text('All recent'),
                  icon: Icon(Icons.history_rounded),
                ),
              ],
              selected: {_showAll},
              onSelectionChanged: (s) => setState(() => _showAll = s.first),
            ),
          ),
        ),
        Expanded(
          child: _showAll && recentAsync.isLoading && !recentAsync.hasValue
              ? const Center(child: CircularProgressIndicator())
              : _showAll && recentAsync.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          mapAdminError(recentAsync.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : list.isEmpty
                      ? Center(
                          child: Text(
                            _showAll
                                ? 'No bookings yet.'
                                : 'No one is parked or booked right now.',
                            style: TextStyle(color: context.semantic.muted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _BookingTile(
                            booking: list[i],
                            now: now,
                            onEnd: () => _act(list[i], end: true),
                            onCancel: () => _act(list[i], end: false),
                          ),
                        ),
        ),
      ],
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({
    required this.booking,
    required this.now,
    required this.onEnd,
    required this.onCancel,
  });

  final Booking booking;
  final DateTime now;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  ({String label, Color color}) get _state {
    if (booking.isLive(now)) {
      return (label: 'Parked now', color: AppColors.available);
    }
    if (booking.isUpcoming(now)) {
      return (label: 'Upcoming', color: AppColors.primary);
    }
    return switch (booking.status) {
      BookingStatus.cancelled => (label: 'Cancelled', color: AppColors.occupied),
      _ => (label: 'Completed', color: AppColors.closed),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final canAct = booking.isLive(now) || booking.isUpcoming(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: context.cardDecoration(16),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: state.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                booking.slotId,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: state.color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.userName.isEmpty ? 'Unknown user' : booking.userName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.dateTime(booking.startTime)} → '
                  '${Formatters.smartTime(booking.endTime)}'
                  '${booking.vehicleNumber.isEmpty ? '' : ' · ${booking.vehicleNumber}'}',
                  style: TextStyle(fontSize: 12.5, color: context.semantic.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  booking.isLive(now)
                      ? '${state.label} · ${Formatters.remaining(booking.remaining(now))} left'
                      : state.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: state.color,
                  ),
                ),
              ],
            ),
          ),
          if (canAct)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) => v == 'end' ? onEnd() : onCancel(),
              itemBuilder: (_) => [
                if (booking.isLive(now))
                  const PopupMenuItem(
                    value: 'end',
                    child: Text('End now & free slot'),
                  ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel booking'),
                ),
              ],
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}
