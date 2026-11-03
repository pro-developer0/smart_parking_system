/// Form validators shared by the signup and edit-profile screens.
abstract class Validators {
  /// Required phone number with at least 10 digits (spaces, dashes, "+" ok).
  static String? phone(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\+?[0-9\s\-()]+$').hasMatch(value)) {
      return 'Use digits only (e.g. 03001234567)';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Required vehicle registration number (letters, digits, dashes, spaces).
  static String? vehicleNumber(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Vehicle number is required';
    if (value.length < 3) return 'Enter a valid vehicle number';
    if (!RegExp(r'^[A-Za-z0-9\s\-]+$').hasMatch(value)) {
      return 'Use letters, numbers and dashes only';
    }
    return null;
  }
}
