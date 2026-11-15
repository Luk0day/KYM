-- B05/B06 · Dados de teste do projeto de dev (idempotente: pode rodar de novo)
--
-- Antes de rodar, crie os usuários em Authentication > Users > Add user
-- (marcar "Auto Confirm User"), todos com a senha kym12345:
--   tecnico@kym.test, tecnico2@kym.test, gestor@kym.test, lojista@kym.test
-- O trigger handle_new_user cria o perfil; este script define o papel, as
-- lojas, os equipamentos, as atribuições e algumas ordens.
--
-- Rode no SQL Editor (como postgres). Os ids das lojas, equipamentos e ordens
-- são os mesmos do FakeDataSeeder do app, para os dois ambientes baterem.
--
-- Atribuições (lojas diferentes por usuário, para testar a RLS):
--   tecnico  -> Loja Centro e Loja Boa Viagem
--   tecnico2 -> Loja Boa Viagem
--   lojista  -> Loja Shopping
--   gestor   -> vê todas (não precisa de atribuição)

do $$
declare
  v_tecnico  uuid := (select id from auth.users where email = 'tecnico@kym.test');
  v_tecnico2 uuid := (select id from auth.users where email = 'tecnico2@kym.test');
  v_gestor   uuid := (select id from auth.users where email = 'gestor@kym.test');
  v_lojista  uuid := (select id from auth.users where email = 'lojista@kym.test');

  c_centro     constant uuid := '00000000-0000-4000-8000-0000000000a1';
  c_boa_viagem constant uuid := '00000000-0000-4000-8000-0000000000a2';
  c_shopping   constant uuid := '00000000-0000-4000-8000-0000000000a3';
begin
  if v_tecnico is null or v_tecnico2 is null or v_gestor is null or v_lojista is null then
    raise exception 'Crie antes os 4 usuários de teste em Authentication > Users.';
  end if;

  update profiles set role = 'tecnico', full_name = 'Técnico Teste'   where id = v_tecnico;
  update profiles set role = 'tecnico', full_name = 'Técnico 2 Teste' where id = v_tecnico2;
  update profiles set role = 'gestor',  full_name = 'Gestor Teste'    where id = v_gestor;
  update profiles set role = 'lojista', full_name = 'Lojista Teste'   where id = v_lojista;

  insert into stores (id, name, code, address, city, latitude, longitude, qr_token) values
    (c_centro,     'Loja Centro',     'LJ-001', 'Av. Guararapes, 120',        'Recife', -8.0631, -34.8711, '00000000-0000-4000-8000-0000000001a1'),
    (c_boa_viagem, 'Loja Boa Viagem', 'LJ-002', 'Av. Boa Viagem, 3500',       'Recife', -8.1181, -34.8999, '00000000-0000-4000-8000-0000000001a2'),
    (c_shopping,   'Loja Shopping',   'LJ-003', 'Rua Padre Carapuceiro, 777', 'Recife', null,    null,     '00000000-0000-4000-8000-0000000001a3')
  on conflict (id) do nothing;

  insert into equipment (id, store_id, name, category, brand, model, status, qr_token) values
    ('00000000-0000-4000-8000-0000000000e1', c_centro,     'Ar-condicionado Salão',   'Climatização', 'Carrier',   'Split 24000',   'operando',      '00000000-0000-4000-8000-0000000001e1'),
    ('00000000-0000-4000-8000-0000000000e2', c_centro,     'Câmara Fria',             'Refrigeração', 'Elber',     'CF-300',        'em_manutencao', '00000000-0000-4000-8000-0000000001e2'),
    ('00000000-0000-4000-8000-0000000000e3', c_centro,     'Balcão Refrigerado',      'Refrigeração', 'Gelopar',   'GBR-120',       'operando',      '00000000-0000-4000-8000-0000000001e3'),
    ('00000000-0000-4000-8000-0000000000e4', c_centro,     'Nobreak',                 'Elétrica',     'SMS',       'Manager III',   'operando',      '00000000-0000-4000-8000-0000000001e4'),
    ('00000000-0000-4000-8000-0000000000e5', c_boa_viagem, 'Ar-condicionado Vitrine', 'Climatização', 'Gree',      'Eco Garden',    'operando',      '00000000-0000-4000-8000-0000000001e5'),
    ('00000000-0000-4000-8000-0000000000e6', c_boa_viagem, 'Freezer Horizontal',      'Refrigeração', 'Metalfrio', 'DA550',         'parado',        '00000000-0000-4000-8000-0000000001e6'),
    ('00000000-0000-4000-8000-0000000000e7', c_boa_viagem, 'Gerador',                 'Elétrica',     'Branco',    'B4T-8000',      'operando',      '00000000-0000-4000-8000-0000000001e7'),
    ('00000000-0000-4000-8000-0000000000e8', c_shopping,   'Ar-condicionado Loja',    'Climatização', 'LG',        'Dual Inverter', 'operando',      '00000000-0000-4000-8000-0000000001e8'),
    ('00000000-0000-4000-8000-0000000000e9', c_shopping,   'Expositor Refrigerado',   'Refrigeração', 'Gelopar',   'GPTU-120',      'operando',      '00000000-0000-4000-8000-0000000001e9'),
    ('00000000-0000-4000-8000-0000000000ea', c_shopping,   'Exaustor',                'Ventilação',   'Ventisol',  null,            'operando',      '00000000-0000-4000-8000-0000000001ea')
  on conflict (id) do nothing;

  insert into store_assignments (store_id, user_id) values
    (c_centro,     v_tecnico),
    (c_boa_viagem, v_tecnico),
    (c_boa_viagem, v_tecnico2),
    (c_shopping,   v_lojista)
  on conflict do nothing;

  insert into maintenance_orders
    (id, equipment_id, store_id, type, status, description, scheduled_for, opened_by, assigned_to, completed_at)
  values
    ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000e9', c_shopping,
     'corretiva', 'aberta', 'Expositor não está mantendo a temperatura.', null, v_lojista, null, null),
    ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-4000-8000-0000000000e5', c_boa_viagem,
     'preventiva', 'agendada', 'Limpeza de filtros e checagem de gás.', '2026-11-20', v_gestor, v_tecnico, null),
    ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-4000-8000-0000000000e1', c_centro,
     'preventiva', 'concluida', 'Manutenção preventiva trimestral.', '2026-10-15', v_gestor, v_tecnico, '2026-10-15 15:30-03'),
    ('00000000-0000-4000-8000-0000000000f4', '00000000-0000-4000-8000-0000000000e7', c_boa_viagem,
     'preventiva', 'agendada', 'Teste de carga do gerador.', '2026-11-25', v_gestor, v_tecnico2, null)
  on conflict (id) do nothing;
end $$;
