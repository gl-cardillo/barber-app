create type public.user_role as enum ('customer', 'barber');
create type public.booking_status as enum ('booked', 'cancelled', 'completed', 'no_show');

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text,
  email       text,
  phone       text,
  role        public.user_role not null default 'customer',
  created_at  timestamptz not null default now()
);

create table public.settings (
  id                         boolean primary key default true check (id),
  slot_minutes               int  not null default 30 check (slot_minutes between 5 and 240),
  booking_window_days        int  not null default 14 check (booking_window_days between 1 and 365),
  min_notice_minutes         int  not null default 60 check (min_notice_minutes >= 0),
  cancel_notice_minutes      int  not null default 60 check (cancel_notice_minutes >= 0),
  max_upcoming_per_customer  int  not null default 2  check (max_upcoming_per_customer >= 1),
  timezone                   text not null default 'Europe/Rome'
);

create table public.working_hours (
  id          uuid primary key default gen_random_uuid(),
  weekday     smallint not null check (weekday between 0 and 6), -- 0 = Sunday
  start_time  time not null,
  end_time    time not null,
  check (start_time < end_time)
);

create table public.time_off (
  id          uuid primary key default gen_random_uuid(),
  starts_at   timestamptz not null,
  ends_at     timestamptz not null,
  reason      text,
  check (starts_at < ends_at)
);

create table public.bookings (
  id           uuid primary key default gen_random_uuid(),
  customer_id  uuid references public.profiles (id) on delete cascade,
  guest_name   text,
  guest_phone  text,
  starts_at    timestamptz not null,
  ends_at      timestamptz not null,
  status       public.booking_status not null default 'booked',
  notes        text,
  created_at   timestamptz not null default now(),
  check (starts_at < ends_at),
  check (customer_id is not null or guest_name is not null),
  constraint bookings_no_overlap
    exclude using gist (tstzrange(starts_at, ends_at) with &&)
    where (status = 'booked')
);

create index bookings_customer_id_idx on public.bookings (customer_id);
create index bookings_starts_at_idx   on public.bookings (starts_at);


create function public.is_barber()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'barber'
  );
$$;

create function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

insert into public.profiles (id, full_name, email)
select id,
       coalesce(raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'name'),
       email
from auth.users
on conflict (id) do nothing;


alter table public.profiles      enable row level security;
alter table public.settings      enable row level security;
alter table public.working_hours enable row level security;
alter table public.time_off      enable row level security;
alter table public.bookings      enable row level security;

create policy "profiles: read own or barber" on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_barber());

create policy "profiles: update own" on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (full_name, phone) on public.profiles to authenticated;

create policy "settings: read" on public.settings
  for select to authenticated using (true);

create policy "settings: barber update" on public.settings
  for update to authenticated
  using (public.is_barber()) with check (public.is_barber());

create policy "working_hours: read" on public.working_hours
  for select to authenticated using (true);

create policy "working_hours: barber manage" on public.working_hours
  for all to authenticated
  using (public.is_barber()) with check (public.is_barber());

create policy "time_off: barber manage" on public.time_off
  for all to authenticated
  using (public.is_barber()) with check (public.is_barber());

create policy "bookings: read own or barber" on public.bookings
  for select to authenticated
  using (customer_id = auth.uid() or public.is_barber());

create policy "bookings: barber insert" on public.bookings
  for insert to authenticated with check (public.is_barber());

create policy "bookings: barber update" on public.bookings
  for update to authenticated
  using (public.is_barber()) with check (public.is_barber());

create policy "bookings: barber delete" on public.bookings
  for delete to authenticated using (public.is_barber());


