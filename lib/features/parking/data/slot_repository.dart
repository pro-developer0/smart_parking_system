import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/slot_condition.dart';

/// Owns the `slots` collection (admin slot settings) and the
/// `app_config/announcement` document.
///
/// Users only READ from here. Only admins may WRITE (enforced by
/// firestore.rules).
class SlotRepository {
  SlotRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _slots =>
      _firestore.collection('slots');

  DocumentReference<Map<String, dynamic>> get _announcement =>
      _firestore.collection('app_config').doc('announcement');

  /// Streams every slot the admin has changed, keyed by slot id (e.g. "A3").
  /// A slot that is not in the map is open.
  Stream<Map<String, SlotConditionInfo>> watchConditions() {
    return _slots.snapshots().map((snap) {
      final result = <String, SlotConditionInfo>{};
      for (final doc in snap.docs) {
        final info = SlotConditionInfo.tryFromDoc(doc);
        if (info != null) result[doc.id] = info;
      }
      return result;
    });
  }

  /// Sets the same condition on one or many slots in a single batch write.
  /// Setting [SlotCondition.open] deletes the documents (back to normal).
  Future<void> setCondition({
    required List<String> slotIds,
    required SlotCondition condition,
    required String adminId,
    String note = '',
    DateTime? until,
  }) async {
    final batch = _firestore.batch();
    for (final id in slotIds) {
      final ref = _slots.doc(id);
      if (condition == SlotCondition.open) {
        batch.delete(ref);
      } else {
        batch.set(ref, {
          'condition': condition.name,
          'note': note.trim(),
          'until': until == null ? null : Timestamp.fromDate(until),
          'updatedBy': adminId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Stream<Announcement?> watchAnnouncement() {
    return _announcement.snapshots().map(Announcement.tryFromDoc);
  }

  Future<void> setAnnouncement({
    required String message,
    required String adminId,
  }) {
    return _announcement.set({
      'message': message.trim(),
      'updatedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearAnnouncement() => _announcement.delete();
}

final slotRepositoryProvider = Provider<SlotRepository>((ref) {
  return SlotRepository(ref.watch(firestoreProvider));
});
