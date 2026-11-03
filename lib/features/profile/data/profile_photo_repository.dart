import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';

/// Thrown when a photo can't be saved for an expected reason.
class ProfilePhotoException implements Exception {
  ProfilePhotoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Saves each user's profile picture in Firestore at `user_photos/{uid}`.
///
/// Why Firestore and not Firebase Storage? New Firebase projects need the
/// paid Blaze plan to use Storage. The picture is resized to max 512 px and
/// compressed before upload (see ProfilePhotoController), so it is only about
/// 30–80 KB, well under Firestore's 1 MB document limit.
///
/// It lives in its own collection (not inside `users/{uid}`) so that loading
/// a profile or the admin's user list doesn't download every picture.
class ProfilePhotoRepository {
  ProfilePhotoRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Safety limit, below Firestore's 1 MB per document.
  static const int maxBytes = 700 * 1024;

  CollectionReference<Map<String, dynamic>> get _photos =>
      _firestore.collection('user_photos');

  /// Streams the picture bytes for [uid], or null when there is no picture.
  Stream<Uint8List?> watchPhoto(String uid) {
    return _photos.doc(uid).snapshots().map((doc) {
      final data = doc.data()?['data'];
      if (data is! String || data.isEmpty) return null;
      try {
        return base64Decode(data);
      } catch (_) {
        return null;
      }
    });
  }

  Future<void> savePhoto(String uid, Uint8List bytes) async {
    if (bytes.lengthInBytes > maxBytes) {
      throw ProfilePhotoException(
        'That picture is too large. Please choose a smaller one.',
      );
    }
    await _photos.doc(uid).set({
      'data': base64Encode(bytes),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removePhoto(String uid) => _photos.doc(uid).delete();
}

final profilePhotoRepositoryProvider = Provider<ProfilePhotoRepository>((ref) {
  return ProfilePhotoRepository(ref.watch(firestoreProvider));
});

/// The profile picture of any user, by uid. Decoded once per change, so the
/// same bytes are reused on every rebuild (no flicker).
final userPhotoProvider =
    StreamProvider.family<Uint8List?, String>((ref, uid) {
  return ref.watch(profilePhotoRepositoryProvider).watchPhoto(uid);
});
