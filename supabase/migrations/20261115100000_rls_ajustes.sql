-- B05 · Ajustes de RLS por perfil e Storage das ordens
--
-- A migration inicial (20261029000000) já foi aplicada e não é editada. Esta
-- migration fecha as brechas encontradas na revisão, conferidas contra a
-- matriz da issue B05:
--
--  1. checklist_items: qualquer usuário com acesso à loja (inclusive o lojista)
--     escrevia no checklist. Agora só o gestor ou o técnico atribuído à ordem.
--  2. signatures: mesma brecha no insert. Agora só o gestor ou o técnico
--     atribuído à ordem.
--  3. photos: o lojista inseria qualquer tipo de foto. Agora o lojista só
--     insere foto de chamado (kind = 'chamado').
--  4. maintenance_orders (insert): o lojista podia criar preventiva se
--     preenchesse assigned_to com o próprio id, e qualquer um podia gravar
--     opened_by de outra pessoa. Agora o lojista só abre corretiva, só o
--     técnico cria preventiva atribuída a si e opened_by é sempre quem insere
--     (com default auth.uid(), para o app não precisar enviar).
--  5. maintenance_orders (update): um lojista com assigned_to = ele mesmo
--     conseguia alterar a ordem. Agora só o gestor ou o técnico atribuído.
--  6. visits (insert): o lojista conseguia registrar visita em nome próprio.
--     Agora só o técnico (check-in), e o gestor apenas lê.
--  7. Storage: o bucket das fotos e assinaturas não existia. Cria o bucket
--     privado `order-files` com as políticas por ordem:
--       orders/<orderId>/<arquivo>   fotos
--       signatures/<orderId>.png     assinatura
--
-- Decisões (B05): o lojista não altera o próprio chamado (quem cancela é o
-- gestor) e o técnico não altera o status do equipamento (continua do gestor).

create or replace function current_user_role() returns user_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid();
$$;

create or replace function is_order_assignee(p_order uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from maintenance_orders o
    where o.id = p_order
      and o.assigned_to = auth.uid()
      and has_store_access(o.store_id)
  );
$$;

create or replace function can_write_order_details(p_order uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_gestor()
      or (current_user_role() = 'tecnico' and is_order_assignee(p_order));
$$;

-- Extrai o id da ordem do caminho no bucket `order-files`. Devolve null para
-- caminhos fora do padrão (em vez de erro de conversão para uuid).
create or replace function storage_order_id(p_name text) returns uuid
language plpgsql immutable set search_path = public as $$
declare
  v_parts text[] := string_to_array(p_name, '/');
  v_id text;
begin
  if array_length(v_parts, 1) = 3 and v_parts[1] = 'orders' then
    v_id := v_parts[2];
  elsif array_length(v_parts, 1) = 2 and v_parts[1] = 'signatures'
        and v_parts[2] like '%.png' then
    v_id := left(v_parts[2], length(v_parts[2]) - 4);
  else
    return null;
  end if;

  if v_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return v_id::uuid;
  end if;
  return null;
end $$;

alter table maintenance_orders alter column opened_by set default auth.uid();

drop policy if exists orders_insert on maintenance_orders;
create policy orders_insert on maintenance_orders for insert to authenticated
  with check (
    is_gestor()
    or (
      has_store_access(store_id)
      and opened_by = auth.uid()
      and (
        type = 'corretiva'
        or (current_user_role() = 'tecnico' and assigned_to = auth.uid())
      )
    )
  );

drop policy if exists orders_update on maintenance_orders;
create policy orders_update on maintenance_orders for update to authenticated
  using (
    is_gestor()
    or (current_user_role() = 'tecnico' and assigned_to = auth.uid())
  )
  with check (
    is_gestor()
    or (current_user_role() = 'tecnico' and assigned_to = auth.uid())
  );

drop policy if exists checklist_write on checklist_items;
create policy checklist_write on checklist_items for all to authenticated
  using (can_write_order_details(order_id))
  with check (can_write_order_details(order_id));

drop policy if exists signatures_insert on signatures;
create policy signatures_insert on signatures for insert to authenticated
  with check (can_write_order_details(order_id));

drop policy if exists photos_insert on photos;
create policy photos_insert on photos for insert to authenticated
  with check (
    has_order_access(order_id)
    and created_by = auth.uid()
    and (current_user_role() <> 'lojista' or kind = 'chamado')
  );

drop policy if exists visits_insert on visits;
create policy visits_insert on visits for insert to authenticated
  with check (
    current_user_role() = 'tecnico'
    and technician_id = auth.uid()
    and has_store_access(store_id)
  );

drop policy if exists visits_update on visits;
create policy visits_update on visits for update to authenticated
  using (current_user_role() = 'tecnico' and technician_id = auth.uid())
  with check (current_user_role() = 'tecnico' and technician_id = auth.uid());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('order-files', 'order-files', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists order_files_select on storage.objects;
create policy order_files_select on storage.objects for select to authenticated
  using (
    bucket_id = 'order-files'
    and has_order_access(storage_order_id(name))
  );

drop policy if exists order_files_insert on storage.objects;
create policy order_files_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'order-files'
    and (
      (name like 'orders/%' and has_order_access(storage_order_id(name)))
      or (name like 'signatures/%'
          and can_write_order_details(storage_order_id(name)))
    )
  );

drop policy if exists order_files_update on storage.objects;
create policy order_files_update on storage.objects for update to authenticated
  using (
    bucket_id = 'order-files'
    and (is_gestor() or owner_id = auth.uid()::text)
  )
  with check (
    bucket_id = 'order-files'
    and storage_order_id(name) is not null
    and (is_gestor() or owner_id = auth.uid()::text)
  );

drop policy if exists order_files_delete on storage.objects;
create policy order_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'order-files' and is_gestor());
