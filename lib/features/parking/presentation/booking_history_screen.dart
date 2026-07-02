import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../application/parking_providers.dart';
import '../domain/booking.dart';

class BookingHistoryScreen extends ConsumerWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(userBookingsProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Booking history')),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text("Couldn't load your history")),
        data: (bookings) {
          if (bookings.isEmpty) return const _EmptyHistory();
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _HistoryTile(booking: bookings[i], now: now),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.booking, required this.now});
  final Booking booking;
  final DateTime now;

  ({Color color, String label, IconData icon}) get _meta {
    if (booking.isLive(now)) {
      return (
        color: AppColors.available,
        label: 'Active',
        icon: Icons.bolt_rounded
      );
    }
    return switch (booking.status) {
      BookingStatus.cancelled => (
          color: AppColors.occupied,
          label: 'Cancelled',
          icon: Icons.close_rounded
        ),
      _ => (
          color: AppColors.primary,
          label: 'Completed',
          icon: Icons.check_rounded
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.semantic.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.semantic.border),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(booking.slotId,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Formatters.dateTime(booking.startTime),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.durationLabel(booking.totalDuration)} · ends ${Formatters.time(booking.endTime)}',
                  style: TextStyle(
                      fontSize: 12.5, color: context.semantic.muted),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(meta.icon, size: 14, color: meta.color),
                const SizedBox(width: 4),
                Text(meta.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: meta.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 56, color: context.semantic.muted),
          const SizedBox(height: 12),
          const Text('No bookings yet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Your past reservations will appear here.',
              style: TextStyle(color: context.semantic.muted)),
        ],
      ),
    );
  }
}
