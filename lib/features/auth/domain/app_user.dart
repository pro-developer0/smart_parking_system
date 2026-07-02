import 'package:cloud_firestore/cloud_firestore.dart';

/// Application-level user profile, stored at `users/{uid}` in Firestore.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.vehicleNumber = '',
    this.phone = '',
  });

  final String uid;
  final String name;
  final String email;
  final String vehicleNumber;
  final String phone;

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
    );
  }

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
    );
  }
}
