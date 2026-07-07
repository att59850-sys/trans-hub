# Definition of Done

Derived from the Trans-Hub Modernization Plan v1.0. A release is complete only
when every box below is checked.

## Release gates

- [ ] **CI passes** — `ci/flutter.yml`: format → analyze → test → web build all green.
- [ ] **Tests pass** — unit (`test/`), widget (`test/widget_test.dart`), and
      integration (`integration_test/app_test.dart`) suites pass.
- [ ] **Security review passes** — no plaintext secrets; passwords salted-hashed
      (`PasswordHasher`); Supabase RLS policies reviewed (`supabase/migrations/0002_rls_policies.sql`).
- [ ] **No critical bugs remain** — issue tracker has zero open `severity:critical`.
- [ ] **Documentation is updated** — `README.md`, `DEPLOYMENT.md`, `supabase/README.md`,
      and `CONTRIBUTING.md` reflect the change.
- [ ] **Monitoring is enabled** — `CrashReporter` + `AnalyticsService` wired to a
      real provider in production (Noop implementations are dev-only).
- [ ] **Release notes are prepared** — changelog entry + tag annotation.

## Success metrics (targets)

| Metric | Target |
|--------|--------|
| Crash-free sessions | > 99.5% |
| Unit test coverage | ≥ 80% |
| Build success rate | ≥ 95% |
| App startup time | < 2 s |
| Sync success rate | > 99% |
| Booking completion rate | Increasing MoM |

## Plan task status (TH-001 … TH-025)

| ID | Task | Status |
|----|------|--------|
| TH-001 | Consolidate to single Flutter frontend | Done |
| TH-002 | Git workflow & branch strategy | Done |
| TH-003 | Strict lints | Done |
| TH-004 | CI pipeline | Done (`ci/flutter.yml`) |
| TH-005 | Riverpod state management | Done |
| TH-006 | Decompose DataService into repositories | Done |
| TH-007 | Use cases | Done |
| TH-008 | get_it dependency injection | Done |
| TH-009 | Environment config (Supabase) | Done |
| TH-010 | Secure auth (salted hashing) | Done |
| TH-011 | Database schema | Done |
| TH-012 | RLS policies | Done |
| TH-013 | Hive as cache + RemoteDataSource | Done |
| TH-014 | Sync engine + pending ops + server-wins | Done |
| TH-015 | Connectivity awareness + status bar | Done |
| TH-016 | 8-state booking lifecycle + events | Done |
| TH-017 | Provider verification status | Done |
| TH-018 | Notifications + push abstraction | Done |
| TH-019 | Maps abstraction | Done |
| TH-020 | Unit tests | Done |
| TH-021 | Widget tests | Done (`test/widget_test.dart`) |
| TH-022 | Integration tests | Done (`integration_test/app_test.dart`) |
| TH-023 | Crash reporter abstraction | Done |
| TH-024 | Analytics abstraction | Done |
| TH-025 | Deployment automation | Done (`ci/deploy.yml` + Fastlane) |
