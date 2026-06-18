# Trans-Hub — Supabase Backend

Implements the backend strategy from the modernization plan (TH-009 … TH-012).

## Layout

```
supabase/
├── migrations/
│   ├── 0001_init_schema.sql   # TH-011 — tables, FKs, indexes, audit fields
│   └── 0002_rls_policies.sql  # TH-012 — Row-Level Security policies
└── README.md
```

## Environments (TH-009)

Three logical environments: `development`, `staging`, `production`. Each gets
its own Supabase project and env file (`.env.dev`, `.env.staging`, `.env.prod`),
copied from [`flutter_app/.env.example`](../flutter_app/.env.example).

> Secrets are **never** committed. Env files are gitignored; rotate keys
> regularly.

## Schema (TH-011)

Tables: `users`, `companies`, `services`, `bookings`, `booking_events`,
`reviews`, `favorites`, `notifications`.

Every table has `created_at`; mutable tables also have `updated_at` maintained
by the `set_updated_at()` trigger. Foreign keys and indexes are defined for all
hot query paths.

## Security (TH-010 / TH-012)

- **Authentication** is delegated to **Supabase Auth** (email/password, Google,
  Apple). No passwords are stored in application tables — `public.users.id`
  references `auth.users.id`. This eliminates the plaintext-password problem
  (P2) entirely on the backend.
- **Row-Level Security** is enabled on every table:
  - Customers: manage own profile, own bookings, own favorites.
  - Providers: manage owned companies + services, see assigned bookings.
  - Public: read company listings, services and reviews.

## Applying

```bash
# Using the Supabase CLI
supabase link --project-ref <ref>
supabase db push

# Or directly
psql "$DATABASE_URL" -f migrations/0001_init_schema.sql
psql "$DATABASE_URL" -f migrations/0002_rls_policies.sql
```

## Client integration

The Flutter app reads config from `--dart-define` via
[`AppConfig`](../flutter_app/lib/core/config/app_config.dart). While no backend
is configured (`hasRemoteBackend == false`), the app runs fully offline against
Hive. Wiring a `SupabaseRemoteDataSource` into the repository layer
(`data/datasources/remote/`) flips Hive to a cache role (TH-013).
