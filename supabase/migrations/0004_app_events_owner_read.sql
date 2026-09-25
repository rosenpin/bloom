-- The app sends app_events as INSERT ... ON CONFLICT (id) DO NOTHING, so a
-- retried event is ignored instead of duplicated. Postgres checks the arbiter
-- row of ON CONFLICT under the SELECT policy, and app_events had none, so every
-- event failed with "new row violates row-level security policy". The outbox
-- drains in order, so the first event blocked every later row (plans, sessions)
-- from syncing. session_events already pairs its insert policy with this read.
create policy "app_events_owner_read"
on public.app_events for select to authenticated
using ((select auth.uid()) = user_id);
