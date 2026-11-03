import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../features/profile/data/profile_photo_repository.dart';

/// Round avatar: shows the user's uploaded picture, or their initials
/// ("MG") on a purple circle when there is no picture.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.uid,
    required this.initials,
    this.radius = 18,
  });

  final String? uid;
  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = uid;
    final bytes = id == null ? null : ref.watch(userPhotoProvider(id)).value;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: bytes != null
          ? ClipOval(
              child: Image.memory(
                bytes,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            )
          : Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.75,
              ),
            ),
    );
  }
}
