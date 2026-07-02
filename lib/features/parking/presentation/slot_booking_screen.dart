import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/parking_config.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/auth_providers.dart';
import '../application/booking_controller.dart';
import '../application/parking_providers.dart';
import '../domain/parking_slot.dart';

class SlotBookingScreen extends ConsumerStatefulWidget {
  const SlotBookingScreen({super.key, required this.slotId});
  final String slotId;

  @override
  ConsumerState<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends ConsumerState<SlotBookingScreen> {
  int _minutes = ParkingConfig.durationOptionsMinutes[1]; // default 60

  /// null means "start now". Otherwise a specific time chosen for today.
  DateTime? _customStart;

  DateTime get _startTime => _customStart ?? DateTime.now();

  Future<void> _pickStartTime() async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_customStart ?? now),
      helpText: 'Choose start time',
    );
    if (picked == null || !mounted) return;

    var start = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (start.isBefore(now)) {
      // Booking is for today only — treat an earlier time as tomorrow.
      start = start.add(const Duration(days: 1));
      if (start.difference(now) > const Duration(hours: 20)) {
        AppSnackbar.info(context, "That time has passed — starting now instead.");
        setState(() => _customStart = null);
        return;
      }
    }
    setState(() => _customStart = start);
  }

  Future<void> _confirm() async {
    final ok = await ref.read(bookingControllerProvider.notifier).book(
          slotId: widget.slotId,
          startTime: _startTime,
          duration: Duration(minutes: _minutes),
        );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, 'Slot ${widget.slotId} booked!');
      context.go(Routes.myBooking);
    } else {
      AppSnackbar.error(
          context, mapBookingError(ref.read(bookingControllerProvider).error!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(bookingControllerProvider).isLoading;
    final profile = ref.watch(userProfileProvider).value;

    // If the slot gets taken while we're here, reflect it.
    final view = ref.watch(slotViewsProvider).firstWhere(
          (v) => v.slot.id == widget.slotId,
          orElse: () => SlotView(
            slot: ParkingConfig.slots.firstWhere((s) => s.id == widget.slotId),
            status: SlotStatus.available,
          ),
        );
    final taken = view.status == SlotStatus.occupied;

    final start = _startTime;
    final end = start.add(Duration(minutes: _minutes));

    return Scaffold(
      appBar: AppBar(title: Text('Book slot ${widget.slotId}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SlotHero(slotId: widget.slotId),
              const SizedBox(height: 24),
              if (taken)
                _Banner(
                  color: AppColors.occupied,
                  icon: Icons.block_rounded,
                  text: 'This slot was just taken. Please pick another.',
                ),
              _SectionTitle(
                icon: Icons.schedule_rounded,
                label: 'Start time',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceCard(
                      label: 'Now',
                      subtitle: Formatters.time(DateTime.now()),
                      icon: Icons.bolt_rounded,
                      selected: _customStart == null,
                      onTap: () => setState(() => _customStart = null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChoiceCard(
                      label: 'Schedule',
                      subtitle: _customStart == null
                          ? 'Pick a time'
                          : Formatters.time(_customStart!),
                      icon: Icons.edit_calendar_rounded,
                      selected: _customStart != null,
                      onTap: _pickStartTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                icon: Icons.timelapse_rounded,
                label: 'Duration',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final m in ParkingConfig.durationOptionsMinutes)
                    _DurationChip(
                      label: Formatters.durationLabel(Duration(minutes: m)),
                      selected: _minutes == m,
                      onTap: () => setState(() => _minutes = m),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                icon: Icons.receipt_long_rounded,
                label: 'Summary',
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                vehicle: profile?.vehicleNumber ?? '',
                start: start,
                end: end,
                minutes: _minutes,
                scheduled: _customStart != null,
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: taken ? 'Slot unavailable' : 'Confirm booking',
                icon: Icons.check_rounded,
                isLoading: loading,
                onPressed: taken ? null : _confirm,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Your spot frees automatically when time ends.',
                  style: TextStyle(
                      fontSize: 12.5, color: context.semantic.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotHero extends StatelessWidget {
  const _SlotHero({required this.slotId});
  final String slotId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_parking_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text('Slot $slotId',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          Text(ParkingConfig.lotName,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.semantic.muted),
        const SizedBox(width: 8),
        Text(label,
            style: context.text.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : context.semantic.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : context.semantic.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? AppColors.primary : context.semantic.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.primary : null,
                      )),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: context.semantic.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : context.semantic.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : context.semantic.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.vehicle,
    required this.start,
    required this.end,
    required this.minutes,
    required this.scheduled,
  });
  final String vehicle;
  final DateTime start;
  final DateTime end;
  final int minutes;
  final bool scheduled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.semantic.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.semantic.border),
      ),
      child: Column(
        children: [
          _row(
            context,
            Icons.play_arrow_rounded,
            'Starts',
            scheduled
                ? '${Formatters.time(start)} (scheduled)'
                : '${Formatters.time(start)} (now)',
          ),
          const Divider(height: 22),
          _row(context, Icons.stop_rounded, 'Ends', Formatters.time(end)),
          const Divider(height: 22),
          _row(context, Icons.timelapse_rounded, 'Duration',
              Formatters.durationLabel(Duration(minutes: minutes))),
          if (vehicle.isNotEmpty) ...[
            const Divider(height: 22),
            _row(context, Icons.directions_car_rounded, 'Vehicle', vehicle),
          ],
        ],
      ),
    );
  }

  Widget _row(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.semantic.muted),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: context.semantic.muted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
