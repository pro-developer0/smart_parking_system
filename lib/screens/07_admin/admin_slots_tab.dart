import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/constants/parking_config.dart';
import '../../core/utils/app_snackbar.dart';
import '../shared_widgets/confirm_dialog.dart';
import '../../features/parking/application/parking_providers.dart';
import '../../features/parking/domain/parking_slot.dart';
import '../../features/parking/domain/slot_condition.dart';
import '../04_parking/widgets/legend_bar.dart';
import '../04_parking/widgets/slot_tile.dart';
import '../../features/admin/application/admin_controller.dart';
import 'widgets/slot_editor_sheet.dart';

/// Tab 2: the same slot grid users see. Tap a slot to change it, or use the
/// ⋮ menu next to a section to change every slot in that section.
class AdminSlotsTab extends ConsumerWidget {
  const AdminSlotsTab({super.key});

  Future<void> _openEditor(
    BuildContext context,
    SlotView view,
  ) async {
    final saved = await showSlotEditor(context, view);
    if (saved == true && context.mounted) {
      AppSnackbar.success(context, 'Slot ${view.slot.label} updated.');
    }
  }

  Future<void> _applyToSection(
    BuildContext context,
    WidgetRef ref,
    String section,
    SlotCondition condition,
  ) async {
    final ids = [
      for (final s in ParkingConfig.slots)
        if (s.section == section) s.id,
    ];
    final what = condition == SlotCondition.open
        ? 'open every slot in ${ParkingConfig.sectionName(section)}'
        : 'mark every slot in ${ParkingConfig.sectionName(section)} as "${condition.label}"';
    final confirm = await showConfirmDialog(
      context,
      title: ParkingConfig.sectionName(section),
      message: 'This will $what.'
          '${condition == SlotCondition.open ? '' : '\nExisting bookings stay valid.'}',
      action: 'Apply',
      color: condition.color,
    );
    if (!confirm || !context.mounted) return;

    final ok = await ref
        .read(adminControllerProvider.notifier)
        .updateSlots(slotIds: ids, condition: condition);
    if (!context.mounted) return;
    ok
        ? AppSnackbar.success(context, '${ParkingConfig.sectionName(section)} updated.')
        : AppSnackbar.error(
            context, mapAdminError(ref.read(adminControllerProvider).error));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(slotViewsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tap a slot to close it, mark construction or reopen it. '
                  'Use ⋮ to change a whole section.',
                  style: TextStyle(fontSize: 12.5, color: context.semantic.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final section in ParkingConfig.sections) ...[
          Row(
            children: [
              Text(
                ParkingConfig.sectionName(section),
                style: context.text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              PopupMenuButton<SlotCondition>(
                tooltip: 'Change whole section',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (c) => _applyToSection(context, ref, section, c),
                itemBuilder: (_) => [
                  for (final c in SlotCondition.values)
                    PopupMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(c.icon, color: c.color, size: 20),
                          const SizedBox(width: 10),
                          Text(c == SlotCondition.open
                              ? 'Open all'
                              : 'All: ${c.label}'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.92,
            children: [
              for (final v in views)
                if (v.slot.section == section)
                  SlotTile(view: v, onTap: () => _openEditor(context, v)),
            ],
          ),
          const SizedBox(height: 20),
        ],
        const LegendBar(),
      ],
    );
  }
}
