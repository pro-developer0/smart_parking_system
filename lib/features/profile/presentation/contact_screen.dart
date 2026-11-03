import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/parking_config.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/auth_providers.dart';

/// Kinds of message a user can send to the parking office.
enum ContactTopic {
  complaint('Complaint', Icons.report_problem_outlined),
  query('Query', Icons.help_outline_rounded),
  feedback('Feedback', Icons.thumb_up_alt_outlined),
  other('Other', Icons.chat_outlined);

  const ContactTopic(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// "Contact us": the user writes a complaint / query / feedback and it is
/// sent by email to [ParkingConfig.supportEmail] through their email app,
/// with their account details filled in.
class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  ContactTopic _topic = ContactTopic.complaint;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(
      const ClipboardData(text: ParkingConfig.supportEmail),
    );
    if (mounted) AppSnackbar.success(context, 'Email address copied.');
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final p = ref.read(userProfileProvider).value;

    final subject = '[${_topic.label}] ${_subject.text.trim()}';
    final body = StringBuffer()
      ..writeln(_message.text.trim())
      ..writeln()
      ..writeln('-----')
      ..writeln('Sent from the ${ParkingConfig.lotName} app')
      ..writeln('Name: ${p?.name ?? '-'}')
      ..writeln('Account email: ${p?.email ?? '-'}')
      ..writeln('Phone: ${(p?.phone.isNotEmpty ?? false) ? p!.phone : '-'}')
      ..writeln('Vehicle: '
          '${(p?.vehicleNumber.isNotEmpty ?? false) ? p!.vehicleNumber : '-'}');

    final uri = Uri(
      scheme: 'mailto',
      path: ParkingConfig.supportEmail,
      // Built by hand: Uri's queryParameters encodes spaces as "+", which
      // many mail apps show literally.
      query: 'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body.toString())}',
    );

    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (opened) {
      AppSnackbar.success(
          context, 'Your email app is open. Tap send there to finish.');
    } else {
      await Clipboard.setData(
        const ClipboardData(text: ParkingConfig.supportEmail),
      );
      if (!mounted) return;
      AppSnackbar.error(
        context,
        'No email app found. The address ${ParkingConfig.supportEmail} '
        'was copied, so you can email us from any app.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact us')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Email address card ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: context.cardDecoration(),
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mail_outline_rounded,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email the parking office',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: context.semantic.muted)),
                            const SizedBox(height: 2),
                            const SelectableText(
                              ParkingConfig.supportEmail,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy email',
                        onPressed: _copyEmail,
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Have a complaint, a question, or anything to tell us? '
                  'Write it below and we will reply to your email.',
                  style: TextStyle(color: context.semantic.muted),
                ),
                const SizedBox(height: 20),

                // ── Topic ───────────────────────────────────────────────
                const Text('What is it about?',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in ContactTopic.values)
                      ChoiceChip(
                        avatar: Icon(t.icon, size: 18),
                        label: Text(t.label),
                        selected: _topic == t,
                        onSelected: (_) => setState(() => _topic = t),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Subject + message ───────────────────────────────────
                TextFormField(
                  controller: _subject,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'e.g. Someone parked in my booked slot',
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Please enter a short subject'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _message,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 6,
                  maxLines: 12,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Describe your complaint or question in detail '
                        '(slot number, date and time help us a lot).',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Please write at least a few words'
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your name, phone and vehicle number are added to the '
                  'email automatically.',
                  style: TextStyle(
                      fontSize: 12.5, color: context.semantic.muted),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Send email',
                  icon: Icons.send_rounded,
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
