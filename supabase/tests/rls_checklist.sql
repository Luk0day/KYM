-- B05 · Roteiro de teste da RLS por perfil
--
-- Pré-requisitos: migrations aplicadas e supabase/seed.sql executado (com os
-- usuários tecnico, tecnico2, gestor e lojista @kym.test criados).
--
-- Como rodar: cole o arquivo inteiro no SQL Editor do Supabase e execute.
-- O bloco simula cada usuário trocando request.jwt.claims e o papel para
-- authenticated, e confere a matriz da issue. Cada regra tem a mensagem do
-- resultado esperado. Se uma falhar, o script para com FALHOU e a regra.
-- Se todas passarem, o resultado é RLS OK. As escritas de teste são
-- desfeitas no fim e nenhum dado fica no banco.
--
-- Escritas negadas pela RLS aparecem de dois jeitos:
--   insert -> erro 42501 (insufficient_privilege)
--   update/delete -> nenhuma linha afetada (a linha fica invisível)

do $$
declare
  v_tecnico  uuid;
  v_tecnico2 uuid;
  v_gestor   uuid;
  v_lojista  uuid;

  c_centro         constant uuid := '00000000-0000-4000-8000-0000000000a1';
  c_boa_viagem     constant uuid := '00000000-0000-4000-8000-0000000000a2';
  c_shopping       constant uuid := '00000000-0000-4000-8000-0000000000a3';
  c_eq_centro      constant uuid := '00000000-0000-4000-8000-0000000000e1';
  c_eq_boa_viagem  constant uuid := '00000000-0000-4000-8000-0000000000e5';
  c_eq_shopping    constant uuid := '00000000-0000-4000-8000-0000000000e9';
  c_ordem_lojista  constant uuid := '00000000-0000-4000-8000-0000000000f1';
  c_ordem_tecnico  constant uuid := '00000000-0000-4000-8000-0000000000f2';
  c_ordem_tecnico2 constant uuid := '00000000-0000-4000-8000-0000000000f4';

  n int;
  v_ok boolean;
