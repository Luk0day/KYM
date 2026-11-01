-- B04 · Schema inicial do app (PostgreSQL / Supabase)
-- Perfis: tecnico, gestor, lojista

create extension if not exists pgcrypto;

-- ============ Tipos ============
create type user_role as enum ('tecnico', 'gestor', 'lojista');
create type order_type as enum ('preventiva', 'corretiva');
create type order_status as enum ('aberta', 'agendada', 'em_andamento', 'concluida', 'cancelada');
create type photo_kind as enum ('chamado', 'antes', 'depois');

-- ============ Tabelas ============
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role user_role not null default 'tecnico',
  phone text,
  created_at timestamptz not null default now()
);

create table stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text unique,
  address text,
  city text,
  latitude double precision,
  longitude double precision,
  qr_token uuid not null unique default gen_random_uuid(), -- QR Code da loja (check-in/out)
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table store_assignments (
  store_id uuid not null references stores(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (store_id, user_id)
);

create table equipment (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  name text not null,
  category text,
  brand text,
  model text,
  serial_number text,
  qr_token uuid not null unique default gen_random_uuid(), -- QR Code do equipamento
  status text not null default 'operando',
  installed_at date,
  notes text,
  created_at timestamptz not null default now()
);

create table maintenance_orders (
  id uuid primary key default gen_random_uuid(),
  equipment_id uuid not null references equipment(id) on delete cascade,
  store_id uuid not null references stores(id) on delete cascade,
  type order_type not null,
  status order_status not null default 'aberta',
  description text,
  notes text,
  scheduled_for date,
  opened_by uuid references profiles(id),
  assigned_to uuid references profiles(id),
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table checklist_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references maintenance_orders(id) on delete cascade,
  description text not null,
  done boolean not null default false,
  position int not null default 0
);

create table photos (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references maintenance_orders(id) on delete cascade,
  storage_path text not null,
  kind photo_kind not null default 'depois',
  taken_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);

create table signatures (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references maintenance_orders(id) on delete cascade,
  signer_id uuid references profiles(id),
  signer_name text not null,
  storage_path text not null,
  signed_at timestamptz not null default now()
);

create table visits (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  technician_id uuid not null references profiles(id),
  checked_in_at timestamptz not null default now(),
  checked_out_at timestamptz
);

-- ============ Índices ============
create index on store_assignments (user_id);
create index on equipment (store_id);
create index on maintenance_orders (store_id, status);
create index on maintenance_orders (equipment_id);
create index on maintenance_orders (assigned_to);
create index on checklist_items (order_id);
create index on photos (order_id);
create index on visits (store_id, technician_id);

-- ============ Triggers ============
create function set_updated_at() returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger maintenance_orders_updated_at
  before update on maintenance_orders
  for each row execute function set_updated_at();

-- cria o perfil automaticamente quando alguém se cadastra
create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============ Funções de apoio para RLS ============
create function is_gestor() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'gestor');
$$;

create function has_store_access(p_store uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_gestor() or exists (
    select 1 from store_assignments where store_id = p_store and user_id = auth.uid()
  );
$$;

create function has_order_access(p_order uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from maintenance_orders o where o.id = p_order and has_store_access(o.store_id)
  );
$$;

-- ============ RLS ============
alter table profiles          enable row level security;
alter table stores            enable row level security;
alter table store_assignments enable row level security;
alter table equipment         enable row level security;
alter table maintenance_orders enable row level security;
alter table checklist_items   enable row level security;
alter table photos            enable row level security;
alter table signatures        enable row level security;
alter table visits            enable row level security;

-- profiles: o usuário nunca altera o próprio papel
create policy profiles_select on profiles for select to authenticated
  using (id = auth.uid() or is_gestor());
create policy profiles_update_own on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_gestor_all on profiles for all to authenticated
  using (is_gestor()) with check (is_gestor());
revoke update on profiles from authenticated;
grant update (full_name, phone) on profiles to authenticated;

-- stores
create policy stores_select on stores for select to authenticated
  using (has_store_access(id));
create policy stores_gestor_write on stores for all to authenticated
  using (is_gestor()) with check (is_gestor());

-- store_assignments
create policy assignments_select on store_assignments for select to authenticated
  using (user_id = auth.uid() or is_gestor());
create policy assignments_gestor_write on store_assignments for all to authenticated
  using (is_gestor()) with check (is_gestor());

-- equipment
create policy equipment_select on equipment for select to authenticated
  using (has_store_access(store_id));
create policy equipment_gestor_write on equipment for all to authenticated
  using (is_gestor()) with check (is_gestor());

-- maintenance_orders
create policy orders_select on maintenance_orders for select to authenticated
  using (has_store_access(store_id));
create policy orders_insert on maintenance_orders for insert to authenticated
  with check (
    has_store_access(store_id)
    and (type = 'corretiva' or is_gestor() or assigned_to = auth.uid())
  );
create policy orders_update on maintenance_orders for update to authenticated
  using (is_gestor() or assigned_to = auth.uid())
  with check (is_gestor() or assigned_to = auth.uid());
create policy orders_gestor_delete on maintenance_orders for delete to authenticated
  using (is_gestor());

-- tabelas filhas da ordem
create policy checklist_select on checklist_items for select to authenticated
  using (has_order_access(order_id));
create policy checklist_write on checklist_items for all to authenticated
  using (has_order_access(order_id)) with check (has_order_access(order_id));

create policy photos_select on photos for select to authenticated
  using (has_order_access(order_id));
create policy photos_insert on photos for insert to authenticated
  with check (has_order_access(order_id) and created_by = auth.uid());

create policy signatures_select on signatures for select to authenticated
  using (has_order_access(order_id));
create policy signatures_insert on signatures for insert to authenticated
  with check (has_order_access(order_id));

-- visits
create policy visits_select on visits for select to authenticated
  using (technician_id = auth.uid() or is_gestor());
create policy visits_insert on visits for insert to authenticated
  with check (technician_id = auth.uid() and has_store_access(store_id));
create policy visits_update on visits for update to authenticated
  using (technician_id = auth.uid()) with check (technician_id = auth.uid());
