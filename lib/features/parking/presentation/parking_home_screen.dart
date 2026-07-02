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
import '../../auth/application/auth_providers.dart';
import '../application/parking_providers.dart';
import '../domain/parking_slot.dart';
import 'widgets/legend_bar.dart';
import 'widgets/slot_tile.dart';

class ParkingHomeScreen extends ConsumerWidget {
  const ParkingHomeScreen({super.key});

  void _onSlotTap(BuildContext context, WidgetRef ref, SlotView view) {
    switch (view.status) {
      case SlotStatus.available:
        context.pushNamed(
          Routes.booking,
          pathParameters: {'slotId': view.slot.id},
        );
      case SlotStatus.mine:
        context.push(Routes.myBooking);
      case SlotStatus.occupied:
        final booking = view.booking;
        final message = booking == null
            ? 'Slot ${view.slot.label} is occupied.'
            : booking.startTime.isAfter(DateTime.now())
                ? 'Slot ${view.slot.label} is reserved from '
                    '${Formatters.time(booking.startTime)} to ${Formatters.time(booking.endTime)}.'
                : 'Slot ${view.slot.label} is occupied until ${Formatters.time(booking.endTime)}.';
        AppSnackbar.info(context, message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps expired bookings tidied up server-side while the app is open.
    ref.watch(bookingJanitorProvider);
    // Ticks every second so countdowns on this screen stay live.
    ref.watch(tickerProvider);
    final counts = ref.watch(slotCountsProvider);
    final myBooking = ref.watch(myBookingProvider);
    final profile = ref.watch(userProfileProvider).value;
    final bookingsAsync = ref.watch(activeBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, ${profile?.name.split(' ').first ?? 'there'} 👋',
                style: context.text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(
              ParkingConfig.lotName,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: context.semantic.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: () => context.go(Routes.profile),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  profile?.initials ?? '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e,
          onRetry: () => ref.invalidate(activeBookingsProvider),
        ),
        data: (_) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeBookingsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _SummaryRow(available: counts.available, total: counts.total),
              const SizedBox(height: 16),
              if (myBooking != null) ...[
                _ActiveBookingCard(
                  slotId: myBooking.slotId,
                  startTime: myBooking.startTime,
                  endTime: myBooking.endTime,
                  upcoming: myBooking.isUpcoming(DateTime.now()),
                  onTap: () => context.push(Routes.myBooking),
                ),
                const SizedBox(height: 20),
              ],
              const _EntranceMarker(),
              const SizedBox(height: 16),
              _SlotSection(
                section: 'A',
                onTap: (v) => _onSlotTap(context, ref, v),
              ),
              const SizedBox(height: 20),
              _SlotSection(
                section: 'B',
                onTap: (v) => _onSlotTap(context, ref, v),
              ),
              const SizedBox(height: 24),
              const LegendBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.available, required this.total});
  final int available;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Available now',
            value: '$available',
            color: AppColors.available,
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Total spots',
            value: '$total',
            color: AppColors.primary,
            icon: Icons.local_parking_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.semantic.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.semantic.border),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: context.text.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: context.semantic.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveBookingCard extends ConsumerWidget {
  const _ActiveBookingCard({
    required this.slotId,
    required this.startTime,
    required this.endTime,
    required this.upcoming,
    required this.onTap,
  });
  final String slotId;
  final DateTime startTime;
  final DateTime endTime;
  final bool upcoming;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final remaining = endTime.difference(now);
    final untilStart = startTime.difference(now);

    final label = upcoming ? 'Upcoming booking' : 'Your active booking';
    final detail = upcoming
        ? '${Formatters.remaining(untilStart)} until start · starts ${Formatters.time(startTime)}'
        : '${Formatters.remaining(remaining)} left · ends ${Formatters.time(endTime)}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: upcoming
                ? [AppColors.primaryDark, AppColors.primaryDark.withValues(alpha: 0.75)]
                : const [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  slotId,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Header strip resembling the lot entrance for spatial context.
class _EntranceMarker extends StatelessWidget {
  const _EntranceMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.semantic.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login_rounded, size: 16, color: context.semantic.muted),
          const SizedBox(width: 8),
          Text('ENTRANCE',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: context.semantic.muted)),
        ],
      ),
    );
  }
}

class _SlotSection extends ConsumerWidget {
  const _SlotSection({required this.section, required this.onTap});
  final String section;
  final void Function(SlotView) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref
        .watch(slotViewsProvider)
        .where((v) => v.slot.section == section)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Section $section',
            style: context.text.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: views.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, i) => SlotTile(
            view: views[i],
            onTap: () => onTap(views[i]),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: context.semantic.muted),
            const SizedBox(height: 12),
            const Text("Couldn't load parking data"),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.semantic.muted),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
