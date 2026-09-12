# Progresso — Plataforma Pastoral

> Registro do estado **verificado** do produto: cada item marcado foi executado e
> conferido (comando, teste automatizado ou captura de tela), não apenas escrito.

## Estado atual — 2026-09-12

### Backend (apps/api) — rodando contra PostgreSQL real

- [x] Bancos `pastoral` e `pastoral_test` no PostgreSQL local (porta 5432).
- [x] Migration inicial (36 tabelas) + SQL manual: `pg_trgm` e índices trigram de
      busca, índice único parcial garantindo **um supervisor ativo por pastor**,
      CHECKs (sem auto-supervisão, profundidade da closure, `endsAt >= startsAt`,
      faixa de progresso, validade de credencial).
- [x] Seed reproduzível (`npm run seed`): 5 países, 13 regiões, 30 igrejas,
      110 pastores, 109 relações de supervisão, 501 linhas de closure,
      303 acompanhamentos, 24 solicitações, 7 publicações, 33 documentos,
      70 credenciais, 10 eventos, 4 treinamentos, 148 matrículas, 30 notificações.
      Sem fotos externas (evita dependência de rede e bloqueio de CORS).
- [x] API em `http://localhost:3000/api`, Swagger em `/api/docs`.
- [x] **19 testes e2e de autorização** (`npm run test:e2e`): 401/403/404, escopo
      por papel, confidencialidade, filtros por pastor, rotação e reuso de refresh
      token, logout.

Correções e melhorias de backend nesta fase:

- [x] `GET /reports/dashboard/pastor` não exige mais `report.read` (dados são do
      próprio usuário); antes retornava 403 para o pastor.
- [x] Dashboard do líder não inclui o próprio líder nos indicadores.
- [x] Novos endpoints com escopo: `/reports/distribution/countries` e
      `/reports/care/activity`.
- [x] `GET /requests` e `GET /events` aceitam `pastorId` (exigindo acesso ao
      pastor) — base das abas do Perfil 360.
- [x] Listagem de solicitações passou a filtrar confidencialidade.
- [x] Conversão de booleanos em query (`unreadOnly`, `pinnedOnly`).
- [x] **Segmentação real do Canal** (ALL, USER, COUNTRY, REGION incluindo regiões
      acima, CHURCH, MINISTRY_ROLE, SUBTREE) na visibilidade e nos destinatários;
      `publish` grava `audienceCount` e cria notificações internas.
      Validado: comunicado de MG aparece para o pastor de MG e dá 404 para fora do público.
- [x] Rate limit: 300 req/min para leitura autenticada; login e recuperação seguem
      restritos (10 por 5 min). Desligado só com `NODE_ENV=test`, com guarda que
      impede a combinação fora de `APP_ENV=DEV`.
- [x] **Download de documento por URL assinada** também no driver local: o link
      leva um token HMAC-SHA256 com validade curta (equivalente ao presigned do
      S3), emitido só depois da checagem de permissão. Antes a API devolvia uma
      URL para uma rota que não existia — todo download dava 404.
      Verificado: download sem cabeçalho `Authorization` devolve o PDF
      (`Cache-Control: private, no-store`) e token adulterado devolve **403**.
- [x] Formação: `PUT /training/enrollments/:id/progress` devolvia **500**
      (Prisma P2014) sempre que a matrícula atingia a nota e já tinha
      certificado — `create` virou `upsert`. Verificado: marcar módulo →
      100% / COMPLETED, desmarcar → 80% / IN_PROGRESS.
- [x] `GET /pastors/:id` não devolvia o vínculo ministerial (o cadastro gravava
      `churchId`/`ministryRoleId`, mas o resumo omitia): passou a incluir igreja,
      cargo, título e as datas de entrada e ordenação.
- [x] Formação: o catálogo devolvia a matrícula sem `id`, o que quebrava a lista
      no app; passou a devolver `id`, `dueAt` e `completedAt`.
- [x] Formação: catálogo e detalhe agora usam o mesmo campo `enrollment`
      (a matrícula de quem consulta) e o detalhe passou a trazer o progresso
      por módulo — sem isso a tela não teria como marcar módulo concluído.

### Flutter (apps/mobile) — integrado à API

- [x] `go_router` com URLs reais; F5 mantém a rota, "voltar" do navegador funciona
      e rota protegida redireciona preservando o destino (`/login?from=...`).
- [x] Riverpod + cliente HTTP único com renovação de sessão, rotação de refresh
      token e erros tipados por código. Falhas temporárias (sem rede, 5xx, 429)
      **não** encerram a sessão.
- [x] Responsividade centralizada (compact / medium / expanded): bottom navigation
      no celular, rail no tablet, sidebar com rótulos no desktop.
- [x] Acessibilidade da navegação coberta por teste de widget (destinos são botões
      acionáveis com rótulo, no desktop e no celular).
