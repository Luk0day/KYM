<div align="center">

# KYM — Know Your Maintenance

**Aplicativo de campo para quem faz manutenção em lojas.**
QR Code, checklist, fotos, assinatura e comprovante em PDF — tudo funcionando offline.

[![CI](https://github.com/Luk0day/KYM/actions/workflows/ci.yml/badge.svg)](https://github.com/Luk0day/KYM/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%5E3.13-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-backend-3ECF8E?logo=supabase&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-Drift-003B57?logo=sqlite&logoColor=white)
![Plataformas](https://img.shields.io/badge/plataformas-Android%20%7C%20iOS-lightgrey)
![Arquitetura](https://img.shields.io/badge/arquitetura-Clean%20Dart-5B5BD6)
![Status](https://img.shields.io/badge/status-em%20desenvolvimento-F2664D)

</div>

---

## Sumário

- [Sobre o projeto](#sobre-o-projeto)
- [Perfis de usuário](#perfis-de-usuário)
- [Requisitos funcionais](#requisitos-funcionais)
- [Requisitos não funcionais](#requisitos-não-funcionais)
- [Telas](#telas)
- [Tecnologias](#tecnologias)
- [Arquitetura](#arquitetura)
- [Como executar](#como-executar)
- [Estado atual](#estado-atual)
- [Contexto acadêmico](#contexto-acadêmico)
- [Integrantes](#integrantes)

## Sobre o projeto

O **KYM (Know Your Maintenance)** é um aplicativo de campo para quem faz manutenção em lojas. O técnico lê o QR Code da loja para registrar a chegada, identifica o equipamento pelo QR Code, registra o serviço com checklist e fotos e colhe a assinatura do responsável pela loja. O lojista acompanha e abre chamados pelo próprio equipamento, e o gestor controla a agenda e gera os QR Codes. Tudo funciona **offline** e é sincronizado quando houver conexão.

**Problema.** Redes de varejo mantêm muitos equipamentos espalhados por várias lojas, e o acompanhamento das manutenções costuma depender de planilhas, papel e mensagens soltas. Isso gera atrasos, falta de histórico por equipamento e ausência de comprovação do serviço. Além disso, quem está em campo nem sempre tem internet estável.

**Objetivos**

1. Registrar manutenções em poucos toques, com evidências (fotos, assinatura e data e hora de entrada e saída).
2. Dar acesso ao histórico e à agenda de cada equipamento, mesmo sem internet.
3. Reduzir retrabalho e perda de informação entre campo e gestão.
4. Manter os dados de técnico, gestor e lojista sincronizados em um único banco na nuvem.

**Diferenciais**

- **Chamado pelo QR Code:** o lojista abre um chamado corretivo a partir do equipamento, lendo o QR Code dele.
- **Check-in e check-out por QR Code:** o QR Code da loja registra a chegada e a saída do técnico, mesmo offline.
- **Comprovante em PDF:** serviço com fotos, assinatura, data e hora, para entregar ao lojista.

## Perfis de usuário

| Perfil | Papel no app |
|---|---|
| **Técnico** | Usuário principal. Atende várias lojas: faz check-in, registra o serviço e colhe a assinatura. |
| **Gestor** | Gestor de manutenção ou de operações. Acompanha agenda, histórico e indicadores e gera os QR Codes. |
| **Lojista** | Responsável pela loja: consulta seus equipamentos, abre chamados corretivos e assina a conclusão do serviço. |

## Requisitos funcionais

Legenda: ✅ implementado · 🚧 parcial · ⬜ não iniciado (situação na branch `develop`).

| Código | Descrição | Situação |
|---|---|:---:|
| RF01 | Login com e-mail e senha ou com Google, abrindo a sessão conforme o perfil do usuário | ✅ |
| RF02 | Recuperação de senha por e-mail | ✅ |
| RF03 | Exibir um painel resumido com manutenções pendentes, atrasadas e concluídas, próximas visitas e o estado da sincronização | ⬜ |
| RF04 | Listar as lojas com busca e filtro, mostrando a cada perfil apenas as suas | ⬜ |
| RF05 | Exibir os dados da loja, o mapa com o endereço e a lista de equipamentos | ⬜ |
| RF06 | Exibir informações, status e histórico de manutenção de cada equipamento | ⬜ |
| RF07 | Abrir um chamado de manutenção corretiva, com descrição e fotos, a partir do equipamento | ⬜ |
| RF08 | Ler QR Codes com a câmera e tratar o código lido: loja (check-in e check-out) ou equipamento | ⬜ |
| RF09 | Registrar o check-in e o check-out do técnico na loja, com data e hora, pela leitura do QR Code da loja | ⬜ |
| RF10 | Consultar a agenda de manutenções preventivas e corretivas, com filtros por status e período | ⬜ |
| RF11 | Registrar a execução de uma manutenção: checklist, observações e fotos | ⬜ |
| RF12 | Coletar a assinatura digital do responsável da loja ao concluir o serviço e gerar o comprovante em PDF | ⬜ |
| RF13 | Gerar e imprimir os QR Codes das lojas e dos equipamentos (somente gestor) | ⬜ |
| RF14 | Funcionar offline para consulta e registro, com sincronização automática ao reconectar | 🚧 |
| RF15 | Exibir notificações de manutenções próximas do vencimento | ⬜ |
| RF16 | Controlar o acesso por perfil (técnico, gestor e lojista), exibindo apenas o que cada um pode fazer | 🚧 |
| RF17 | Gerenciar o perfil e as configurações do usuário, incluindo sincronização, notificações e saída da conta | ⬜ |

## Requisitos não funcionais

| Requisito | Descrição |
|---|---|
| **Offline** | Dados essenciais (lojas, equipamentos, agenda, ordens em andamento) disponíveis sem internet, com fila de sincronização. |
| **Desempenho** | Listas e consultas a partir do banco local abrem em até 2 segundos. |
| **Segurança** | Comunicação por HTTPS, token de sessão em armazenamento seguro e controle de acesso por perfil. |
| **Acessibilidade** | Bom contraste, fontes que respeitam o tamanho do sistema e áreas de toque adequadas. |
| **Usabilidade** | Fluxos curtos, pensados para uso em pé e com uma mão. |
| **Compatibilidade** | Android e iOS com a mesma base de código Flutter. |
| **Privacidade** | Tratamento de dados pessoais conforme a LGPD. |

## Telas

O aplicativo prevê **12 telas**, cada uma com função própria.

| # | Tela | Responsabilidade | Perfis | Situação |
|---|---|---|---|:---:|
| 1 | Login | Autenticar com e-mail e senha ou Google e abrir a sessão conforme o perfil | Todos | ✅ |
| 2 | Recuperar senha | Pedir o envio do e-mail de redefinição | Todos | ✅ |
| 3 | Painel | Resumir pendentes, atrasadas e concluídas, listar as próximas visitas e mostrar o estado da sincronização | Técnico e gestor | 🚧 |
| 4 | Lojas | Listar as lojas, com busca e filtro | Técnico, gestor e lojista (cada um vê só as suas) | ⬜ |
| 5 | Detalhes da loja | Mostrar dados e mapa, listar os equipamentos e iniciar o check-in lendo o QR da loja | Técnico, gestor e lojista | ⬜ |
| 6 | Detalhes do equipamento | Mostrar informações, status e histórico, e permitir abrir um chamado corretivo | Técnico, gestor e lojista | ⬜ |
| 7 | Leitor de QR Code | Abrir a câmera e tratar o código lido: loja (check-in e check-out) ou equipamento | Técnico e lojista | ⬜ |
| 8 | Agenda | Listar manutenções preventivas e corretivas, com filtro por status e período | Técnico e gestor | ⬜ |
| 9 | Registro de manutenção | Preencher checklist, observações e fotos e concluir o serviço | Técnico | ⬜ |
| 10 | Assinatura | Coletar a assinatura do responsável da loja e gerar o comprovante em PDF | Técnico (o responsável da loja assina no aparelho dele) | ⬜ |
| 11 | Perfil e configurações | Mostrar os dados do usuário, a sincronização e as notificações, e permitir sair | Todos | ⬜ |
| 12 | QR Codes | Gerar e imprimir os QR Codes das lojas e dos equipamentos | Somente gestor | ⬜ |

> A tela de Painel existe hoje como página inicial provisória, usada para validar a sessão e o perfil do usuário.

## Tecnologias

| Tecnologia | Uso |
|---|---|
| **Flutter / Dart** | Aplicativo para Android e iOS com uma única base de código |
| **Supabase** | Autenticação (e-mail e senha e Google), banco PostgreSQL com RLS e armazenamento de fotos |
| **Drift / SQLite** | Banco local e fila de sincronização (outbox) para o uso offline |
| **Flutter Modular** | Modularização por funcionalidade, injeção de dependências e rotas |
| **ChangeNotifier** | Gerenciamento de estado das telas |
| **google_sign_in** | Login com Google integrado ao Supabase Auth |
| **flutter_secure_storage** | Sessão guardada no Keychain (iOS) e no Keystore (Android) |
| **flutter_dotenv** | Configuração por variáveis de ambiente |
| **OpenStreetMap / flutter_map** | Mapa da loja *(previsto)* |
| **mobile_scanner / qr_flutter** | Leitura e geração de QR Codes *(previsto)* |
| **image_picker / signature / pdf / printing** | Fotos, assinatura, comprovante e impressão *(previsto)* |
| **flutter_local_notifications / connectivity_plus** | Lembretes e detecção de rede *(previsto)* |

## Arquitetura

O projeto segue **Clean Dart**, com as camadas `domain`, `infra`, `external` e `presenter`, organizadas em módulos por funcionalidade. As regras de negócio ficam independentes da interface, do banco e dos serviços externos, o que permite, por exemplo, trocar o Supabase por uma implementação em memória nos testes.

```
lib/
├── main.dart
├── app/                    # núcleo: módulo raiz, tema, config, banco local, armazenamento seguro
│   ├── database/           #   Drift: tabelas, DAOs e enums
│   ├── storage/            #   sessão e preferências
│   └── theme/              #   cores, tipografia e tema (Lato)
├── modules/
│   ├── auth/               # login, Google e recuperação de senha
│   │   ├── domain/         #   entidades, casos de uso e contratos
│   │   ├── infra/          #   repositórios e datasource fake
│   │   ├── external/       #   Supabase e Google Sign-In
│   │   └── presenter/      #   páginas, controllers e widgets
│   └── home/               # página inicial provisória
└── shared/presenter/widgets/   # componentes base (botão, campo, chip, banner)

supabase/migrations/        # schema inicial: tabelas e políticas RLS
test/                       # testes de unidade e de widget
```

## Como executar

**Pré-requisitos:** [Flutter](https://docs.flutter.dev/get-started/install) (canal stable, Dart `^3.13.1`), Android Studio ou Xcode, e um dispositivo ou emulador.

**1. Clone e instale as dependências**

```bash
git clone https://github.com/Luk0day/KYM.git
cd KYM
flutter pub get
```

**2. Gere o código do Drift** (os arquivos `*.g.dart` não são versionados)

```bash
dart run build_runner build
```

**3. Configure o ambiente**

```bash
cp .env.example .env
```

| Variável | Descrição |
|---|---|
| `SUPABASE_URL` | URL do projeto no Supabase |
| `SUPABASE_PUBLISHABLE_KEY` | Chave **publicável** (nunca use a `service_role`) |
| `USE_FAKE_AUTH` | `true` usa login em memória, sem Supabase |
| `GOOGLE_WEB_CLIENT_ID` | Client ID OAuth "Aplicativo da Web"; vazio desativa o login com Google |

> **Sem backend?** Use `USE_FAKE_AUTH=true` e entre com `tecnico@kym.test`, `gestor@kym.test` ou `lojista@kym.test` (senha `kym12345`).

**4. (Com Supabase)** Aplique `supabase/migrations/20261029000000_schema_inicial.sql` no projeto e habilite o provedor Google em *Authentication > Providers*.

**5. Execute**

```bash
flutter run
```

**Testes e análise estática**

```bash
flutter analyze
flutter test
```

O login com Google está disponível no Android; em depuração ele depende da keystore de debug compartilhada pelo grupo.

## Estado atual

O projeto está **em desenvolvimento**, em 3 sprints de 15 dias (19/10 a 02/12/2026):

| Sprint | Período | Foco |
|---|---|---|
| 1 | 19/10 a 02/11 | Base do app: escopo, Supabase, tema, login (e-mail e Google), recuperação de senha, banco local |
| 2 | 03/11 a 17/11 | Dados e consulta: lojas, equipamentos, agenda, controle por perfil, leitor de QR Code e chamado corretivo |
| 3 | 18/11 a 02/12 | Campo e fechamento: registro de manutenção, assinatura e PDF, QR Codes, sincronização, notificações, painel, perfil e entrega final |

## Contexto acadêmico

Projeto desenvolvido para a disciplina **Programação para Dispositivos Móveis**, do curso superior de tecnologia em **Análise e Desenvolvimento de Sistemas (ADS)** do **Instituto Federal de Pernambuco (IFPE) — Campus Palmares**.

**Professor:** Renan Alves de Morais Rocha.

## Integrantes

- Arianny Raphaelly Paiva Leão
- Lucas Gomes da Silva Lins
- Luiz Eduardo da Silva
- Pedro Guilherme Cordeiro dos Santos
