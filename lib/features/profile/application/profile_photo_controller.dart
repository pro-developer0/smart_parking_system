import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/application/auth_providers.dart';
import '../data/profile_photo_repository.dart';

/// Result of trying to change the profile picture.
enum PhotoResult { saved, removed, cancelled, failed }

/// Picks a picture (gallery or camera), shrinks it and uploads it.
/// The UI watches this for the loading spinner on the avatar.
class ProfilePhotoController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  ProfilePhotoRepository get _repo => ref.read(profilePhotoRepositoryProvider);

  Future<PhotoResult> pickAndUpload(ImageSource source) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return PhotoResult.failed;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        // Shrink before upload: small, fast and fits in Firestore.
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
    } catch (e) {
      // e.g. camera permission denied, or no camera on the device.
      state = AsyncError(e, StackTrace.current);
      return PhotoResult.failed;
    }
    if (picked == null) return PhotoResult.cancelled; // user pressed back
    final XFile file = picked;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bytes = await file.readAsBytes();
      await _repo.savePhoto(uid, bytes);
    });
    return state.hasError ? PhotoResult.failed : PhotoResult.saved;
  }

  Future<PhotoResult> remove() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return PhotoResult.failed;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.removePhoto(uid));
    return state.hasError ? PhotoResult.failed : PhotoResult.removed;
  }
}

final profilePhotoControllerProvider =
    AsyncNotifierProvider<ProfilePhotoController, void>(
  ProfilePhotoController.new,
);

String mapPhotoError(Object? error) {
  if (error is ProfilePhotoException) return error.message;
  return "Couldn't update your photo. Please try again.";
}
