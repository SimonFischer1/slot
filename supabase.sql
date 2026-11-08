-- Im Supabase-Dashboard: SQL Editor -> New query -> alles einfügen -> Run
-- (am besten in einem NEUEN Supabase-Projekt, getrennt von NavTool)

create table if not exists profiles(
  id uuid primary key references auth.users on delete cascade,
  email text,
  balance numeric not null default 0,
  is_admin boolean not null default false
);
create table if not exists settings(
  id int primary key default 1 check (id = 1),
  luck int not null default 100   -- 100 = Standard, höher = mehr Gewinne, niedriger = weniger
);
insert into settings values (1, 100) on conflict do nothing;

alter table profiles enable row level security;
alter table settings enable row level security;

create or replace function is_admin() returns boolean language sql security definer set search_path = public as
$$ select coalesce((select is_admin from profiles where id = auth.uid()), false) $$;

drop policy if exists "profil lesen" on profiles;
create policy "profil lesen" on profiles for select using (auth.uid() = id or is_admin());
drop policy if exists "settings lesen" on settings;
create policy "settings lesen" on settings for select using (is_admin());
-- Es gibt absichtlich KEINE Update-Policies: Guthaben ändert sich nur über die Funktionen unten.

create or replace function new_user() returns trigger language plpgsql security definer set search_path = public as
$$ begin insert into profiles(id, email) values (new.id, new.email); return new; end $$;
drop trigger if exists on_signup on auth.users;
create trigger on_signup after insert on auth.users for each row execute function new_user();

-- Symbole 0..5 (🍒🍋🍇🔔⭐7️⃣), Gewichte 30/25/20/12/8/5
create or replace function pick() returns int language plpgsql as $$
declare r float := random() * 100;
begin
  return case when r < 30 then 0 when r < 55 then 1 when r < 75 then 2
              when r < 87 then 3 when r < 95 then 4 else 5 end;
end $$;

create or replace function roll() returns int[] language plpgsql as $$
declare g int[] := array[]::int[]; i int;
begin
  for i in 1..9 loop g := g || pick(); end loop;
  return g;
end $$;

-- 5 Gewinnlinien (3 Reihen + 2 Diagonalen), drei gleiche Symbole = Einsatz x Faktor
create or replace function calc(g int[], bet numeric) returns numeric language plpgsql as $$
declare
  m numeric[] := array[2,3,5,10,20,50];
  ls int[][] := array[[1,2,3],[4,5,6],[7,8,9],[1,5,9],[7,5,3]];
  w numeric := 0; i int;
begin
  for i in 1..5 loop
    if g[ls[i][1]] = g[ls[i][2]] and g[ls[i][2]] = g[ls[i][3]] then
      w := w + bet * m[g[ls[i][1]] + 1];
    end if;
  end loop;
  return w;
end $$;

create or replace function spin(p_bet numeric) returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); bal numeric; g int[]; w numeric; lk int;
begin
  if uid is null then raise exception 'Nicht angemeldet'; end if;
  if p_bet not in (1,2,5,10,20,50) then raise exception 'Ungültiger Einsatz'; end if;
  select balance into bal from profiles where id = uid for update;
  if bal < p_bet then raise exception 'Guthaben zu niedrig'; end if;
  select luck into lk from settings where id = 1;
  g := roll(); w := calc(g, p_bet);
  if w = 0 and lk > 100 and random() < (lk - 100) / 100.0 then
    g := roll(); w := calc(g, p_bet);
  elsif w > 0 and lk < 100 and random() < (100 - lk) / 100.0 then
    g := roll(); w := calc(g, p_bet);
  end if;
  update profiles set balance = balance - p_bet + w where id = uid returning balance into bal;
  return json_build_object('grid', g, 'win', w, 'balance', bal);
end $$;

create or replace function admin_add(p_email text, p_amount numeric) returns numeric language plpgsql security definer set search_path = public as $$
declare b numeric;
begin
  if not is_admin() then raise exception 'Nur Admin'; end if;
  update profiles set balance = greatest(0, balance + p_amount) where lower(email) = lower(p_email) returning balance into b;
  if b is null then raise exception 'Nutzer nicht gefunden'; end if;
  return b;
end $$;

create or replace function admin_luck(p_luck int) returns int language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Nur Admin'; end if;
  update settings set luck = least(300, greatest(10, p_luck)) where id = 1;
  return p_luck;
end $$;

-- Profile für schon vorhandene Konten nachtragen
insert into profiles(id,email) select id,email from auth.users on conflict do nothing;

-- ADMIN: erst im Spiel mit simon@navtool.de registrieren, dann DIESE Zeile einzeln ausführen:
update profiles set is_admin = true where email = 'simon@navtool.de';
