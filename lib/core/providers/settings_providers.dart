import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

/// Provided at app startup via an override (see main.dart).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences not initialised'),
);

/// Persists and exposes the user's light/dark preference.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(_key);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, mode.name);
  }

  Future<void> toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Simple notification toggle (persisted) used on the settings screen.
class NotificationsController extends Notifier<bool> {
  static const _key = 'notifications_enabled';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
    if (value) await NotificationService.instance.requestPermission();
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsController, bool>(NotificationsController.new);

/// Prompts for OS notification permission once per app session (if the
/// reminders setting is on). Watched from [MainScaffold] so it fires as
/// soon as the user reaches the signed-in part of the app. Harmless to
/// re-run — the OS only shows its own prompt once until the user responds.
final notificationPermissionPromptProvider = Provider<void>((ref) {
  if (ref.watch(notificationsProvider)) {
    NotificationService.instance.requestPermission();
  }
});
