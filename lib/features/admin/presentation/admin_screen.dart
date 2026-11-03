import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/parking_config.dart';
import '../../../core/widgets/cctv_widgets.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_providers.dart';
import 'admin_bookings_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_slots_tab.dart';
import 'admin_users_tab.dart';

/// Home of the admin panel. Users with `role: "admin"` are sent here by the
/// router instead of the normal parking app. Four tabs at the bottom:
/// Dashboard · Slots · Bookings · Users.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _index = 0;

  static const _titles = ['Dashboard', 'Manage slots', 'Bookings', 'Users'];

  Future<void> _logout() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You will leave the admin panel.',
      action: 'Log out',
    );
    if (!confirm) return;
    await ref.read(authControllerProvider.notifier).signOut();
    // The router sends us back to /login automatically.
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the database tidy: marks finished bookings as completed.
    ref.watch(adminJanitorProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_index]),
            Text(
              'Admin panel · ${ParkingConfig.lotName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: context.semantic.muted,
              ),
            ),
          ],
        ),
        actions: [
          const CctvAppBarButton(forAdmin: true),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.occupied),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          AdminDashboardTab(),
          AdminSlotsTab(),
          AdminBookingsTab(),
          AdminUsersTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_parking_outlined),
            selectedIcon: Icon(Icons.local_parking_rounded),
            label: 'Slots',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Users',
          ),
        ],
      ),
    );
  }
}
