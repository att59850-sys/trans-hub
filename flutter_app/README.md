# 🚚 Trans-Hub — Flutter app

The Trans-Hub marketplace, built with **Flutter** and structured per the
modernization plan: **Clean Architecture** (presentation → domain → data),
Riverpod state management, get_it dependency injection, and an offline-first
Hive datasource that is ready to become a cache behind Supabase.

> Design: **Modern Material Design** (trust blue `#1565D8` + energetic
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

## 🗂️ Structure (Clean Architecture)
```
lib/
  main.dart                       # entry: Hive init → DI → ProviderScope
  core/
    config/app_config.dart        # env config (--dart-define), TH-009
    di/injection.dart             # get_it composition root, TH-008
    errors/failures.dart          # typed domain failures
    utils/
      id_generator.dart
      password_hasher.dart        # salted SHA-256 hashing, P2/TH-010
  domain/                         # pure Dart — no Flutter/Hive
    entities/                     # one file per entity (+ entities.dart barrel)
    repositories/repositories.dart# repository interfaces, TH-006
    usecases/usecases.dart        # LoginUser, CreateBooking, …, TH-007
  data/
    datasources/local/hive_local_datasource.dart   # centralized Hive boxes, TH-013
    models/                       # DTOs: toJson/fromJson per entity
    repositories/                 # Hive-backed repository implementations
  presentation/
    providers/providers.dart      # Riverpod providers, TH-005
  services/
    data_service.dart             # reactive facade over the repo layer (legacy UI binding)
    seed_data.dart                # development seed fixtures
  theme/app_theme.dart            # Material 3 theme, palette, icon & gradient maps
  widgets/widgets.dart            # CompanyCard, RatingBadge, toasts, status badges
  screens/                        # home, browse, company, bookings, dashboard, account, shell
```

## 🔌 Going cloud (TH-013/014)
The repository **interfaces** in `domain/repositories/` are backend-agnostic. To
go online, add a `SupabaseRemoteDataSource` under `data/datasources/remote/`,
wrap each repository with a remote-first / cache-fallback implementation, and
register it in `core/di/injection.dart`. The UI, providers and use cases are
unaffected. See [`../supabase/`](../supabase) for the schema and RLS policies.

## 🧪 Tests
`test/` contains unit + use-case tests (run with `flutter test`):
- `password_hasher_test.dart` — salted hashing & legacy fallback
- `booking_status_test.dart` — 8-state lifecycle & transitions
- `dto_roundtrip_test.dart` — JSON (de)serialization fidelity
- `usecases_test.dart` — use cases against mocktail repositories
