-- Nordlicht Slots: kostenloses Spiel mit virtuellen Demo-Credits.
-- Supabase Dashboard -> SQL Editor -> New query -> gesamten Inhalt ausführen.
-- Dieses Schema unterstützt KEINE Echtgeld-Einzahlungen oder Auszahlungen.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  balance bigint not null default 1000 check (balance >= 0),
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create or replace function public.is_slot_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false);
$$;

revoke all on function public.is_slot_admin() from public;
grant execute on function public.is_slot_admin() to authenticated;

drop policy if exists "Users can read their own profile; admins can read profiles" on public.profiles;
create policy "Users can read their own profile; admins can read profiles"
  on public.profiles for select to authenticated
  using (auth.uid() = id or public.is_slot_admin());

-- Clients cannot insert or change balances/admin flags directly. Updates happen only through RPCs.
revoke insert, update, delete on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;

create or replace function public.slot_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_slot_signup on auth.users;
create trigger on_slot_signup
  after insert on auth.users
  for each row execute function public.slot_new_user();

-- Idempotent backfill for accounts that existed before this SQL was run.
insert into public.profiles (id, email)
select id, email from auth.users
on conflict (id) do nothing;

-- Fixed, public symbol weights and payout multipliers. There is deliberately no admin odds control.
create or replace function public.slot_pick()
returns integer
language plpgsql
volatile
set search_path = public
as $$
declare r double precision := random() * 100;
begin
  return case when r < 30 then 0 when r < 55 then 1 when r < 75 then 2
              when r < 87 then 3 when r < 95 then 4 else 5 end;
end;
$$;

create or replace function public.spin(p_bet integer)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_balance bigint;
  v_grid integer[] := array[]::integer[];
  v_win bigint := 0;
  v_multipliers integer[] := array[2,3,5,10,20,50];
  v_lines integer[][] := array[[1,2,3],[4,5,6],[7,8,9],[1,5,9],[7,5,3]];
  i integer;
begin
  if v_uid is null then raise exception 'Bitte anmelden.'; end if;
  if p_bet not in (1,2,5,10,20,50) then raise exception 'Ungültiger Einsatz.'; end if;

  select balance into v_balance from public.profiles where id = v_uid for update;
  if not found then raise exception 'Profil fehlt. Bitte SQL-Setup prüfen.'; end if;
  if v_balance < p_bet then raise exception 'Guthaben zu niedrig.'; end if;

  for i in 1..9 loop v_grid := array_append(v_grid, public.slot_pick()); end loop;
  for i in 1..5 loop
    if v_grid[v_lines[i][1]] = v_grid[v_lines[i][2]]
       and v_grid[v_lines[i][2]] = v_grid[v_lines[i][3]] then
      v_win := v_win + p_bet * v_multipliers[v_grid[v_lines[i][1]] + 1];
    end if;
  end loop;

  update public.profiles set balance = balance - p_bet + v_win
  where id = v_uid returning balance into v_balance;
  return json_build_object('grid', v_grid, 'win', v_win, 'balance', v_balance);
end;
$$;

create or replace function public.admin_add_demo_credits(p_email text, p_amount integer)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare v_balance bigint;
begin
  if auth.uid() is null or not public.is_slot_admin() then raise exception 'Nur Admin.'; end if;
  if p_amount < 1 or p_amount > 100000 then raise exception 'Betrag muss zwischen 1 und 100000 Credits liegen.'; end if;
  update public.profiles
    set balance = balance + p_amount
    where lower(email) = lower(trim(p_email))
    returning balance into v_balance;
  if v_balance is null then raise exception 'Nutzer nicht gefunden.'; end if;
  return v_balance;
end;
$$;

revoke all on function public.spin(integer) from public;
grant execute on function public.spin(integer) to authenticated;
revoke all on function public.admin_add_demo_credits(text, integer) from public;
grant execute on function public.admin_add_demo_credits(text, integer) to authenticated;

-- ADMIN EINRICHTEN:
-- 1) Erst selbst über die Website ein Konto anlegen und die E-Mail bestätigen.
-- 2) Diese Zeile separat im SQL Editor ausführen (E-Mail bei Bedarf ändern):
-- update public.profiles set is_admin = true where lower(email) = lower('simon@navtool.de');
