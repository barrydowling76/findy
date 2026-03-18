-- ============================================================
-- Findy — Supabase Schema
-- Run this in the Supabase SQL Editor after creating the project
-- ============================================================

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- ─── USERS ───
create table public.users (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  email       text not null unique,
  phone       text,
  pin         text not null,              -- 4-digit PIN (hashed would be better, plain for MVP)
  code        text not null unique,       -- unique short code for QR URLs (e.g. "AB12XY")
  email_verified boolean not null default false,
  wa_phone    text,                       -- WhatsApp phone number
  wa_api_key  text,                       -- CallMeBot API key
  created_at  timestamptz not null default now()
);

-- ─── ITEMS ───
create table public.items (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users(id) on delete cascade,
  name        text not null,
  emoji       text default '📦',
  created_at  timestamptz not null default now()
);

-- ─── REPORTS (finder submissions) ───
create table public.reports (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  item_name     text,
  message       text not null,
  finder_phone  text,
  finder_email  text,
  photo         text,                     -- base64 data URL (or storage path later)
  read          boolean not null default false,
  created_at    timestamptz not null default now()
);

-- ─── INDEXES ───
create index idx_users_email on public.users(email);
create index idx_users_code on public.users(code);
create index idx_items_user on public.items(user_id);
create index idx_reports_user on public.reports(user_id);
create index idx_reports_unread on public.reports(user_id) where read = false;

-- ─── ROW LEVEL SECURITY ───
alter table public.users enable row level security;
alter table public.items enable row level security;
alter table public.reports enable row level security;

-- Users: anyone can read (for QR code lookups), only the user can update their own row
create policy "Anyone can read users by code" on public.users for select using (true);
create policy "Users can update own row" on public.users for update using (id = auth.uid());

-- Items: owner can CRUD, anyone can read (for display on found page)
create policy "Anyone can read items" on public.items for select using (true);
create policy "Owner can insert items" on public.items for insert with check (user_id = auth.uid());
create policy "Owner can update items" on public.items for update using (user_id = auth.uid());
create policy "Owner can delete items" on public.items for delete using (user_id = auth.uid());

-- Reports: owner can read their reports, anyone can insert (finders are anonymous)
create policy "Owner can read own reports" on public.reports for select using (user_id = auth.uid());
create policy "Anyone can insert reports" on public.reports for insert with check (true);
create policy "Owner can update own reports" on public.reports for update using (user_id = auth.uid());

-- ─── ANON ACCESS: Allow public inserts for sign-up and finder reports ───
-- Since finders and new sign-ups aren't authenticated, we need anon access
-- We'll use Supabase service role for sign-up, and anon for finder report submission

-- Allow anon to read users (for QR code lookup by code)
create policy "Anon can read users" on public.users for select to anon using (true);

-- Allow anon to insert reports (finders submitting)
create policy "Anon can insert reports" on public.reports for insert to anon with check (true);

-- Allow anon to read items (for found page display)
create policy "Anon can read items" on public.items for select to anon using (true);
