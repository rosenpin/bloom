-- Bring the server mirror forward with the app-owned fields added to Drift in
-- local schema v2. These are required for a faithful fresh-install restore.
alter table public.profiles
  add column unit_prompt_seen boolean not null default false;

alter table public.session_records
  add column plan_ref text not null default '',
  add column mesocycle_index integer not null default 1
    check (mesocycle_index >= 1),
  add column mesocycle_week_index integer not null default 1
    check (mesocycle_week_index >= 1),
  add column absolute_week_index integer not null default 1
    check (absolute_week_index >= 1),
  add column week_kind text not null default 'build'
    check (week_kind in ('build', 'easier', 'push', 'deload')),
  add column abandoned_at timestamptz,
  add constraint session_records_closed_once
    check (completed_at is null or abandoned_at is null);

create table public.app_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  props jsonb not null default '{}'::jsonb,
  client_ts timestamptz not null,
  created_at timestamptz not null default now()
);

create index app_events_name_created_idx
  on public.app_events (name, created_at);

alter table public.app_events enable row level security;

create policy "app_events_owner_insert"
on public.app_events for insert to authenticated
with check ((select auth.uid()) = user_id);
