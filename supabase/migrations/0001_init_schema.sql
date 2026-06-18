-- Trans-Hub — initial database schema (TH-011)
-- PostgreSQL / Supabase. Tables, foreign keys, indexes, timestamps, audit fields.
--
-- Apply with: supabase db push   (or psql -f this_file)

-- Extensions ----------------------------------------------------------------
create extension if not exists "pgcrypto";

-- Enums ---------------------------------------------------------------------
do $$ begin
  create type user_role as enum ('customer', 'company');
exception when duplicate_object then null; end $$;

do $$ begin
  create type booking_status as enum (
    'draft','quote_requested','quote_sent','pending',
    'accepted','in_transit','completed','cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type verification_status as enum (
    'unverified','submitted','under_review','approved','rejected'
  );
exception when duplicate_object then null; end $$;

-- Helper: auto-update updated_at --------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- users ---------------------------------------------------------------------
-- Mirrors auth.users (Supabase Auth owns credentials; no passwords here).
create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null default '',
  email       text not null,
  role        user_role not null default 'customer',
  company_id  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- companies -----------------------------------------------------------------
create table if not exists public.companies (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references public.users(id) on delete cascade,
  name                text not null,
  category            text not null default 'freight',
  tagline             text not null default '',
  description         text not null default '',
  city                text not null default '',
  coverage            text[] not null default array['Local'],
  fleet_size          int not null default 1,
  years_active        int not null default 0,
  verified            boolean not null default false,
  verification_status verification_status not null default 'unverified',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index if not exists idx_companies_owner    on public.companies(owner_id);
create index if not exists idx_companies_category on public.companies(category);
create index if not exists idx_companies_city     on public.companies(city);

alter table public.users
  add constraint fk_users_company
  foreign key (company_id) references public.companies(id) on delete set null
  not valid;

-- services ------------------------------------------------------------------
create table if not exists public.services (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  name        text not null,
  description text not null default '',
  unit        text not null default 'flat',
  price       numeric(12,2) not null default 0,
  icon        text not null default 'local_shipping',
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_services_company on public.services(company_id);

-- bookings ------------------------------------------------------------------
create table if not exists public.bookings (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade,
  service_id    uuid references public.services(id) on delete set null,
  user_id       uuid references public.users(id) on delete set null,
  contact_name  text not null default '',
  contact_email text not null default '',
  phone         text not null default '',
  pickup        text not null default '',
  dropoff       text not null default '',
  date          text not null default '',
  notes         text not null default '',
  status        booking_status not null default 'pending',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists idx_bookings_company on public.bookings(company_id);
create index if not exists idx_bookings_user    on public.bookings(user_id);
create index if not exists idx_bookings_status  on public.bookings(status);

-- booking_events (TH-016) ---------------------------------------------------
create table if not exists public.booking_events (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references public.bookings(id) on delete cascade,
  status      booking_status not null,
  note        text not null default '',
  created_at  timestamptz not null default now()
);
create index if not exists idx_booking_events_booking on public.booking_events(booking_id);

-- reviews -------------------------------------------------------------------
create table if not exists public.reviews (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  user_id     uuid references public.users(id) on delete set null,
  name        text not null default '',
  rating      int not null check (rating between 1 and 5),
  text        text not null default '',
  created_at  timestamptz not null default now()
);
create index if not exists idx_reviews_company on public.reviews(company_id);

-- favorites -----------------------------------------------------------------
create table if not exists public.favorites (
  user_id     uuid not null references public.users(id) on delete cascade,
  company_id  uuid not null references public.companies(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, company_id)
);

-- notifications (TH-018) ----------------------------------------------------
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users(id) on delete cascade,
  title       text not null,
  body        text not null default '',
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists idx_notifications_user on public.notifications(user_id);

-- updated_at triggers -------------------------------------------------------
create trigger trg_users_updated     before update on public.users     for each row execute function set_updated_at();
create trigger trg_companies_updated before update on public.companies for each row execute function set_updated_at();
create trigger trg_services_updated  before update on public.services  for each row execute function set_updated_at();
create trigger trg_bookings_updated  before update on public.bookings  for each row execute function set_updated_at();
