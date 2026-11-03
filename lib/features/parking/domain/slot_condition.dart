import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// What the admin has set for a slot. Every slot is [open] unless the admin
/// changes it from the admin panel. Stored at `slots/{slotId}` in Firestore
/// (no document = open).
enum SlotCondition {
  open(
    label: 'Open',
    userMessage: 'This slot is open for booking.',
    icon: Icons.check_circle_outline_rounded,
    color: AppColors.available,
  ),
  construction(
    label: 'Under construction',
    userMessage: 'Construction work is going on at this slot.',
    icon: Icons.construction_rounded,
    color: AppColors.construction,
  ),
  maintenance(
    label: 'Maintenance',
    userMessage: 'This slot is under maintenance.',
    icon: Icons.build_rounded,
    color: AppColors.maintenance,
  ),
  reserved(
    label: 'Reserved',
    userMessage: 'This slot is reserved by the parking office.',
    icon: Icons.lock_rounded,
    color: AppColors.reserved,
  ),
  closed(
    label: 'Closed',
    userMessage: 'This slot has been closed by the admin.',
    icon: Icons.block_rounded,
    color: AppColors.closed,
  );

  const SlotCondition({
    required this.label,
    required this.userMessage,
    required this.icon,
    required this.color,
  });

  /// Short name shown in the admin panel and on chips.
  final String label;

  /// Default sentence shown to users when they tap a blocked slot.
  final String userMessage;
  final IconData icon;
  final Color color;

  static SlotCondition fromName(String? name) => SlotCondition.values
      .firstWhere((c) => c.name == name, orElse: () => SlotCondition.open);
}

/// The admin's setting for one slot, read from `slots/{slotId}`.
class SlotConditionInfo {
  const SlotConditionInfo({
    required this.slotId,
    required this.condition,
    this.note = '',
    this.until,
    this.updatedAt,
  });

  final String slotId;
  final SlotCondition condition;

  /// Optional message from the admin, e.g. "Floor painting until Friday".
  final String note;

  /// If set, the slot opens again automatically after this time.
  final DateTime? until;
  final DateTime? updatedAt;

  /// True while this setting is blocking the slot right now.
  bool isActive(DateTime now) =>
      condition != SlotCondition.open && (until == null || until!.isAfter(now));

  /// What the user sees: the admin's note if there is one, else the default.
  String get message => note.trim().isNotEmpty ? note.trim() : condition.userMessage;

  static SlotConditionInfo? tryFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    if (d == null) return null;
    try {
      return SlotConditionInfo(
        slotId: doc.id,
        condition: SlotCondition.fromName(d['condition'] as String?),
        note: (d['note'] ?? '') as String,
        until: (d['until'] as Timestamp?)?.toDate(),
        updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// A message the admin shows at the top of every user's home screen.
/// Stored at `app_config/announcement`.
class Announcement {
  const Announcement({required this.message, this.updatedAt});

  final String message;
  final DateTime? updatedAt;

  static Announcement? tryFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;
    final message = d['message'];
    if (message is! String || message.trim().isEmpty) return null;
    return Announcement(
      message: message.trim(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