- [x] Telas com dados reais: Início (pastor e líder), Minha Rede (lista + árvore),
      Diretório de Pastores, Perfil 360 (11 abas), Canal (feed + publicação, com
      leitura e confirmação de ciência), Notificações, Agenda (mês/dia/próximos e
      novo compromisso), Solicitações (lista, detalhe com histórico, nova,
      assumir, mudar situação), Acompanhamentos (histórico + registrar),
      Documentos (busca, filtro por categoria e por vencimento, download por URL
      assinada), Credencial digital (cartão + QR Code) e validação pública,
      Igrejas (busca, filtros por situação/tipo/país e ficha da igreja com
      contato, responsável, pastores e congregações vinculadas),
      Formação (minhas matrículas com progresso, catálogo com filtros, ficha do
      curso com módulos, matrícula e marcação de módulo concluído),
      Relatórios (totais da rede, indicadores da minha rede, acompanhamentos por
      semana e distribuição por país — cada bloco some quando a API nega acesso,
      sem biblioteca de gráfico adicionada),
      Administração (contas de acesso com papéis e situação, papéis com suas
      permissões e trilha de auditoria filtrável — `pastor` recebe 403 em
      `/users` e `/admin/audit`, verificado),
      Mapa (igrejas georreferenciadas de `/churches/map` sobre OpenStreetMap,
      com filtro por país e atalho para a ficha da igreja),
      Cadastro de pastor (identificação, contato, país/região/cidade, igreja,
      cargo, datas, supervisor inicial e criação opcional da conta de acesso),
      Cadastro de igreja (código, nome, tipo, situação, país/região/cidade,
      endereço, coordenadas para o mapa, igreja sede, contato e fundação),
      Configurações (sessões, trocar senha, sair de todos).
- [x] Validade de documento e de credencial em **fato**, nunca rótulo:
      "Vence em 18 dias", "Vencido há 12 dias", "Válida até 06/2028".
- [x] QR Code aponta para `/verify/<token opaco>`: nenhum dado pessoal viaja no
      código, e a página pública mostra só o que a API decide expor (nome
      ministerial, número, tipo, validade).
- [x] Ações reais de contato: WhatsApp (`wa.me`), telefone e e-mail.
- [x] Correção visual relevante: cards da rede ficavam vazios porque a estratégia
      de imagem em HTML sobrepunha o conteúdo do card.

### Verificações executadas

- [x] `flutter analyze` sem problemas.
- [x] `flutter test`: 34 testes (roteamento/sessão, dashboard, acessibilidade do
      shell, mapa de igrejas, card de pastor, formatadores, falhas HTTP,
      destinos por permissão, golden do login).
- [x] `flutter build web --release --pwa-strategy=none`.
- [x] Fluxo real no navegador com API e banco: login → destino preservado → F5 →
      voltar → logout.
- [x] Telas conferidas por captura no navegador, com dados do PostgreSQL:
      Canal, Notificações, Rede, Solicitações, Agenda, Acompanhamentos (lista e
      registro), Documentos, Credencial digital, página pública de validação
      (caso válido e inválido, **sem sessão**), Igrejas e ficha da igreja,
      Formação e ficha do curso, Relatórios, Administração (usuários, papéis e
      auditoria, logado como administrador), Mapa e os dois cadastros.
- [x] Escritas verificadas de ponta a ponta pela API: acompanhamento move o
      indicador do pastor (40 dias → 0, próximo em 21 dias); matrícula em
      formação e marcação de módulo (100% → COMPLETED, desmarcar → 80% /
      IN_PROGRESS); cadastro de pastor (201, aparece na busca, vínculo de igreja
      e cargo gravados, `DELETE` 204 e a busca volta a zero).
- [x] Download de documento: a URL assinada baixa o PDF sem `Authorization`
      e o token adulterado recebe **403**.
- [x] **Teste obrigatório de segurança** repetido contra a API em execução, com
      o usuário `pastor` (que enxerga 1 pastor, enquanto o admin enxerga 50):
      `GET /pastors/<outro>` **403**, `/care?pastorId=<outro>` **403**,
      `/users` **403**, `/admin/audit` **403**, `/admin/roles` **403**,
      `/reports/dashboard/global` **403**; os próprios dados respondem 200,
      id inexistente 404 e sem token 401.
- [x] Na interface, blocos sem permissão **desaparecem** em vez de mostrar erro:
      `/reports` e `/admin` abertos como `pastor` registram os 403 no console e
      renderizam a página sem seção nenhuma quebrada.

## Pendências conhecidas

1. Não há mais tela mockada: o pacote de dados fictícios (`core/mock`), a tela
   de perfil de demonstração e os widgets que só ela usava foram removidos.
2. Upload de documento pelo app (falta seletor de arquivo) — a API já aceita.
3. Internacionalização: infraestrutura pronta (pt-BR/en/es), textos ainda embutidos.
4. Push/FCM e check-in por QR Code.
5. Harness visual: digitar em campos do Flutter Web exige clique + teclado
   (com `Tab` entre campos); `fill()` não chega ao app.
