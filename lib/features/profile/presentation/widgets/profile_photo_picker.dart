import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../application/profile_photo_controller.dart';
import '../../data/profile_photo_repository.dart';
import 'user_avatar.dart';

/// Big avatar with a small camera button. Tapping it lets the user pick a
/// new picture from the gallery or camera, or remove the current one.
/// Used on the Profile and Edit profile screens.
class EditableAvatar extends ConsumerWidget {
  const EditableAvatar({
    super.key,
    required this.uid,
    required this.initials,
    this.radius = 44,
  });

  final String? uid;
  final String initials;
  final double radius;

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final id = uid;
    if (id == null) return;
    final hasPhoto = ref.read(userPhotoProvider(id)).value != null;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.occupied),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: AppColors.occupied),
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final controller = ref.read(profilePhotoControllerProvider.notifier);
    final result = switch (choice) {
      'gallery' => await controller.pickAndUpload(ImageSource.gallery),
      'camera' => await controller.pickAndUpload(ImageSource.camera),
      _ => await controller.remove(),
    };
    if (!context.mounted) return;

    switch (result) {
      case PhotoResult.saved:
        AppSnackbar.success(context, 'Profile photo updated.');
      case PhotoResult.removed:
        AppSnackbar.success(context, 'Profile photo removed.');
      case PhotoResult.failed:
        AppSnackbar.error(
          context,
          mapPhotoError(ref.read(profilePhotoControllerProvider).error),
        );
      case PhotoResult.cancelled:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploading = ref.watch(profilePhotoControllerProvider).isLoading;

    return GestureDetector(
      onTap: uploading ? null : () => _openPicker(context, ref),
      child: Stack(
        children: [
          UserAvatar(uid: uid, initials: initials, radius: radius),
          if (uploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.6,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.photo_camera_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small text button under the avatar ("Change photo").
class ChangePhotoHint extends StatelessWidget {
  const ChangePhotoHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Tap the photo to change it',
      style: TextStyle(fontSize: 12, color: context.semantic.muted),
    );
  }
}
