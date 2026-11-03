# Screens (all UI)

Every file that draws something on screen lives here, numbered in the order a user meets it.

| Folder | What's inside |
|---|---|
| `01_splash/` | Splash / loading screen shown at app start |
| `02_auth/` | Login and Sign-up screens |
| `03_main_shell/` | Bottom navigation bar wrapper (Home · History · Profile) |
| `04_parking/` | Parking home (slot grid), slot booking, my booking, booking history |
| `04_parking/widgets/` | Slot tile, legend bar, countdown ring |
| `05_profile/` | Profile, edit profile, contact |
| `05_profile/widgets/` | Avatar, photo picker |
| `06_settings/` | Settings screen + "About app" section |
| `07_admin/` | Admin panel and its tabs (dashboard, slots, bookings, users) |
| `07_admin/widgets/` | Admin card, slot editor bottom sheet |
| `shared_widgets/` | Reusable UI used by many screens (buttons, text fields, stat cards, dialogs, CCTV widgets) |

Logic (Firebase, controllers, models) stays in `lib/features/<feature>/` (`application/`, `data/`, `domain/`).
Navigation between screens is defined in `lib/app/router/app_router.dart`.
