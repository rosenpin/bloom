-- Local-first server mirror. All user IDs are owned by auth.uid(); content is
-- readable by both the signed-in app and the anonymous web quiz funnel.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  unit_system text not null check (unit_system in ('metric', 'imperial')),
  quiz_answers jsonb not null default '{}'::jsonb,
  last_period_start date,
  usual_gap_days integer check (usual_gap_days is null or usual_gap_days > 0),
  updated_at timestamptz not null default now()
);

create table public.plans (
  id text primary key check (length(id) = 26),
  user_id uuid not null references auth.users (id) on delete cascade,
  document jsonb not null,
  engine_version text not null,
  config_hash text not null,
  content_hash text not null,
  profile_hash text not null,
  mesocycle_index integer not null check (mesocycle_index >= 1),
  created_at timestamptz not null
);

create index plans_user_created_idx
  on public.plans (user_id, created_at desc);

create table public.session_records (
  id text primary key check (length(id) = 26),
  user_id uuid not null references auth.users (id) on delete cascade,
  plan_id text not null references public.plans (id) on delete restrict,
  day_index integer not null check (day_index >= 1),
  started_at timestamptz not null,
  completed_at timestamptz
);

create index session_records_user_started_idx
  on public.session_records (user_id, started_at desc);
create index session_records_plan_idx
  on public.session_records (plan_id);

create table public.session_events (
  id text primary key check (length(id) = 26),
  user_id uuid not null references auth.users (id) on delete cascade,
  session_id text not null references public.session_records (id) on delete restrict,
  seq integer not null check (seq >= 0),
  type text not null check (
    type in (
      'setCompleted',
      'effortReported',
      'swapRequested',
      'shorten',
      'lowEnergy',
      'painReported',
      'sessionAbandoned'
    )
  ),
  payload jsonb not null,
  recorded_at timestamptz not null,
  unit_system_at_entry text not null
    check (unit_system_at_entry in ('metric', 'imperial')),
  unique (session_id, seq)
);

create index session_events_session_seq_idx
  on public.session_events (session_id, seq);
create index session_events_user_recorded_idx
  on public.session_events (user_id, recorded_at);

create function public.reject_session_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'session_events is append-only';
end;
$$;

create trigger session_events_no_update_or_delete
before update or delete on public.session_events
for each row execute function public.reject_session_event_mutation();

create table public.exercises (
  id text primary key,
  slug text not null,
  name text not null,
  movement_class text not null check (
    movement_class in (
      'compoundLower',
      'compoundUpperPush',
      'compoundUpperPull',
      'isolationLower',
      'isolationUpper',
      'core',
      'cardio'
    )
  ),
  block_role text not null check (
    block_role in (
      'warmUp',
      'lowerHinge',
      'lowerSquat',
      'upperPush',
      'upperPull',
      'gluteIsolation',
      'legIsolation',
      'armShoulderIsolation',
      'core',
      'finisherCardio'
    )
  ),
  metric_type text not null check (metric_type in ('loadReps', 'repsOnly', 'timed')),
  laterality text not null check (laterality in ('bilateral', 'perSide')),
  bw_contribution double precision not null
    check (bw_contribution between 0 and 1),
  load_step_override_kg double precision,
  resistance_equipment text not null check (
    resistance_equipment in (
      'barbell',
      'dumbbell',
      'machine',
      'assistedStack',
      'cable',
      'bodyweight'
    )
  ),
  support_equipment text not null check (
    support_equipment in (
      'none',
      'bench',
      'inclineBench',
      'rack',
      'mat',
      'box',
      'platform',
      'hipThrustPad'
    )
  ),
  target_muscles jsonb not null,
  primary_joint_actions jsonb not null,
  secondary_joint_actions jsonb not null,
  rom_rank integer not null check (rom_rank between 1 and 5),
  stability_rank integer not null check (stability_rank between 1 and 5),
  difficulty_tier text not null
    check (difficulty_tier in ('beginner', 'intermediate', 'advanced')),
  min_experience text not null check (
    min_experience in (
      'neverTrained',
      'returningAfterBreak',
      'trainsSometimes',
      'trainsRegularly'
    )
  ),
  intimidation_tier text not null
    check (intimidation_tier in ('low', 'moderate', 'high')),
  age_eligibility text not null
    check (age_eligibility in ('allAges', 'under60', 'under50')),
  safety_eligibility text not null
    check (safety_eligibility in ('selfGuided', 'instructorRequired')),
  machine_lean_ok boolean not null,
  seated_variant boolean not null,
  retired_at timestamptz,
  updated_at timestamptz not null default now()
);

create index exercises_block_role_idx on public.exercises (block_role);
create index exercises_updated_at_idx on public.exercises (updated_at);
create index exercises_retired_at_idx on public.exercises (retired_at);

create table public.exercise_copy (
  exercise_id text primary key references public.exercises (id) on delete restrict,
  setup_steps jsonb not null,
  should_feel text not null,
  stop_if text not null,
  find_it text not null,
  dos jsonb not null,
  donts jsonb not null,
  updated_at timestamptz not null default now()
);

create index exercise_copy_updated_at_idx
  on public.exercise_copy (updated_at);

create table public.swap_edges (
  from_id text not null references public.exercises (id) on delete restrict,
  to_id text not null references public.exercises (id) on delete restrict,
  reason text not null
    check (reason in ('busy', 'intimidating', 'uncomfortable', 'unavailable')),
  rank integer not null check (rank >= 0),
  tier integer not null check (tier between 1 and 3),
  updated_at timestamptz not null default now(),
  primary key (from_id, to_id, reason),
  unique (from_id, reason, rank)
);

create index swap_edges_from_reason_rank_idx
  on public.swap_edges (from_id, reason, rank);
create index swap_edges_updated_at_idx on public.swap_edges (updated_at);

create table public.user_exercise_prefs (
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_id text not null references public.exercises (id) on delete restrict,
  excluded boolean not null,
  source text not null check (source in ('pain', 'user')),
  updated_at timestamptz not null default now(),
  primary key (user_id, exercise_id, source)
);

create index user_exercise_prefs_user_updated_idx
  on public.user_exercise_prefs (user_id, updated_at);

create table public.version_gate (
  id boolean primary key default true check (id),
  recommended_version text not null,
  min_supported_version text not null,
  message text,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.plans enable row level security;
alter table public.session_records enable row level security;
alter table public.session_events enable row level security;
alter table public.user_exercise_prefs enable row level security;
alter table public.exercises enable row level security;
alter table public.exercise_copy enable row level security;
alter table public.swap_edges enable row level security;
alter table public.version_gate enable row level security;

create policy "profiles_owner_all"
on public.profiles for all to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "plans_owner_all"
on public.plans for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "session_records_owner_all"
on public.session_records for all to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1
    from public.plans plan
    where plan.id = plan_id
      and plan.user_id = (select auth.uid())
  )
);

create policy "session_events_owner_read"
on public.session_events for select to authenticated
using ((select auth.uid()) = user_id);

create policy "session_events_owner_insert"
on public.session_events for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1
    from public.session_records record
    where record.id = session_id
      and record.user_id = (select auth.uid())
  )
);

create policy "user_exercise_prefs_owner_all"
on public.user_exercise_prefs for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "exercises_public_read"
on public.exercises for select to anon, authenticated
using (true);

create policy "exercise_copy_public_read"
on public.exercise_copy for select to anon, authenticated
using (true);

create policy "swap_edges_public_read"
on public.swap_edges for select to anon, authenticated
using (true);

create policy "version_gate_public_read"
on public.version_gate for select to anon, authenticated
using (true);
