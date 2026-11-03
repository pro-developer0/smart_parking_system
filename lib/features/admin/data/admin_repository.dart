import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../auth/domain/app_user.dart';

/// Admin-only reads/writes on the `users` collection.
/// firestore.rules only lets admins list all users or change `suspended`.
class AdminRepository {
  AdminRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Every registered user, sorted by name.
  Stream<List<AppUser>> watchAllUsers() {
    return _users.snapshots().map((snap) {
      final users = <AppUser>[];
      for (final doc in snap.docs) {
        try {
          users.add(AppUser.fromMap(doc.id, doc.data()));
        } catch (_) {
          // Skip a broken user document instead of failing the whole list.
        }
      }
      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return users;
    });
  }

  /// Blocks (or unblocks) a user from making new bookings.
  Future<void> setSuspended(String uid, bool suspended) {
    return _users.doc(uid).set({
      'suspended': suspended,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(firestoreProvider));
});
