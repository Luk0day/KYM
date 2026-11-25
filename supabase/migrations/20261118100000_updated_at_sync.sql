-- B20 · updated_at para a baixada incremental
--
-- O app baixa só o que mudou desde a última sincronização, filtrando por
-- updated_at. Na migration inicial só maintenance_orders tinha a coluna; esta
-- migration a adiciona nas demais tabelas sincronizadas, com o mesmo trigger
-- set_updated_at() (criado em 20261029000000).
--
-- Linhas que já existem recebem now() no momento em que a migration roda:
-- o primeiro pull de cada aparelho traz tudo de qualquer forma.
--
-- Os índices (updated_at, id) servem à paginação do app, que ordena por essas
-- duas colunas e continua de onde parou ("keyset"), em vez de usar offset.

alter table stores
  add column if not exists updated_at timestamptz not null default now();
alter table equipment
  add column if not exists updated_at timestamptz not null default now();
alter table checklist_items
  add column if not exists updated_at timestamptz not null default now();
alter table photos
  add column if not exists updated_at timestamptz not null default now();
alter table signatures
  add column if not exists updated_at timestamptz not null default now();
alter table visits
  add column if not exists updated_at timestamptz not null default now();

drop trigger if exists stores_updated_at on stores;
create trigger stores_updated_at
  before update on stores
  for each row execute function set_updated_at();

drop trigger if exists equipment_updated_at on equipment;
create trigger equipment_updated_at
  before update on equipment
  for each row execute function set_updated_at();

drop trigger if exists checklist_items_updated_at on checklist_items;
create trigger checklist_items_updated_at
  before update on checklist_items
  for each row execute function set_updated_at();

drop trigger if exists photos_updated_at on photos;
create trigger photos_updated_at
  before update on photos
  for each row execute function set_updated_at();

drop trigger if exists signatures_updated_at on signatures;
create trigger signatures_updated_at
  before update on signatures
  for each row execute function set_updated_at();

drop trigger if exists visits_updated_at on visits;
create trigger visits_updated_at
  before update on visits
  for each row execute function set_updated_at();

create index if not exists maintenance_orders_updated_at_idx
  on maintenance_orders (updated_at, id);
create index if not exists equipment_updated_at_idx
  on equipment (updated_at, id);
create index if not exists stores_updated_at_idx
  on stores (updated_at, id);
create index if not exists photos_updated_at_idx
  on photos (updated_at, id);
