-- ============================================================
-- PlanIT — Supabase schema v1 (habit/deed tracker)
-- Run this in the Supabase SQL Editor on a fresh project.
-- ============================================================

-- ---------- Categories (Today screen sections) ----------
create table if not exists public.categories (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  icon       text not null default 'star',
  color      text not null default '#1B6CFF',
  sort_order int  not null default 0,
  created_at timestamptz not null default now()
);

-- ---------- Deeds (recurring items) ----------
create table if not exists public.deeds (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  category_id      uuid references public.categories(id) on delete set null,
  parent_id        uuid references public.deeds(id) on delete cascade,
  name             text not null,
  icon             text,
  frequency_type   text not null default 'daily'
                     check (frequency_type in ('daily','weekdays','times_per_week','times_per_month')),
  weekdays         smallint[],                    -- 1=Mon .. 7=Sun (for 'weekdays')
  times_per_period smallint,                      -- for times_per_week / times_per_month
  goal             smallint,
  goal_period      text check (goal_period in ('week','month')),
  reasons_enabled  boolean not null default false,
  reminder_time    time,
  sort_order       int  not null default 0,
  archived_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------- Logs (one per deed per day) ----------
create table if not exists public.deed_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  deed_id    uuid not null references public.deeds(id) on delete cascade,
  date       date not null,
  status     text not null check (status in ('done','late','skipped')),
  reason     text,
  logged_at  timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (deed_id, date)
);

-- ---------- Indexes ----------
create index if not exists categories_user_idx on public.categories (user_id, sort_order);
create index if not exists deeds_user_idx      on public.deeds (user_id, archived_at);
create index if not exists deeds_category_idx  on public.deeds (category_id);
create index if not exists logs_user_date_idx  on public.deed_logs (user_id, date);
create index if not exists logs_deed_idx       on public.deed_logs (deed_id);

-- ---------- updated_at triggers ----------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists deeds_touch on public.deeds;
create trigger deeds_touch before update on public.deeds
  for each row execute function public.touch_updated_at();

drop trigger if exists logs_touch on public.deed_logs;
create trigger logs_touch before update on public.deed_logs
  for each row execute function public.touch_updated_at();

-- ---------- Row Level Security ----------
alter table public.categories enable row level security;
alter table public.deeds      enable row level security;
alter table public.deed_logs  enable row level security;

drop policy if exists "owner all" on public.categories;
create policy "owner all" on public.categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "owner all" on public.deeds;
create policy "owner all" on public.deeds
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "owner all" on public.deed_logs;
create policy "owner all" on public.deed_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- Seed new users with starter content ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  c_health uuid;
  c_learning uuid;
  c_work uuid;
  c_social uuid;
begin
  insert into public.categories (user_id, name, icon, color, sort_order)
  values (new.id, 'Health',  'fitness_center', '#22C55E', 0) returning id into c_health;
  insert into public.categories (user_id, name, icon, color, sort_order)
  values (new.id, 'Learning','menu_book',      '#3B82F6', 1) returning id into c_learning;
  insert into public.categories (user_id, name, icon, color, sort_order)
  values (new.id, 'Work',    'work',           '#F59E0B', 2) returning id into c_work;
  insert into public.categories (user_id, name, icon, color, sort_order)
  values (new.id, 'Social',  'groups',         '#EC4899', 3) returning id into c_social;

  insert into public.deeds (user_id, category_id, name, frequency_type, weekdays, reminder_time)
  values (new.id, c_health,   'Exercise 20 min', 'weekdays', '{1,2,3,4,5}', '06:30'),
         (new.id, c_learning, 'Read 20 pages',   'daily',    null,            null),
         (new.id, c_work,     'Plan tomorrow',   'daily',    null,            '21:00');

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Realtime ----------
alter publication supabase_realtime add table public.deeds;
alter publication supabase_realtime add table public.deed_logs;
alter publication supabase_realtime add table public.categories;