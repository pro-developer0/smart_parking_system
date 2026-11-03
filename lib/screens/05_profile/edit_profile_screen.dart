import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_snackbar.dart';
import '../../core/utils/validators.dart';
import '../shared_widgets/app_text_field.dart';
import '../shared_widgets/primary_button.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/data/auth_repository.dart';
import 'widgets/profile_photo_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _vehicle;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).value;
    _name = TextEditingController(text: profile?.name ?? '');
    _vehicle = TextEditingController(text: profile?.vehicleNumber ?? '');
    _phone = TextEditingController(text: profile?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _vehicle.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            uid: uid,
            name: _name.text,
            vehicleNumber: _vehicle.text.trim().toUpperCase(),
            phone: _phone.text,
          );
      if (!mounted) return;
      AppSnackbar.success(context, 'Profile updated.');
      context.pop();
    } catch (_) {
      if (mounted) AppSnackbar.error(context, "Couldn't save. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: EditableAvatar(
                    uid: profile?.uid,
                    initials: profile?.initials ?? '?',
                    radius: 48,
                  ),
                ),
                const SizedBox(height: 8),
                const Center(child: ChangePhotoHint()),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _vehicle,
                  label: 'Vehicle number *',
                  hint: 'ABC-123',
                  icon: Icons.directions_car_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: Validators.vehicleNumber,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _phone,
                  label: 'Phone number *',
                  hint: '+92 300 0000000',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: 8),
                Text(
                  '* Required to book a parking slot.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Save changes',
                  icon: Icons.save_rounded,
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
