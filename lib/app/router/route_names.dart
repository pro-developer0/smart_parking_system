/// Central route paths + names to avoid magic strings.
abstract class Routes {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const booking = 'booking'; // /home/booking/:slotId  (name)
  static const bookingPath = 'booking/:slotId';
  static const myBooking = '/my-booking';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const history = '/history';
  static const admin = '/admin';
  static const contact = '/contact';
}
