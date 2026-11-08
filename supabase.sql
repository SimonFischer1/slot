-- Nordlicht Slots: kostenloses Spiel mit virtuellen Demo-Credits.
-- Im Supabase Dashboard -> SQL Editor -> New query -> gesamten Inhalt ausführen.
-- Für bestehende Installationen: Dieses Skript erneut vollständig ausführen (idempotente Migration).
-- Es gibt KEINE Echtgeld-Aufladung/Auszahlung und KEINE individuelle Gewinnchance.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  balance bigint not null default 1000 check (balance >= 0),
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists balance bigint not null default 1000;
alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles alter column balance set default 1000;
alter table public.profiles enable row level security;

create or replace function public.is_slot_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select coalesce((select p.is_admin from public.profiles p where p.id = (select auth.uid())), false); $$;
revoke all on function public.is_slot_admin() from public;
grant execute on function public.is_slot_admin() to authenticated;

drop policy if exists "Users can read their own profile; admins can read profiles" on public.profiles;
drop policy if exists "profile_read_self_or_admin" on public.profiles;
create policy "profile_read_self_or_admin" on public.profiles for select to authenticated
using ((select auth.uid()) = id or public.is_slot_admin());
revoke insert, update, delete on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;

create or replace function public.slot_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;
drop trigger if exists on_slot_signup on auth.users;
create trigger on_slot_signup after insert on auth.users for each row execute function public.slot_new_user();

-- Repairs profiles for accounts created before the trigger/schema was installed.
insert into public.profiles (id, email) select id, email from auth.users
on conflict (id) do update set email = excluded.email;

create or replace function public.get_slot_profile()
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid(); v_profile public.profiles%rowtype;
begin
  if v_uid is null then raise exception 'Bitte anmelden.'; end if;
  insert into public.profiles (id, email)
    select u.id, u.email from auth.users u where u.id = v_uid
    on conflict (id) do update set email = excluded.email;
  select * into v_profile from public.profiles where id = v_uid;
  return jsonb_build_object('email',v_profile.email,'balance',v_profile.balance,'is_admin',v_profile.is_admin);
end;
$$;

-- Public, fixed symbol distribution; no account-specific luck/odds controls.
create or replace function public.slot_pick()
returns integer language plpgsql volatile set search_path = ''
as $$
declare r double precision := random() * 100;
begin
 return case when r < 30 then 0 when r < 55 then 1 when r < 75 then 2 when r < 87 then 3 when r < 95 then 4 else 5 end;
end;
$$;

create or replace function public.spin(p_bet integer)
returns json language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid(); v_balance bigint; v_grid integer[] := array[]::integer[]; v_win bigint := 0;
  v_multipliers integer[] := array[2,3,5,10,20,50];
  v_lines integer[][] := array[[1,2,3],[4,5,6],[7,8,9],[1,5,9],[7,5,3]]; i integer;
begin
  if v_uid is null then raise exception 'Bitte anmelden.'; end if;
  if p_bet not in (1,2,5,10,20,50) then raise exception 'Ungültiger Einsatz.'; end if;
  -- Ensure old accounts have a profile, then lock it for an atomic spin.
  insert into public.profiles (id,email) select u.id,u.email from auth.users u where u.id=v_uid on conflict (id) do nothing;
  select balance into v_balance from public.profiles where id=v_uid for update;
  if not found then raise exception 'Profil fehlt. Bitte SQL-Setup prüfen.'; end if;
  if v_balance < p_bet then raise exception 'Guthaben zu niedrig.'; end if;
  for i in 1..9 loop v_grid := array_append(v_grid, public.slot_pick()); end loop;
  for i in 1..5 loop
    if v_grid[v_lines[i][1]]=v_grid[v_lines[i][2]] and v_grid[v_lines[i][2]]=v_grid[v_lines[i][3]] then
      v_win := v_win + p_bet * v_multipliers[v_grid[v_lines[i][1]]+1];
    end if;
  end loop;
  update public.profiles set balance=balance-p_bet+v_win where id=v_uid returning balance into v_balance;
  return json_build_object('grid',v_grid,'win',v_win,'balance',v_balance);
end;
$$;

-- Admin can add or subtract virtual credits. Negative balances are rejected by the table constraint.
create or replace function public.admin_add_demo_credits(p_email text,p_amount integer)
returns bigint language plpgsql security definer set search_path = ''
as $$
declare v_balance bigint;
begin
  if auth.uid() is null or not public.is_slot_admin() then raise exception 'Nur Admin.'; end if;
  if p_amount=0 or p_amount < -100000 or p_amount > 100000 then raise exception 'Betrag muss zwischen -100000 und 100000 liegen (außer 0).'; end if;
  update public.profiles set balance=balance+p_amount where lower(email)=lower(trim(p_email)) returning balance into v_balance;
  if v_balance is null then raise exception 'Nutzer nicht gefunden.'; end if;
  return v_balance;
end;
$$;

create or replace function public.admin_list_demo_profiles()
returns table(email text,balance numeric)
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_slot_admin() then raise exception 'Nur Admin.'; end if;
  return query select p.email,p.balance::numeric from public.profiles p order by p.created_at desc limit 200;
end;
$$;

revoke all on function public.get_slot_profile() from public;
grant execute on function public.get_slot_profile() to authenticated;
revoke all on function public.spin(integer) from public;
grant execute on function public.spin(integer) to authenticated;
revoke all on function public.admin_add_demo_credits(text,integer) from public;
grant execute on function public.admin_add_demo_credits(text,integer) to authenticated;
revoke all on function public.admin_list_demo_profiles() from public;
grant execute on function public.admin_list_demo_profiles() to authenticated;

-- ADMIN EINRICHTEN: Erst registrieren und E-Mail bestätigen, dann diese Zeile separat ausführen.
-- update public.profiles set is_admin=true where lower(email)=lower('simon@navtool.de');
