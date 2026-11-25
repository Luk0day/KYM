-- B27: equipment.status passa de texto livre para enum, no mesmo padrão de
-- order_status. Valores: operando, em_manutencao, parado.

create type equipment_status as enum ('operando', 'em_manutencao', 'parado');

-- Dados fora da lista (seed antigo ou testes) voltam para o padrão.
update equipment
   set status = 'operando'
 where status not in ('operando', 'em_manutencao', 'parado');

alter table equipment alter column status drop default;

alter table equipment
  alter column status type equipment_status using status::equipment_status;

alter table equipment alter column status set default 'operando';
alter table equipment alter column status set not null;
