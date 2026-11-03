import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/parking_config.dart';
import '../../core/providers/settings_providers.dart';
import '../../features/auth/application/auth_providers.dart';
import 'widgets/about_app_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notifications = ref.watch(notificationsProvider);
    final lead = ref.watch(notificationLeadProvider);
    final isAdmin = ref.watch(userProfileProvider).value?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _SectionLabel('Appearance'),
          _Card(
            child: Column(
              children: [
                _ThemeOption(
                  label: 'System default',
                  icon: Icons.brightness_auto_rounded,
                  selected: themeMode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .set(ThemeMode.system),
                ),
                const Divider(height: 1),
                _ThemeOption(
                  label: 'Light',
                  icon: Icons.light_mode_rounded,
                  selected: themeMode == ThemeMode.light,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).set(ThemeMode.light),
                ),
                const Divider(height: 1),
                _ThemeOption(
                  label: 'Dark',
                  icon: Icons.dark_mode_rounded,
                  selected: themeMode == ThemeMode.dark,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Booking reminders only matter to drivers, not admins.
          if (!isAdmin) ...[
            _SectionLabel('Notifications'),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Notifications'),
                    subtitle: Text(
                      'Notify me $lead minute${lead == 1 ? '' : 's'} '
                      'before my time runs out',
                      style: TextStyle(color: context.semantic.muted),
                    ),
                    value: notifications,
                    onChanged: (v) =>
                        ref.read(notificationsProvider.notifier).set(v),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remind me before my booking ends',
                          style: TextStyle(
                            color: notifications
                                ? null
                                : context.semantic.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m
                                in ParkingConfig.notificationLeadOptionsMinutes)
                              ChoiceChip(
                                label: Text('$m min'),
                                selected: lead == m,
                                onSelected: notifications
                                    ? (_) => ref
                                          .read(
                                            notificationLeadProvider.notifier,
                                          )
                                          .set(m)
                                    : null,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          _SectionLabel('About'),
          _Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Version'),
                  // Read from the installed app (pubspec `version:`), so it
                  // is always correct after a release.
                  trailing: Text(
                    ref.watch(appVersionProvider).value ?? '…',
                  ),
                ),
                const Divider(height: 1),
                AboutAppSection(isAdmin: isAdmin),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The installed app's version, e.g. "1.0.0 (1)".
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
});

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
          color: context.semantic.muted,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A Material (not a decorated Container) so the ListTiles inside can
    // paint their ink splashes on it instead of being hidden behind it.
    return Material(
      color: context.semantic.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.semantic.border),
      ),
      child: child,
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: context.colors.primary)
          : null,
      onTap: onTap,
    );
  }
}
