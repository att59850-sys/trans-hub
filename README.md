# 🚚 Trans-Hub

A trusted **transport & logistics marketplace** that connects customers with vetted
transport providers — and lets providers list services and manage bookings.

> Design: **Modern Material Design** (trust blue `#1565D8` + energetic orange `#FF7A18`).
> Built with **Flutter** (web + Android + iOS), offline-first, sync-ready.

## 📦 Repository structure

```
trans-hub/
├── flutter_app/          ← the application (Flutter, Clean Architecture)
├── supabase/             ← backend: schema + RLS migrations (TH-009…012)
├── ci/flutter.yml        ← CI/CD pipeline (TH-004); copy to .github/workflows/
└── CONTRIBUTING.md       ← git workflow & quality gates (TH-002/003)
```

> **Single codebase (TH-001).** The legacy Vanilla-JS web SPA (`index.html`,
> `js/`, `styles.css`) has been **removed**; Flutter Web is now the one web target.

## 🏛️ Architecture

The app follows **Clean Architecture** with three layers and a DI composition root:

```
presentation  (Riverpod providers, screens, widgets)
     │  depends on
domain        (entities, repository interfaces, use cases)   ← no Flutter/Hive
     │  implemented by
data          (Hive local datasource, DTOs, repository impls)
```

- **State management:** `flutter_riverpod` (TH-005)
- **Dependency injection:** `get_it` (`core/di/injection.dart`, TH-008)
- **Repositories** (TH-006): Auth, Company, Booking, Review, Favorites, Location
- **Use cases** (TH-007): LoginUser, RegisterUser, CreateBooking, UpdateBookingStatus,
  SubmitReview, ToggleFavorite, …
- **Security** (P2/TH-010): passwords are stored as **salted SHA-256 hashes**
  locally; production auth is delegated to **Supabase Auth**.
- **Offline-first** (TH-013): Hive is the local store today and becomes a cache
  once the Supabase remote datasource is enabled.

See [`flutter_app/README.md`](flutter_app/README.md) for app-level detail and
[`supabase/README.md`](supabase/README.md) for the backend.

## ✨ Features

### For customers
- Browse & search providers; filter by service type / verification; sort by
  rating, reviews or fleet size.
- Rich company profiles with services, transparent pricing, ratings & reviews.
- **Book a service** or **request a custom quote**.
- Save favorites, set location, track bookings.

### For providers
- Free provider account & public business profile.
- Dashboard: KPIs, manage services (CRUD), edit profile.
- Receive bookings & quotes; advance status through the full lifecycle.

### Booking lifecycle (TH-016)
```
draft → quote_requested → quote_sent → pending → accepted → in_transit → completed
                                                       └──────────→ cancelled
```
Every transition is recorded as a `booking_event`.

## 🆕 Transport service categories
Original: Freight, Movers, Courier, Coach, Ride. Plus **five new** categories:

| New service | Covers |
|-------------|--------|
| ❄️ Cold-Chain Logistics | Refrigerated & temperature-controlled |
| 🏗️ Heavy Haul & Machinery | Oversized / abnormal loads |
| ⚡ Green / EV Fleet | Zero-emission electric delivery |
| 🛩️ Air & Drone Freight | Air cargo + last-mile drone |
| ⛴️ Ferry & Marine | Ro-Ro & container marine transfer |

## ▶️ Run locally
```bash
cd flutter_app
flutter pub get
flutter run -d chrome          # or: flutter run -d <device>
```

## 🔑 Demo logins
| Role | Email | Password |
|------|-------|----------|
| Customer | `customer@demo.com` | `demo123` |
| Provider | `admin@transglobalfreight.com` | `demo123` |

## 🧪 Quality
```bash
cd flutter_app
dart format .
flutter analyze     # strict lints (analysis_options.yaml, TH-003)
flutter test        # unit + use-case tests (TH-020/021)
```
CI runs all of the above plus a web build on every push/PR (TH-004).

> ⚠️ Build note: `flutter build web` uses `dart2js` (~1.5 GB RAM). It runs in
> CI (GitHub Actions) and on normal dev machines; the constrained authoring
> sandbox cannot complete it. All sources parse cleanly and dependencies resolve.

## 🗺️ Modernization roadmap
This repo is being executed against the **Trans-Hub Modernization Plan**. Status:

| Phase | Items | Status |
|-------|-------|--------|
| 1 — Foundation | TH-001 consolidate · TH-002 workflow · TH-003 lints · TH-004 CI/CD | ✅ Done |
| 2 — Architecture | TH-005 Riverpod · TH-006 repositories · TH-007 use cases · TH-008 DI | ✅ Done |
| 3 — Backend | TH-009 envs · TH-010 auth · TH-011 schema · TH-012 RLS | 🟡 Scaffolded (migrations + config + dio client ready) |
| 4 — Offline sync | TH-013 cache+remote datasource ✅ · TH-014 sync engine + queue ✅ · TH-015 connectivity + banner ✅ | ✅ Done |
| 5 — Product | TH-016 lifecycle ✅ (wired into dashboard) · TH-017 verification ✅ (5-state workflow + dashboard panel + admin review queue) · TH-018 notifications ✅ (in-app inbox + bell badge) · TH-019 maps abstraction ✅ | ✅ Done |
| 6 — QA | TH-020 unit ✅ · TH-021 widget ✅ · TH-022 integration ✅ | ✅ Done |
| 7 — Ops | TH-023 monitoring abstraction ✅ · TH-024 analytics abstraction ✅ · TH-025 deploy automation ✅ | ✅ Done |

Deployment is documented in **[DEPLOYMENT.md](DEPLOYMENT.md)** and the release
checklist in **[DEFINITION_OF_DONE.md](DEFINITION_OF_DONE.md)**.
