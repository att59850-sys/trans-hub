# 🚚 TransportHub — Flutter app

The **original-intended Flutter app** for the Transport Hub platform, rebuilt to
match the project's first design (the repo was scaffolded as `flutter_app`).
It is **offline-first using Hive** for local storage — exactly as the original
plan in `trans hub.txt` specified — so it runs fully without a backend.

> Design: **Style 1 — Modern Material Design** (trust blue `#1565D8` + energetic
> orange `#FF7A18`), built with Material 3 and Google Fonts (Inter).

## ✨ Features

### Two roles
- **Customer** — browse, compare, book services, request quotes, review.
- **Company / Provider** — list services and manage bookings from a dashboard.

### Customer experience
- Home with hero, location picker, category chips, **new services** highlight,
  top-rated providers and "why us".
- Browse with live search, category filter chips, verified-only filter and
  sorting (rating / reviews / fleet / name).
- Company profiles: services & transparent pricing, ratings, reviews,
  booking + quote bottom-sheet, write a review.
- "My bookings" tab to track requests and statuses.

### Provider dashboard
- KPIs (bookings, pending, services, rating).
- Services CRUD (add / edit / hide / delete) with icon & pricing model picker.
- Booking management with status updates (pending → confirmed → completed → cancelled).
- Editable business profile.

## 🆕 New transport services (integrated from both platforms)
On top of the original Freight, Movers, Courier, Coach and Ride categories:

| New service | Covers |
|-------------|--------|
| ❄️ Cold-Chain Logistics | Refrigerated / temperature-controlled (food, pharma) |
| 🏗️ Heavy Haul & Machinery | Oversized / abnormal loads with permits & escorts |
| ⚡ Green / EV Fleet | Zero-emission electric delivery + carbon reporting |
| 🛩️ Air & Drone Freight | Next-flight-out air cargo + last-mile drone |
| ⛴️ Ferry & Marine | Ro-Ro vehicle ferries & container transfers |

Each ships with seeded demo providers and bookable services. All data
(providers, services, reviews, demo bookings) is ported 1:1 from the web
platform so the two stay in sync.

## ▶️ Run

```bash
cd flutter_app
flutter pub get

# Web
flutter run -d chrome
# or build a release bundle (needs ~1.5GB RAM for dart2js):
flutter build web --release

# Mobile
flutter run            # Android / iOS device or emulator
```

## 🔑 Demo logins
| Role | Email | Password |
|------|-------|----------|
| Customer | `customer@demo.com` | `demo123` |
| Provider | `admin@transglobalfreight.com` | `demo123` |

Use **Account → Reset demo data** to restore the original seed at any time.

## 🗂️ Structure
```
lib/
  main.dart                 # app entry + Hive init
  models/models.dart        # User, Company, TransportService, Booking, Review + categories
  services/
    data_service.dart       # Hive-backed "backend" (auth, CRUD, bookings, reviews, favorites)
    seed_data.dart          # seed providers/services/reviews (ported from web platform)
  theme/app_theme.dart      # Material 3 theme, palette, icon & gradient maps
  widgets/widgets.dart      # CompanyCard, RatingBadge, toasts, empty states, etc.
  screens/
    shell.dart              # bottom-nav shell + brand app bar
    home_screen.dart
    browse_screen.dart
    company_screen.dart     # profile + booking/quote/review sheets
    bookings_screen.dart    # customer bookings
    dashboard_screen.dart   # provider dashboard
    account_screen.dart     # auth (login/signup) + profile
```

## 🔌 Going cloud
`DataService` isolates all persistence. To connect Firebase/Firestore later,
swap its method bodies for SDK calls — screens and widgets are unaffected.
