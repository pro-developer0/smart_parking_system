import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/parking_config.dart';
import '../../../../core/utils/formatters.dart';

/// Expandable "Smart Parking System" tile in Settings → About. Opening it
/// lists, in plain text, everything the app does. Numbers come from
/// [ParkingConfig] so the text stays correct when the config changes.
/// Admins also see the admin-panel topics.
class AboutAppSection extends StatelessWidget {
  const AboutAppSection({super.key, required this.isAdmin});
  final bool isAdmin;

  static String _list(Iterable<String> items) {
    final l = items.toList();
    if (l.length <= 1) return l.join();
    return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
  }

  @override
  Widget build(BuildContext context) {
    final sectionsText = _list([
      for (final s in ParkingConfig.sections)
        '${ParkingConfig.sectionName(s)} (${ParkingConfig.slotsPerSection[s]} '
            'slots, ${s}1–$s${ParkingConfig.slotsPerSection[s]})',
    ]);
    final durations = _list(ParkingConfig.durationOptionsMinutes
        .map((m) => Formatters.durationLabel(Duration(minutes: m))));
    final extensions = _list(ParkingConfig.extensionOptionsMinutes
        .map((m) => Formatters.durationLabel(Duration(minutes: m))));
    final maxLength = Formatters.durationLabel(
        const Duration(minutes: ParkingConfig.maxBookingMinutes));
    final leads = _list(
        ParkingConfig.notificationLeadOptionsMinutes.map((m) => '$m min'));

    final topics = <_Topic>[
      _Topic(Icons.local_parking_rounded, 'Parking lot', [
        '${ParkingConfig.lotName} has ${ParkingConfig.slots.length} slots '
            'in ${ParkingConfig.sections.length} sections: $sectionsText.',
        'Slot availability on the home screen updates live for everyone.',
        'Colours: green = available, red = occupied, indigo = your spot, '
            'amber/grey = closed by the admin (construction, maintenance, '
            'reserved or closed).',
      ]),
      _Topic(Icons.badge_outlined, 'Before you book', [
        'A phone number and vehicle number are required. Until both are '
            'added in your profile you cannot book a slot.',
        'A suspended account cannot make bookings. Contact the parking '
            'office if this happens.',
      ]),
      _Topic(Icons.event_available_rounded, 'Booking a slot', [
        'Tap a green slot, choose to start now or schedule a start time, '
            'then pick a duration.',
        'Durations available: $durations.',
        'You can hold one active or upcoming booking at a time.',
        'Two people can never book the same slot for overlapping times. '
            'The app checks this when you confirm.',
      ]),
      _Topic(Icons.timer_outlined, 'Your active booking', [
        'My Booking shows a live countdown of the time left.',
        'You can extend by $extensions at a time. In total you can add up '
            'to half of your booked time (at least 1h), and a booking can '
            'never be longer than $maxLength.',
        'An extension is refused if someone else has booked the slot '
            'right after you.',
        'You can end a booking early, or cancel one that has not started '
            'yet.',
        'When your time ends the slot is freed automatically for others.',
      ]),
      _Topic(Icons.notifications_active_outlined, 'Notifications', [
        'You get a confirmation notification when you book.',
        'A reminder is sent before your time runs out. Choose $leads in '
            'Settings, or turn reminders off.',
      ]),
      _Topic(Icons.videocam_outlined, 'Security', [
        'The parking is covered by ${ParkingConfig.cctvCameraCount} CCTV '
            'cameras, monitored by the parking administration.',
        'Tap the camera icon on the home screen for details.',
      ]),
      _Topic(Icons.mail_outline_rounded, 'Contact us', [
        'Send complaints, queries or feedback from Profile → Contact us. '
            'It opens your email app addressed to '
            '${ParkingConfig.supportEmail}, with your name, phone and '
            'vehicle number filled in.',
      ]),
      _Topic(Icons.campaign_outlined, 'Notices', [
        'Messages from the parking office (closures, changes) appear at '
            'the top of the home screen.',
      ]),
      _Topic(Icons.person_outline_rounded, 'Profile & history', [
        'Edit your name, phone number, vehicle number and profile photo.',
        'Booking history lists your past bookings.',
        'Settings lets you choose a light, dark or system theme.',
      ]),
      if (isAdmin) ...[
        _Topic(Icons.dashboard_outlined, 'Admin · Dashboard', [
          'Live counts of available, occupied, closed and total slots.',
          'Bookings parked now, upcoming and made today.',
          'Occupancy for each section.',
          'Post or remove a notice shown to every user.',
          'Reopen all slots, or close the whole parking in an emergency '
              '(existing bookings stay valid).',
        ]),
        _Topic(Icons.local_parking_outlined, 'Admin · Slots', [
          'Set any slot to Open, Under construction, Maintenance, Reserved '
              'or Closed, with an optional message for users.',
          'Optionally reopen a slot automatically at a set time.',
          'Change a whole section at once from the ⋮ menu.',
        ]),
        _Topic(Icons.event_note_outlined, 'Admin · Bookings', [
          'See active bookings and the most recent bookings.',
          'End a booking now to free its slot, or cancel a booking.',
        ]),
        _Topic(Icons.people_outline_rounded, 'Admin · Users', [
          'Search users by name, email, vehicle or phone.',
          "View a user's details and current booking.",
          'Suspend a user from booking, or remove their profile photo.',
        ]),
      ],
    ];

    return Theme(
      // Hide the default divider lines ExpansionTile draws when open.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: const Icon(Icons.local_parking_rounded),
        title: const Text('Smart Parking System'),
        subtitle: Text(
          'Tap to see everything the app does',
          style: TextStyle(color: context.semantic.muted),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Check live slot availability, book ahead and manage your '
            'parking time, all in one app.',
            style: TextStyle(color: context.semantic.muted),
          ),
          const SizedBox(height: 12),
          for (final t in topics) _TopicView(topic: t),
        ],
      ),
    );
  }
}

class _Topic {
  const _Topic(this.icon, this.title, this.points);
  final IconData icon;
  final String title;
  final List<String> points;
}

class _TopicView extends StatelessWidget {
  const _TopicView({required this.topic});
  final _Topic topic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(topic.icon, size: 18, color: context.colors.primary),
              const SizedBox(width: 8),
              Text(
                topic.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in topic.points)
            Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(p)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
