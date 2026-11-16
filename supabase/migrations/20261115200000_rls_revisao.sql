-- B05 · Revisão da RLS (pontos levantados na revisão do PR)
--
-- A migration 20261115100000 já foi aplicada e não é editada. Esta fecha o
-- que a revisão encontrou:
--
--  1. maintenance_orders (insert): o gestor podia gravar opened_by de outra
--     pessoa. Agora opened_by é sempre quem insere, para todos os perfis.
--  2. maintenance_orders (insert): o lojista abria corretiva já com status
--     avançado ou atribuída a outro técnico. Agora quem não é gestor só abre
--     com status aberta (o técnico também agendada, se atribuída a ele), sem
--     datas de início ou conclusão, e só atribui a si mesmo.
--  3. maintenance_orders (insert): dava para usar o equipamento de outra
--     loja. Agora o equipamento precisa ser da loja da ordem.
--  4. maintenance_orders (update): o técnico mudava loja ou equipamento da
--     própria ordem (até para loja sem acesso). Agora um trigger impede quem
--     não é gestor de mudar loja, equipamento, tipo, responsável, autor e
--     data; e a policy exige acesso à loja.
--  5. signatures (insert): não validava o arquivo nem o signatário. Agora o
--     caminho é signatures/<ordem>.png e o signatário, se informado, é
--     alguém da loja da ordem.
--  6. photos (insert): o caminho não precisava bater com a ordem. Agora é
--     orders/<ordem>/<arquivo>.
--  7. Storage (insert): o lojista enviava qualquer arquivo em orders/<ordem>/,
--     porque o bucket não sabe o kind. Agora quem não é gestor só envia um
--     arquivo que já tenha o registro em photos criado por ele (o app grava
--     a linha em photos antes do upload), então a regra do kind vale também
--     no bucket.
--  8. Storage (update): o técnico que perdeu a atribuição ainda atualizava os
--     próprios arquivos. Agora o autor também precisa continuar com acesso à
--     ordem (e, na assinatura, continuar atribuído).

create or replace function equipment_in_store(p_equipment uuid, p_store uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from equipment where id = p_equipment and store_id = p_store
  );
$$;

create or replace function is_order_store_member(p_user uuid, p_order uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from maintenance_orders o
    join store_assignments a on a.store_id = o.store_id
    where o.id = p_order and a.user_id = p_user
  );
$$;

create or replace function has_own_photo_record(p_path text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from photos where storage_path = p_path and created_by = auth.uid()
  );
$$;

drop policy if exists orders_insert on maintenance_orders;
create policy orders_insert on maintenance_orders for insert to authenticated
  with check (
    opened_by = auth.uid()
    and equipment_in_store(equipment_id, store_id)
    and (
      is_gestor()
      or (
        has_store_access(store_id)
        and started_at is null
        and completed_at is null
        and (
          (
            type = 'corretiva'
            and status = 'aberta'
            and (
              assigned_to is null
              or (current_user_role() = 'tecnico' and assigned_to = auth.uid())
            )
          )
          or (
            current_user_role() = 'tecnico'
            and assigned_to = auth.uid()
            and status in ('aberta', 'agendada')
          )
        )
      )
    )
  );

drop policy if exists orders_update on maintenance_orders;
create policy orders_update on maintenance_orders for update to authenticated
  using (
    is_gestor()
    or (
      current_user_role() = 'tecnico'
      and assigned_to = auth.uid()
      and has_store_access(store_id)
    )
  )
  with check (
    is_gestor()
    or (
      current_user_role() = 'tecnico'
      and assigned_to = auth.uid()
      and has_store_access(store_id)
    )
  );

-- Sem usuário logado (painel, sincronização pelo servidor) o trigger não
-- bloqueia; a RLS não se aplica a esses papéis.
create or replace function guard_order_update() returns trigger
language plpgsql set search_path = public as $$
begin
  if auth.uid() is null or is_gestor() then
    return new;
  end if;

  if new.store_id is distinct from old.store_id
     or new.equipment_id is distinct from old.equipment_id
     or new.type is distinct from old.type
     or new.opened_by is distinct from old.opened_by
     or new.assigned_to is distinct from old.assigned_to
     or new.scheduled_for is distinct from old.scheduled_for
     or new.created_at is distinct from old.created_at then
    raise exception
      'Somente o gestor altera loja, equipamento, tipo, responsável, autor ou data da ordem.'
      using errcode = '42501';
  end if;

  return new;
end $$;

drop trigger if exists maintenance_orders_guard_update on maintenance_orders;
create trigger maintenance_orders_guard_update
  before update on maintenance_orders
  for each row execute function guard_order_update();

drop policy if exists signatures_insert on signatures;
create policy signatures_insert on signatures for insert to authenticated
  with check (
    can_write_order_details(order_id)
    and storage_path = 'signatures/' || order_id || '.png'
    and (signer_id is null or is_order_store_member(signer_id, order_id))
  );

drop policy if exists photos_insert on photos;
create policy photos_insert on photos for insert to authenticated
  with check (
    has_order_access(order_id)
    and created_by = auth.uid()
    and (current_user_role() <> 'lojista' or kind = 'chamado')
    and storage_path ~ ('^orders/' || order_id || '/[^/]+$')
  );

drop policy if exists order_files_insert on storage.objects;
create policy order_files_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'order-files'
    and (
      (
        name like 'orders/%'
        and has_order_access(storage_order_id(name))
        and (is_gestor() or has_own_photo_record(name))
      )
      or (
        name like 'signatures/%'
        and can_write_order_details(storage_order_id(name))
      )
    )
  );

drop policy if exists order_files_update on storage.objects;
create policy order_files_update on storage.objects for update to authenticated
  using (
    bucket_id = 'order-files'
    and (
      is_gestor()
      or (
        owner_id = auth.uid()::text
        and (
          (name like 'orders/%' and has_order_access(storage_order_id(name)))
          or (
            name like 'signatures/%'
            and can_write_order_details(storage_order_id(name))
          )
        )
      )
    )
  )
  with check (
    bucket_id = 'order-files'
    and storage_order_id(name) is not null
    and (
      is_gestor()
      or (
        owner_id = auth.uid()::text
        and (
          (name like 'orders/%' and has_order_access(storage_order_id(name)))
          or (
            name like 'signatures/%'
            and can_write_order_details(storage_order_id(name))
          )
        )
      )
    )
  );