create function public.get_available_slots(p_date date)
returns table (slot_start timestamptz, slot_end timestamptz)
language sql stable security definer set search_path = ''
as $$
  with s as (
    select * from public.settings where id
  ),
  candidates as (
    select (gs at time zone s.timezone)                                       as slot_start,
           (gs at time zone s.timezone) + make_interval(mins => s.slot_minutes) as slot_end
    from s
    join public.working_hours wh on wh.weekday = extract(dow from p_date)
    cross join lateral generate_series(
      p_date + wh.start_time,
      p_date + wh.end_time - make_interval(mins => s.slot_minutes),
      make_interval(mins => s.slot_minutes)
    ) as gs
  )
  select c.slot_start, c.slot_end
  from candidates c
  cross join s
  where c.slot_start >= now() + make_interval(mins => s.min_notice_minutes)
    and p_date <= (now() at time zone s.timezone)::date + s.booking_window_days
    and not exists (
      select 1 from public.bookings b
      where b.status = 'booked'
        and tstzrange(b.starts_at, b.ends_at) && tstzrange(c.slot_start, c.slot_end)
    )
    and not exists (
      select 1 from public.time_off t
      where tstzrange(t.starts_at, t.ends_at) && tstzrange(c.slot_start, c.slot_end)
    )
  order by c.slot_start;
$$;


create function public.book_slot(p_starts_at timestamptz, p_notes text default null)
returns public.bookings
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_settings public.settings;
  v_slot_end timestamptz;
  v_booking  public.bookings;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = v_uid and coalesce(trim(phone), '') <> ''
  ) then
    raise exception 'PHONE_REQUIRED';
  end if;

  select * into v_settings from public.settings where id;

  select a.slot_end into v_slot_end
  from public.get_available_slots((p_starts_at at time zone v_settings.timezone)::date) a
  where a.slot_start = p_starts_at;

  if v_slot_end is null then
    raise exception 'SLOT_UNAVAILABLE';
  end if;

  if (
    select count(*) from public.bookings
    where customer_id = v_uid and status = 'booked' and starts_at > now()
  ) >= v_settings.max_upcoming_per_customer then
    raise exception 'TOO_MANY_BOOKINGS';
  end if;

  insert into public.bookings (customer_id, starts_at, ends_at, notes)
  values (v_uid, p_starts_at, v_slot_end, p_notes)
  returning * into v_booking;

  return v_booking;
exception
  when exclusion_violation then
    raise exception 'SLOT_UNAVAILABLE';
end;
$$;

create function public.cancel_booking(p_booking_id uuid)
returns public.bookings
language plpgsql security definer set search_path = ''
as $$
declare
  v_notice  int;
  v_booking public.bookings;
begin
  select cancel_notice_minutes into v_notice from public.settings where id;

  select * into v_booking
  from public.bookings
  where id = p_booking_id and customer_id = auth.uid()
  for update;

  if not found then
    raise exception 'BOOKING_NOT_FOUND';
  end if;
  if v_booking.status <> 'booked' then
    raise exception 'BOOKING_NOT_ACTIVE';
  end if;
  if v_booking.starts_at < now() + make_interval(mins => v_notice) then
    raise exception 'TOO_LATE_TO_CHANGE';
  end if;

  update public.bookings set status = 'cancelled'
  where id = p_booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;

create function public.reschedule_booking(p_booking_id uuid, p_new_starts_at timestamptz)
returns public.bookings
language plpgsql security definer set search_path = ''
as $$
declare
  v_old public.bookings;
begin
  v_old := public.cancel_booking(p_booking_id);
  return public.book_slot(p_new_starts_at, v_old.notes);
end;
$$;


revoke execute on function public.handle_new_user()                          from public, anon, authenticated;
revoke execute on function public.get_available_slots(date)                  from public, anon;
revoke execute on function public.book_slot(timestamptz, text)               from public, anon;
revoke execute on function public.cancel_booking(uuid)                       from public, anon;
revoke execute on function public.reschedule_booking(uuid, timestamptz)      from public, anon;

grant execute on function public.get_available_slots(date)                   to authenticated;
grant execute on function public.book_slot(timestamptz, text)                to authenticated;
grant execute on function public.cancel_booking(uuid)                        to authenticated;
grant execute on function public.reschedule_booking(uuid, timestamptz)       to authenticated;


insert into public.settings (id, slot_minutes, booking_window_days)
values (true, 30, 14);

insert into public.working_hours (weekday, start_time, end_time)
select d, '09:00', '19:00'
from generate_series(2, 6) as d;
