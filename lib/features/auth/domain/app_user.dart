import 'package:cloud_firestore/cloud_firestore.dart';

/// Application-level user profile, stored at `users/{uid}` in Firestore.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.vehicleNumber = '',
    this.phone = '',
    this.role = 'user',
    this.suspended = false,
  });

  final String uid;
  final String name;
  final String email;
  final String vehicleNumber;
  final String phone;

  /// 'user' (default) or 'admin'. Set to 'admin' by hand in the Firebase
  /// console. A user can never change this from the app (firestore.rules).
  final String role;

  /// True when an admin has blocked this user from making bookings.
  final bool suspended;

  bool get isAdmin => role == 'admin';

  /// Phone and vehicle number are both required before booking a slot.
  bool get hasBookingDetails =>
      phone.trim().isNotEmpty && vehicleNumber.trim().isNotEmpty;

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      vehicleNumber: (map['vehicleNumber'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      role: (map['role'] ?? 'user') as String,
      suspended: (map['suspended'] ?? false) as bool,
    );
  }

  /// Fields the user is allowed to write. `role` and `suspended` are left out
  /// on purpose: only an admin may change them.
  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'vehicleNumber': vehicleNumber,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  AppUser copyWith({String? name, String? vehicleNumber, String? phone}) {
    return AppUser(
      uid: uid,
      email: email,
      name: name ?? this.name,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      phone: phone ?? this.phone,
      role: role,
      suspended: suspended,
    );
  }
}
