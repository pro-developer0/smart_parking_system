import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../parking/domain/parking_slot.dart';
import '../../../parking/domain/slot_condition.dart';
import '../../application/admin_controller.dart';

/// Opens the editor for one slot. Returns true when the admin saved.
Future<bool?> showSlotEditor(BuildContext context, SlotView view) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SlotEditorSheet(view: view),
  );
}

/// Lets the admin set a slot to Open / Under construction / Maintenance /
/// Reserved / Closed, with an optional message for users and an optional
/// time when it opens again automatically.
class SlotEditorSheet extends ConsumerStatefulWidget {
  const SlotEditorSheet({super.key, required this.view});
  final SlotView view;

  @override
  ConsumerState<SlotEditorSheet> createState() => _SlotEditorSheetState();
}

class _SlotEditorSheetState extends ConsumerState<SlotEditorSheet> {
  late SlotCondition _condition =
      widget.view.condition?.condition ?? SlotCondition.open;
  late final TextEditingController _note =
      TextEditingController(text: widget.view.condition?.note ?? '');
  late DateTime? _until = widget.view.condition?.until;
  bool _releaseBooking = true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickUntil() async {
    final now = DateTime.now();
    final start = _until ?? now.add(const Duration(hours: 2));
    final date = await showDatePicker(
      context: context,
      initialDate: start.isBefore(now) ? now : start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Opens again on',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
      helpText: 'Opens again at',
    );
    if (time == null || !mounted) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!picked.isAfter(now)) {
      AppSnackbar.info(context, 'Please choose a time in the future.');
      return;
    }
    setState(() => _until = picked);
  }

  Future<void> _save() async {
    final booking = widget.view.booking;
    final ok = await ref.read(adminControllerProvider.notifier).updateSlots(
          slotIds: [widget.view.slot.id],
          condition: _condition,
          note: _note.text,
          until: _condition == SlotCondition.open ? null : _until,
          releaseBookings: booking != null && _releaseBooking,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      AppSnackbar.error(
          context, mapAdminError(ref.read(adminControllerProvider).error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final booking = view.booking;
    final saving = ref.watch(adminControllerProvider).isLoading;
    final closing = _condition != SlotCondition.open;
    final now = DateTime.now();

    return Padding(
      // Moves the sheet up when the keyboard opens.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: _condition.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        view.slot.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: _condition.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Slot ${view.slot.label}',
                          style: context.text.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          view.isBlocked
                              ? 'Now: ${view.condition?.condition.label}'
                              : booking != null
                                  ? 'Now: booked'
                                  : 'Now: open and free',
                          style: TextStyle(color: context.semantic.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (booking != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.occupied.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.occupied.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car_rounded,
                          color: AppColors.occupied),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${booking.isUpcoming(now) ? 'Booked from' : 'Parked since'} '
                          '${Formatters.time(booking.startTime)} to '
                          '${Formatters.smartTime(booking.endTime)}\n'
                          '${booking.userName.isEmpty ? 'User' : booking.userName}'
                          '${booking.vehicleNumber.isEmpty ? '' : ' · ${booking.vehicleNumber}'}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Set slot to',
                style: context.text.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in SlotCondition.values)
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 18, color: c.color),
                      label: Text(c.label),
                      selected: _condition == c,
                      selectedColor: c.color.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _condition = c),
                    ),
                ],
              ),
              if (closing) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: _note,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Message for users (optional)',
                    hintText: _condition.userMessage,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.semantic.border),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.event_available_rounded),
                    title: const Text('Opens again automatically'),
                    subtitle: Text(
                      _until == null ? 'Never (until you reopen it)' : Formatters.dateTime(_until!),
                    ),
                    trailing: _until == null
                        ? const Icon(Icons.chevron_right_rounded)
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => _until = null),
                          ),
                    onTap: _pickUntil,
                  ),
                ),
                if (booking != null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _releaseBooking,
                    onChanged: (v) => setState(() => _releaseBooking = v ?? false),
                    title: Text(
                      booking.isUpcoming(now)
                          ? 'Also cancel this booking'
                          : 'Also end this booking now',
                    ),
                    subtitle: const Text('Otherwise the user keeps the slot'),
                  ),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: closing ? 'Save: ${_condition.label}' : 'Save: open slot',
                icon: _condition.icon,
                color: closing ? _condition.color : AppColors.available,
                isLoading: saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
