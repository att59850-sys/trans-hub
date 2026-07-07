-- Trans-Hub — Row-Level Security policies (TH-012)
-- Goal: zero unauthorized access paths.
--
--   Customers : view/manage own profile, own bookings, own favorites.
--   Providers : manage owned companies + their services, see assigned bookings.
--   Public    : read company listings, services and reviews.

-- Enable RLS ----------------------------------------------------------------
alter table public.users          enable row level security;
alter table public.companies      enable row level security;
alter table public.services       enable row level security;
alter table public.bookings       enable row level security;
alter table public.booking_events enable row level security;
alter table public.reviews        enable row level security;
alter table public.favorites      enable row level security;
alter table public.notifications  enable row level security;

-- Helper: is the current user the owner of a company? -----------------------
create or replace function public.owns_company(c_id uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.companies c
    where c.id = c_id and c.owner_id = auth.uid()
  );
$$;

-- users ---------------------------------------------------------------------
create policy users_select_self on public.users
  for select using (id = auth.uid());
create policy users_update_self on public.users
  for update using (id = auth.uid()) with check (id = auth.uid());
create policy users_insert_self on public.users
  for insert with check (id = auth.uid());

-- companies -----------------------------------------------------------------
create policy companies_public_read on public.companies
  for select using (true);
create policy companies_owner_write on public.companies
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- services ------------------------------------------------------------------
create policy services_public_read on public.services
  for select using (true);
create policy services_owner_write on public.services
  for all using (public.owns_company(company_id))
  with check (public.owns_company(company_id));

-- reviews -------------------------------------------------------------------
create policy reviews_public_read on public.reviews
  for select using (true);
create policy reviews_author_insert on public.reviews
  for insert with check (user_id = auth.uid());
create policy reviews_author_modify on public.reviews
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy reviews_author_delete on public.reviews
  for delete using (user_id = auth.uid());

-- bookings ------------------------------------------------------------------
-- A booking is visible to its customer OR the owner of the target company.
create policy bookings_customer_read on public.bookings
  for select using (
    user_id = auth.uid() or public.owns_company(company_id)
  );
create policy bookings_customer_insert on public.bookings
  for insert with check (user_id = auth.uid());
-- Customers may cancel; providers may advance status.
create policy bookings_party_update on public.bookings
  for update using (
    user_id = auth.uid() or public.owns_company(company_id)
  ) with check (
    user_id = auth.uid() or public.owns_company(company_id)
  );

-- booking_events ------------------------------------------------------------
create policy booking_events_party_read on public.booking_events
  for select using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.user_id = auth.uid() or public.owns_company(b.company_id))
    )
  );
create policy booking_events_party_insert on public.booking_events
  for insert with check (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.user_id = auth.uid() or public.owns_company(b.company_id))
    )
  );

-- favorites -----------------------------------------------------------------
create policy favorites_owner_all on public.favorites
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- notifications -------------------------------------------------------------
create policy notifications_owner_read on public.notifications
  for select using (user_id = auth.uid());
create policy notifications_owner_update on public.notifications
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
