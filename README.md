# KYM — Know Your Maintenance

O **KYM (Know Your Maintenance)** é um aplicativo móvel voltado ao registro e acompanhamento de manutenções em redes de lojas. A proposta é centralizar informações sobre lojas, equipamentos, visitas técnicas e serviços realizados, reduzindo a dependência de planilhas, papéis e mensagens dispersas.

O aplicativo está sendo desenvolvido em Flutter para Android e iOS, com foco no uso em campo e no funcionamento **offline-first**: o técnico poderá consultar informações e registrar operações sem conexão, sincronizando os dados quando a internet estiver disponível novamente.

## Contexto acadêmico

Projeto desenvolvido para a disciplina **Programação para Dispositivos Móveis**, do curso superior de tecnologia em **Análise e Desenvolvimento de Sistemas (ADS)** do **Instituto Federal de Pernambuco (IFPE) — Campus Palmares**.

**Professor:** Renan Alves de Morais Rocha.

## Perfis de usuário

- **Técnico:** consulta a agenda, registra visitas e manutenções, anexa fotos e coleta a assinatura do responsável pela loja.
- **Gestor:** acompanha manutenções e indicadores, consulta históricos e gera QR Codes para lojas e equipamentos.
- **Lojista:** consulta os equipamentos da própria loja e abre chamados de manutenção corretiva.

## Funcionalidades previstas

- Autenticação por e-mail e senha ou conta Google, com recuperação de senha.
- Consulta de lojas, equipamentos, agenda e histórico de manutenções.
- Leitura de QR Codes para identificar lojas e equipamentos.
- Check-in e check-out de visitas técnicas.
- Registro de serviços com checklist, observações e fotos.
- Abertura de chamados corretivos.
- Assinatura digital e geração de comprovantes em PDF.
- Geração e impressão de QR Codes.
- Armazenamento local e sincronização com o backend.
- Notificações locais sobre manutenções próximas do vencimento.

## Tecnologias

- **Flutter / Dart:** desenvolvimento do aplicativo para Android e iOS.
- **Supabase:** autenticação, banco de dados PostgreSQL remoto e armazenamento de arquivos.
- **Drift / SQLite:** armazenamento local para suporte ao uso offline.
- **flutter_secure_storage:** armazenamento seguro da sessão (Keychain no iOS e Keystore no Android).
- **Flutter Modular:** modularização por funcionalidade, injeção de dependências e navegação entre telas.
- **ChangeNotifier:** gerenciamento de estado das telas, com escopo de página fornecido pelo Modular.
- **OpenStreetMap / flutter_map:** exibição de mapas.

Outros pacotes serão incorporados conforme as funcionalidades forem implementadas.

## Arquitetura

O projeto adotará **Clean Dart**, com separação de responsabilidades nas camadas `Domain`, `Infra`, `External` e `Presenter`. O objetivo é manter as regras de negócio independentes dos detalhes de interface, banco de dados e serviços externos.

## Estado do projeto

**Em desenvolvimento.** As funcionalidades descritas acima representam o escopo previsto e podem ainda não estar implementadas.

## Autores

- Arianny Leão
- Lucas Lins
- Luiz Eduardo
- Pedro Guilherme
