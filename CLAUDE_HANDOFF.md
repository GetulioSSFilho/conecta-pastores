# Handoff — Plataforma Pastoral (Conecta Pastores)

> Estado **verificado** em 2026-09-12. O detalhamento por etapa está em
> `docs/progress.md`. Este arquivo é o ponto de partida de qualquer sessão.

## Como rodar

```bash
# 1. Banco (PostgreSQL local, porta 5432) — credenciais em apps/api/.env
cd apps/api
npm install
npx prisma migrate deploy      # ou: npm run prisma:migrate
npm run seed                   # dados de desenvolvimento
npm run start:dev              # API em http://localhost:3000/api (Swagger em /api/docs)
npm run test:e2e               # 19 testes de autorização contra o banco com seed

# 2. App (Flutter Web como prioridade)
cd apps/mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
# ou build + servidor com fallback de rota (F5 em /pastors/123 funciona):
flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=http://localhost:3000/api
python tool/serve_web.py 8080
```

Usuários de teste (senha `Pastoral@2025`), todos `@pastoral.dev`:
`admin` (global), `nacional` (BR + rede), `regional` (MG + rede),
`supervisor` (rede), `pastor` (só os próprios dados), `secretaria` (BR).

## O que já é real (ligado à API, com dados do PostgreSQL)

- Autenticação completa: login, refresh com rotação, logout, "Lembrar de mim",
  sessões ativas com revogação, troca e redefinição de senha.
- Navegação por URL (go_router): F5, botão voltar e links diretos funcionam;
  rota protegida manda para o login preservando o destino.
- Início (pastor e líder), Minha Rede (lista real + árvore visual de exemplo), Diretório de Pastores,
  Perfil 360 (11 abas), Canal (feed + publicação, leitura e confirmação),
  Notificações, Agenda (mês/dia/próximos + novo compromisso), Solicitações
  (lista, detalhe com histórico, nova, assumir, mudar situação),
  Acompanhamentos (histórico + registrar), Documentos (filtros + download por
  URL assinada), Credencial digital com QR Code e a página pública de validação
  (`/verify/<token>`, aberta sem sessão), Igrejas (lista + ficha), Formação
  (catálogo, matrícula e progresso por módulo), Relatórios, Administração
  (contas, papéis e auditoria), Mapa (OpenStreetMap), cadastro de Pastor,
  cadastro de Igreja e Configurações.
- Contato real: WhatsApp (wa.me), telefone e e-mail.

## O que ainda é mock

O modo **Árvore** de Minha Rede usa dados locais de exemplo para reproduzir a
composição visual aprovada; a lista continua consumindo a API. O pacote
`core/mock`, a tela de perfil de demonstração e os widgets que só ela usava
foram removidos. Ao criar tela nova, siga o padrão: `domain/` (modelos) +
`data/` (providers) + `presentation/`, rota no `app_router.dart`, depois
`flutter analyze`, `flutter test` e build.

## O que falta (próximos passos)

1. Upload de documento pelo app (a API já aceita `POST /documents`; falta um
   seletor de arquivo no Flutter).
2. i18n: a infraestrutura está pronta (pt-BR/en/es no `MaterialApp`), os textos
   ainda estão embutidos nas telas — migrar para ARB.
3. Administração é somente leitura: editar papéis (`PUT /admin/roles/:id/permissions`)
   e escopos (`/admin/scopes/users/:id`) ainda não tem tela.
4. Push/FCM (`FCM_ENABLED=false`) e check-in por QR Code em eventos.

## Decisão de rumo — 2026-09-12

O produto está integrado ponta a ponta, mas o dono do projeto ainda está na fase
de **ideia**: a partir daqui, **integração está congelada**. Não inicie novos
endpoints nem novas integrações por conta própria; o trabalho é iterar telas,
fluxo e conteúdo em cima do que já existe (os dados fictícios vêm do seed).
Primeiro commit do repositório: `11bd5d0`.

## Regras que não podem ser quebradas

1. **Autorização é do servidor.** Esconder botão não é segurança: toda listagem
   e todo acesso por id passam por permissão + escopo na API (403 `OUT_OF_SCOPE`).
2. **Indicadores são fatos**, nunca julgamento: "63 dias sem acompanhamento",
   jamais "pastor em risco".
3. **Confidencialidade do cuidado** (NORMAL/RESTRITO/CONFIDENCIAL) é decidida na
   API e auditada na leitura.
4. Nada de dado mockado em tela nova por padrão; exceção: composições visuais de
   exemplo explicitamente aprovadas, como o modo Árvore atual.
5. Toda mudança termina com `flutter analyze`, `flutter test` e, quando mexe em
   API, `npm run test:e2e`.

## Ambiente

- PostgreSQL local; sem Docker nesta máquina (o compose segue como referência).
- Cache do npm do projeto em `.npm-cache` (o cache global não é gravável aqui).
- Harness visual: Playwright + servidor estático com fallback SPA. Para digitar
  em campos do Flutter Web é preciso **clicar e digitar** (com `Tab` entre
  campos); `fill()` não chega ao app. O script reutilizável recebe usuário e
  rotas: `python capture_routes.py <saída> <email> nome:/rota ...`.
- Armadilhas do harness já pagas:
  - O rate limit de autenticação (10 tentativas / 5 min) é compartilhado com os
    scripts de verificação: vários logins seguidos derrubam o login do harness
    (aparece como tela de login ou 401). Reaproveite um token por script.
  - `ChoiceChip` não aparece na árvore de acessibilidade do Flutter Web —
    clique por coordenada quando precisar trocar de aba/filtro na captura.
  - Limpe o campo antes de digitar (`Control+A`, `Delete`): resíduo de texto
    gera 401 e polui a auditoria com `LOGIN_FAILED`.
- Detalhes de API que já custaram tempo: a hierarquia pastoral responde em
  `/network/:pastorId/{ancestors,direct-reports,stats}` (não em `/pastors/...`);
  auditoria em `/admin/audit`; números decimais do Prisma (latitude/longitude)
  chegam como **string** no JSON.
