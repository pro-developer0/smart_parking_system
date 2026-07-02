import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/parking_config.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/booking_controller.dart';
import '../application/parking_providers.dart';
import '../domain/booking.dart';
import 'widgets/countdown_ring.dart';

class MyBookingScreen extends ConsumerStatefulWidget {
  const MyBookingScreen({super.key});

  @override
  ConsumerState<MyBookingScreen> createState() => _MyBookingScreenState();
}

class _MyBookingScreenState extends ConsumerState<MyBookingScreen> {
  Future<void> _extend(Booking booking, int minutes) async {
    final ok = await ref
        .read(bookingControllerProvider.notifier)
        .extend(booking, Duration(minutes: minutes));
    if (!mounted) return;
    ok
        ? AppSnackbar.success(
            context, 'Extended by ${Formatters.durationLabel(Duration(minutes: minutes))}.')
        : AppSnackbar.error(
            context, mapBookingError(ref.read(bookingControllerProvider).error!));
  }

  Future<void> _endEarly(Booking booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave now?'),
        content: Text(
            'This frees slot ${booking.slotId} immediately for others.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.occupied),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave now')),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await ref
        .read(bookingControllerProvider.notifier)
        .endEarly(booking.id);
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, 'Slot released. Safe travels!');
      context.go(Routes.home);
    }
  }

  Future<void> _cancelUpcoming(Booking booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text('This frees slot ${booking.slotId} for others.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep it')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.occupied),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel booking')),
        ],
      ),
    );
    if (confirm != true) return;
    final ok =
        await ref.read(bookingControllerProvider.notifier).cancel(booking.id);
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, 'Booking cancelled.');
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ticks every second → smooth countdown and reactive expiry.
    ref.watch(tickerProvider);
    final booking = ref.watch(myBookingProvider);
    final now = DateTime.now();

    Widget body;
    if (booking == null) {
      body = _ExpiredView(onBack: () => context.go(Routes.home));
    } else if (booking.isUpcoming(now)) {
      body = _UpcomingView(
        booking: booking,
        now: now,
        onCancel: () => _cancelUpcoming(booking),
      );
    } else {
      body = _ActiveView(
        booking: booking,
        now: now,
        onExtend: _extend,
        onEndEarly: _endEarly,
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('My booking'),
      ),
      body: body,
    );
  }
}

class _UpcomingView extends ConsumerWidget {
  const _UpcomingView({
    required this.booking,
    required this.now,
    required this.onCancel,
  });
  final Booking booking;
  final DateTime now;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(bookingControllerProvider).isLoading;
    final untilStart = booking.startTime.difference(now);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Slot ${booking.slotId} · ${ParkingConfig.lotName}',
                style: const TextStyle(
                    color: AppColors.primaryDark, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available_rounded,
                      color: AppColors.primary, size: 32),
                  const SizedBox(height: 6),
                  Text(
                    Formatters.remaining(untilStart),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18),
                  ),
                  Text('until start',
                      style: TextStyle(
                          color: context.semantic.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _MiniInfo(
                  label: 'Starts at',
                  value: Formatters.time(booking.startTime),
                  icon: Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniInfo(
                  label: 'Ends at',
                  value: Formatters.time(booking.endTime),
                  icon: Icons.flag_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This slot will be reserved for you starting '
            '${Formatters.time(booking.startTime)}.',
            style: TextStyle(color: context.semantic.muted, fontSize: 13),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Cancel booking',
            icon: Icons.close_rounded,
            color: AppColors.occupied,
            isLoading: loading,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _ActiveView extends ConsumerWidget {
  const _ActiveView({
    required this.booking,
    required this.now,
    required this.onExtend,
    required this.onEndEarly,
  });

  final Booking booking;
  final DateTime now;
  final void Function(Booking, int) onExtend;
  final void Function(Booking) onEndEarly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = booking.remaining(now);
    final loading = ref.watch(bookingControllerProvider).isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Slot ${booking.slotId} · ${ParkingConfig.lotName}',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: CountdownRing(
              progress: booking.progress(now),
              remaining: remaining,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _MiniInfo(
                  label: 'Started',
                  value: Formatters.time(booking.startTime),
                  icon: Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniInfo(
                  label: 'Ends at',
                  value: Formatters.time(booking.endTime),
                  icon: Icons.flag_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Extend time',
              style: context.text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'You can only extend while your booking is still active.',
            style: TextStyle(color: context.semantic.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final m in ParkingConfig.extensionOptionsMinutes) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        loading ? null : () => onExtend(booking, m),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: context.semantic.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('+${m}m',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                if (m != ParkingConfig.extensionOptionsMinutes.last)
                  const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Leave now & free slot',
            icon: Icons.logout_rounded,
            color: AppColors.occupied,
            isLoading: loading,
            onPressed: () => onEndEarly(booking),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.semantic.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.semantic.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.semantic.muted),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: context.semantic.muted)),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpiredView extends StatelessWidget {
  const _ExpiredView({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                color: AppColors.available.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.available, size: 44),
            ),
            const SizedBox(height: 20),
            Text('No active booking',
                style: context.text.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Your booking has ended and the slot is free again. '
              'Book a new slot whenever you need one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.semantic.muted),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Back to parking',
              icon: Icons.local_parking_rounded,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}
