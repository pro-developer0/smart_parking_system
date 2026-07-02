import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notifications = ref.watch(notificationsProvider);

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
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).set(ThemeMode.system),
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
          _SectionLabel('Notifications'),
          _Card(
            child: SwitchListTile(
              title: const Text('Notifications'),
              subtitle: Text('Notify me 1 minute before my time runs out',
                  style: TextStyle(color: context.semantic.muted)),
              value: notifications,
              onChanged: (v) =>
                  ref.read(notificationsProvider.notifier).set(v),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('About'),
          _Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('Version'),
                  trailing: Text('1.0.0'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.local_parking_rounded),
                  title: Text('ParkEase'),
                  subtitle: Text('Smart parking, minus the circling.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.semantic.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.semantic.border),
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