begin
  select id into v_tecnico  from auth.users where email = 'tecnico@kym.test';
  select id into v_tecnico2 from auth.users where email = 'tecnico2@kym.test';
  select id into v_gestor   from auth.users where email = 'gestor@kym.test';
  select id into v_lojista  from auth.users where email = 'lojista@kym.test';

  if v_tecnico is null or v_tecnico2 is null or v_gestor is null or v_lojista is null then
    raise exception 'FALHOU: rode antes o supabase/seed.sql com os 4 usuários de teste.';
  end if;

  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_gestor, 'role', 'authenticated')::text, true);
    set local role authenticated;

    select count(*) into n from stores where id in (c_centro, c_boa_viagem, c_shopping);
    if n <> 3 then raise exception 'FALHOU: gestor vê % de 3 lojas', n; end if;

    select count(*) into n from maintenance_orders
     where id in (c_ordem_lojista, c_ordem_tecnico, c_ordem_tecnico2);
    if n <> 3 then raise exception 'FALHOU: gestor vê % de 3 ordens', n; end if;

    select count(*) into n from profiles
     where id in (v_tecnico, v_tecnico2, v_gestor, v_lojista);
    if n <> 4 then raise exception 'FALHOU: gestor vê % de 4 perfis', n; end if;

    update stores set address = address where id = c_shopping;
    get diagnostics n = row_count;
    if n <> 1 then raise exception 'FALHOU: gestor não alterou a loja'; end if;

    update maintenance_orders set notes = 'gestor' where id = c_ordem_tecnico2;
    get diagnostics n = row_count;
    if n <> 1 then raise exception 'FALHOU: gestor não alterou a ordem'; end if;

    insert into checklist_items (order_id, description) values (c_ordem_tecnico2, 'gestor');

    begin
      insert into maintenance_orders (equipment_id, store_id, type, opened_by)
      values (c_eq_centro, c_centro, 'corretiva', v_lojista);
      raise exception 'FALHOU: gestor abriu ordem em nome de outra pessoa';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into maintenance_orders (equipment_id, store_id, type)
      values (c_eq_shopping, c_centro, 'corretiva');
      raise exception 'FALHOU: ordem aceitou equipamento de outra loja';
    exception when insufficient_privilege then null;
    end;

    insert into storage.objects (bucket_id, name, owner_id)
    values ('order-files', 'orders/' || c_ordem_tecnico2 || '/gestor.jpg', v_gestor::text);
    select count(*) into n from storage.objects
     where bucket_id = 'order-files' and name = 'orders/' || c_ordem_tecnico2 || '/gestor.jpg';
    if n <> 1 then raise exception 'FALHOU: gestor não vê o arquivo que enviou'; end if;
    update storage.objects set metadata = '{}'::jsonb
     where bucket_id = 'order-files' and name = 'orders/' || c_ordem_tecnico2 || '/gestor.jpg';
    get diagnostics n = row_count;
    if n <> 1 then raise exception 'FALHOU: gestor não atualizou o arquivo'; end if;

    reset role;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_tecnico, 'role', 'authenticated')::text, true);
    set local role authenticated;

    select count(*) into n from stores where id in (c_centro, c_boa_viagem);
    if n <> 2 then raise exception 'FALHOU: técnico vê % de 2 lojas atribuídas', n; end if;
    select count(*) into n from stores where id = c_shopping;
    if n <> 0 then raise exception 'FALHOU: técnico vê loja não atribuída'; end if;

    select count(*) into n from equipment where id = c_eq_shopping;
    if n <> 0 then raise exception 'FALHOU: técnico vê equipamento de outra loja'; end if;
    select count(*) into n from maintenance_orders where id = c_ordem_lojista;
    if n <> 0 then raise exception 'FALHOU: técnico vê ordem de outra loja'; end if;

    select count(*) into n from maintenance_orders where id = c_ordem_tecnico2;
    if n <> 1 then raise exception 'FALHOU: técnico não vê ordem da loja atribuída'; end if;

    update maintenance_orders set notes = 'x' where id = c_ordem_tecnico2;
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'FALHOU: técnico alterou ordem de outro técnico'; end if;

    update maintenance_orders set status = 'em_andamento' where id = c_ordem_tecnico;
    get diagnostics n = row_count;
    if n <> 1 then raise exception 'FALHOU: técnico não alterou a própria ordem'; end if;

    begin
      update maintenance_orders set assigned_to = v_tecnico2 where id = c_ordem_tecnico;
      raise exception 'FALHOU: técnico reatribuiu a ordem';
    exception when insufficient_privilege then null;
    end;
    begin
      update maintenance_orders set store_id = c_centro where id = c_ordem_tecnico;
      raise exception 'FALHOU: técnico mudou a loja da ordem';
    exception when insufficient_privilege then null;
    end;
    begin
      update maintenance_orders
         set equipment_id = '00000000-0000-4000-8000-0000000000e6'
       where id = c_ordem_tecnico;
      raise exception 'FALHOU: técnico mudou o equipamento da ordem';
    exception when insufficient_privilege then null;
    end;
    begin
      update maintenance_orders set scheduled_for = '2026-12-01' where id = c_ordem_tecnico;
      raise exception 'FALHOU: técnico mudou a data da ordem';
    exception when insufficient_privilege then null;
    end;

    insert into checklist_items (order_id, description) values (c_ordem_tecnico, 'ok');
    begin
      insert into checklist_items (order_id, description) values (c_ordem_tecnico2, 'x');
      raise exception 'FALHOU: técnico escreveu checklist de ordem de outro técnico';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into signatures (order_id, signer_name, storage_path)
      values (c_ordem_tecnico2, 'x', 'signatures/x.png');
      raise exception 'FALHOU: técnico assinou ordem de outro técnico';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into signatures (order_id, signer_name, storage_path)
      values (c_ordem_tecnico, 'x', 'signatures/outra.png');
      raise exception 'FALHOU: assinatura aceitou caminho de outra ordem';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into signatures (order_id, signer_id, signer_name, storage_path)
      values (c_ordem_tecnico, v_lojista, 'x', 'signatures/' || c_ordem_tecnico || '.png');
      raise exception 'FALHOU: assinatura aceitou signatário de fora da loja';
    exception when insufficient_privilege then null;
    end;
    insert into signatures (order_id, signer_name, storage_path)
    values (c_ordem_tecnico, 'Responsável', 'signatures/' || c_ordem_tecnico || '.png');

    insert into photos (order_id, storage_path, kind, created_by)
    values (c_ordem_tecnico, 'orders/' || c_ordem_tecnico || '/a.jpg', 'antes', v_tecnico);
    begin
      insert into photos (order_id, storage_path, kind, created_by)
      values (c_ordem_tecnico, 'orders/' || c_ordem_tecnico2 || '/b.jpg', 'antes', v_tecnico);
      raise exception 'FALHOU: foto aceitou caminho de outra ordem';
    exception when insufficient_privilege then null;
    end;

    insert into maintenance_orders (equipment_id, store_id, type)
    values (c_eq_centro, c_centro, 'corretiva');
    insert into maintenance_orders (equipment_id, store_id, type, assigned_to)
    values (c_eq_centro, c_centro, 'preventiva', v_tecnico);
    begin
      insert into maintenance_orders (equipment_id, store_id, type, assigned_to)
      values (c_eq_boa_viagem, c_boa_viagem, 'preventiva', v_tecnico2);
      raise exception 'FALHOU: técnico criou preventiva para outro técnico';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into maintenance_orders (equipment_id, store_id, type, opened_by)
      values (c_eq_centro, c_centro, 'corretiva', v_gestor);
      raise exception 'FALHOU: técnico abriu ordem em nome de outra pessoa';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into maintenance_orders (equipment_id, store_id, type, status)
      values (c_eq_centro, c_centro, 'corretiva', 'concluida');
      raise exception 'FALHOU: técnico abriu ordem já concluída';
    exception when insufficient_privilege then null;
    end;

    update stores set address = address where id = c_centro;
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'FALHOU: técnico alterou loja'; end if;
    update equipment set status = 'parado' where id = c_eq_centro;
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'FALHOU: técnico alterou status do equipamento'; end if;

    insert into visits (store_id, technician_id) values (c_centro, v_tecnico);
    begin
      insert into visits (store_id, technician_id) values (c_shopping, v_tecnico);
      raise exception 'FALHOU: técnico registrou visita em loja não atribuída';
    exception when insufficient_privilege then null;
    end;

    select count(*) into n from profiles where id <> v_tecnico;
    if n <> 0 then raise exception 'FALHOU: técnico vê perfil de outra pessoa'; end if;
    begin
      update profiles set role = 'gestor' where id = v_tecnico;
      raise exception 'FALHOU: técnico mudou o próprio papel';
    exception when insufficient_privilege then null;
    end;
    update profiles set phone = '81999990000' where id = v_tecnico;
    get diagnostics n = row_count;
    if n <> 1 then raise exception 'FALHOU: técnico não alterou o próprio telefone'; end if;

    reset role;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_tecnico2, 'role', 'authenticated')::text, true);
    set local role authenticated;

    select count(*) into n from stores where id = c_centro;
    if n <> 0 then raise exception 'FALHOU: técnico 2 vê loja não atribuída'; end if;

    update maintenance_orders set notes = 'x' where id = c_ordem_tecnico;
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'FALHOU: técnico 2 alterou ordem do técnico 1'; end if;

    reset role;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_lojista, 'role', 'authenticated')::text, true);
    set local role authenticated;

    select count(*) into n from stores where id in (c_centro, c_boa_viagem);
    if n <> 0 then raise exception 'FALHOU: lojista vê loja de outra pessoa'; end if;
    select count(*) into n from stores where id = c_shopping;
    if n <> 1 then raise exception 'FALHOU: lojista não vê a própria loja'; end if;
    select count(*) into n from maintenance_orders where id in (c_ordem_tecnico, c_ordem_tecnico2);
    if n <> 0 then raise exception 'FALHOU: lojista vê ordem de outra loja'; end if;
    select count(*) into n from maintenance_orders where id = c_ordem_lojista;
    if n <> 1 then raise exception 'FALHOU: lojista não vê o próprio chamado'; end if;

    update maintenance_orders set status = 'cancelada' where id = c_ordem_lojista;
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'FALHOU: lojista alterou ordem'; end if;

    insert into maintenance_orders (equipment_id, store_id, type, description)
    values (c_eq_shopping, c_shopping, 'corretiva', 'Teste RLS');

    begin
      insert into maintenance_orders (equipment_id, store_id, type, status)
      values (c_eq_shopping, c_shopping, 'corretiva', 'em_andamento');
      raise exception 'FALHOU: lojista abriu chamado com status avançado';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into maintenance_orders (equipment_id, store_id, type, assigned_to)
      values (c_eq_shopping, c_shopping, 'corretiva', v_tecnico);
      raise exception 'FALHOU: lojista atribuiu o chamado a um técnico';
    exception when insufficient_privilege then null;
    end;

    begin
      insert into maintenance_orders (equipment_id, store_id, type, assigned_to)
      values (c_eq_shopping, c_shopping, 'preventiva', v_lojista);
      raise exception 'FALHOU: lojista abriu preventiva';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into maintenance_orders (equipment_id, store_id, type)
      values (c_eq_centro, c_centro, 'corretiva');
      raise exception 'FALHOU: lojista abriu chamado em outra loja';
    exception when insufficient_privilege then null;
    end;

    begin
      insert into checklist_items (order_id, description) values (c_ordem_lojista, 'x');
      raise exception 'FALHOU: lojista escreveu checklist';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into signatures (order_id, signer_name, storage_path)
      values (c_ordem_lojista, 'x', 'signatures/x.png');
      raise exception 'FALHOU: lojista inseriu assinatura';
    exception when insufficient_privilege then null;
    end;

    insert into photos (order_id, storage_path, kind, created_by)
    values (c_ordem_lojista, 'orders/' || c_ordem_lojista || '/c.jpg', 'chamado', v_lojista);
    begin
      insert into photos (order_id, storage_path, kind, created_by)
      values (c_ordem_lojista, 'orders/' || c_ordem_lojista || '/d.jpg', 'depois', v_lojista);
      raise exception 'FALHOU: lojista inseriu foto que não é de chamado';
    exception when insufficient_privilege then null;
    end;

    begin
      insert into visits (store_id, technician_id) values (c_shopping, v_lojista);
      raise exception 'FALHOU: lojista registrou visita';
    exception when insufficient_privilege then null;
    end;

    select count(*) into n from profiles where id <> v_lojista;
    if n <> 0 then raise exception 'FALHOU: lojista vê perfil de outra pessoa'; end if;
    begin
      update profiles set role = 'gestor' where id = v_lojista;
      raise exception 'FALHOU: lojista mudou o próprio papel';
    exception when insufficient_privilege then null;
    end;

    insert into storage.objects (bucket_id, name, owner_id)
    values ('order-files', 'orders/' || c_ordem_lojista || '/c.jpg', v_lojista::text);
    begin
      insert into storage.objects (bucket_id, name, owner_id)
      values ('order-files', 'orders/' || c_ordem_lojista || '/sem-registro.jpg', v_lojista::text);
      raise exception 'FALHOU: lojista enviou arquivo sem o registro da foto';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into storage.objects (bucket_id, name, owner_id)
      values ('order-files', 'orders/' || c_ordem_lojista || '/a/c.jpg', v_lojista::text);
      raise exception 'FALHOU: lojista enviou arquivo em caminho aninhado';
    exception when insufficient_privilege then null;
    end;
    select count(*) into n from storage.objects
     where bucket_id = 'order-files' and name like 'orders/' || c_ordem_tecnico2 || '/%';
    if n <> 0 then raise exception 'FALHOU: lojista vê arquivo de outra loja'; end if;
    v_ok := false;
    begin
      delete from storage.objects
       where bucket_id = 'order-files' and name = 'orders/' || c_ordem_lojista || '/c.jpg';
      get diagnostics n = row_count;
      v_ok := n = 0;
    exception when others then
      v_ok := true;
    end;
    if not v_ok then raise exception 'FALHOU: lojista apagou arquivo do bucket'; end if;
    begin
      insert into storage.objects (bucket_id, name, owner_id)
      values ('order-files', 'orders/' || c_ordem_tecnico || '/foto.jpg', v_lojista::text);
      raise exception 'FALHOU: lojista enviou arquivo de ordem de outra loja';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into storage.objects (bucket_id, name, owner_id)
      values ('order-files', 'signatures/' || c_ordem_lojista || '.png', v_lojista::text);
      raise exception 'FALHOU: lojista enviou assinatura';
    exception when insufficient_privilege then null;
    end;

    reset role;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_tecnico, 'role', 'authenticated')::text, true);
    set local role authenticated;

    insert into storage.objects (bucket_id, name, owner_id)
    values ('order-files', 'signatures/' || c_ordem_tecnico || '.png', v_tecnico::text);
    begin
      insert into storage.objects (bucket_id, name, owner_id)
      values ('order-files', 'signatures/' || c_ordem_tecnico2 || '.png', v_tecnico::text);
      raise exception 'FALHOU: técnico enviou assinatura de ordem de outro técnico';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into storage.objects (bucket_id, name, owner_id)
      values ('order-files', 'qualquer/arquivo.jpg', v_tecnico::text);
      raise exception 'FALHOU: técnico enviou arquivo fora do padrão de caminho';
    exception when insufficient_privilege then null;
    end;
    begin
      insert into storage.objects (bucket_id, name, owner_id)
      values ('order-files', 'signatures/' || c_ordem_tecnico || '/x.png', v_tecnico::text);
      raise exception 'FALHOU: técnico enviou assinatura em caminho aninhado';
    exception when insufficient_privilege then null;
    end;
    insert into storage.objects (bucket_id, name, owner_id)
    values ('order-files', 'orders/' || c_ordem_tecnico || '/a.jpg', v_tecnico::text);
    select count(*) into n from storage.objects
     where bucket_id = 'order-files' and name = 'orders/' || c_ordem_tecnico || '/a.jpg';
    if n <> 1 then raise exception 'FALHOU: técnico não vê o próprio arquivo'; end if;
    update storage.objects set metadata = '{}'::jsonb
     where bucket_id = 'order-files' and name = 'signatures/' || c_ordem_tecnico || '.png';
    get diagnostics n = row_count;
    if n <> 1 then raise exception 'FALHOU: técnico não atualizou a própria assinatura'; end if;

    reset role;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_gestor, 'role', 'authenticated')::text, true);
    set local role authenticated;
    update maintenance_orders set assigned_to = v_tecnico2 where id = c_ordem_tecnico;
    reset role;

    perform set_config('request.jwt.claims',
      json_build_object('sub', v_tecnico, 'role', 'authenticated')::text, true);
    set local role authenticated;
    update storage.objects set metadata = '{}'::jsonb
     where bucket_id = 'order-files' and name = 'signatures/' || c_ordem_tecnico || '.png';
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'FALHOU: técnico desatribuído atualizou a assinatura'; end if;

    reset role;

    raise exception 'RLS_OK_ROLLBACK';
  exception
    when others then
      if sqlerrm = 'RLS_OK_ROLLBACK' then
        return;
      end if;
      raise;
  end;
end $$;

select 'RLS OK' as resultado;
