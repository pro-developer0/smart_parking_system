import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/constants/parking_config.dart';

/// Color used for everything CCTV / security related.
const Color _cctvColor = AppColors.available;

/// Small blinking red dot with "LIVE" text, like a recording indicator.
class CctvLiveIndicator extends StatefulWidget {
  const CctvLiveIndicator({super.key});

  @override
  State<CctvLiveIndicator> createState() => _CctvLiveIndicatorState();
}

class _CctvLiveIndicatorState extends State<CctvLiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.occupied.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.25, end: 1).animate(_blink),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.occupied,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: AppColors.occupied,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Camera icon for app bars. Tapping it explains the CCTV coverage.
class CctvAppBarButton extends StatelessWidget {
  const CctvAppBarButton({super.key, this.forAdmin = false});
  final bool forAdmin;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'CCTV surveillance active',
      onPressed: () => showCctvInfoSheet(context, forAdmin: forAdmin),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.videocam_rounded, color: _cctvColor),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.occupied,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card telling the user (or admin) the parking is watched by cameras.
/// Tapping it opens [showCctvInfoSheet].
class CctvStatusCard extends StatelessWidget {
  const CctvStatusCard({super.key, this.forAdmin = false});
  final bool forAdmin;

  @override
  Widget build(BuildContext context) {
    final title = forAdmin
        ? 'CCTV surveillance active'
        : 'Your vehicle is safe with us';
    final subtitle = forAdmin
        ? '${ParkingConfig.cctvCameraCount} cameras covering all '
            '${ParkingConfig.sections.length} sections · monitored 24/7'
        : 'This parking is under 24/7 CCTV camera surveillance, '
            'monitored by the parking administration.';

    return Material(
      color: _cctvColor.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _cctvColor.withValues(alpha: 0.40)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showCctvInfoSheet(context, forAdmin: forAdmin),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: _cctvColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  forAdmin
                      ? Icons.videocam_rounded
                      : Icons.verified_user_rounded,
                  color: _cctvColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const CctvLiveIndicator(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.semantic.muted,
                      ),
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

/// Bottom sheet with details about the camera coverage.
Future<void> showCctvInfoSheet(BuildContext context, {bool forAdmin = false}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Without this the sheet is capped at ~56% of the screen height and the
    // content overflowed on smaller phones. Now it sizes to its content and
    // scrolls if the screen is too short.
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videocam_rounded, color: _cctvColor, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    forAdmin ? 'Camera surveillance' : 'Protected by CCTV',
                    style: context.text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const CctvLiveIndicator(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              forAdmin
                  ? 'The whole of ${ParkingConfig.lotName} is covered by '
                      'security cameras. Keep an eye on the monitors and '
                      'respond quickly to anything unusual.'
                  : 'Park with peace of mind. ${ParkingConfig.lotName} is '
                      'watched by security cameras and the parking admins '
                      'keep an eye on every vehicle.',
              style: TextStyle(color: context.semantic.muted),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.videocam_outlined,
              text: '${ParkingConfig.cctvCameraCount} CCTV cameras in the lot',
            ),
            for (final section in ParkingConfig.sections)
              _InfoRow(
                icon: Icons.check_circle_rounded,
                text: '${ParkingConfig.sectionName(section)} section covered',
              ),
            const _InfoRow(
              icon: Icons.schedule_rounded,
              text: 'Recording and monitoring 24 hours a day, 7 days a week',
            ),
            _InfoRow(
              icon: Icons.admin_panel_settings_outlined,
              text: forAdmin
                  ? 'Report incidents to security right away'
                  : 'Parking admins watch the cameras and act on any issue',
            ),
          ],
        ),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _cctvColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
