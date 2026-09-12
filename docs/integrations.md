# Integrações e recursos externos

**Data da revisão:** 2026-09-09  
**Escopo:** decisão inicial para o MVP da Plataforma Pastoral, considerando uma máquina pequena com aproximadamente 2,4 GB de RAM disponíveis.

## Princípios

- O domínio não deve depender diretamente de um fornecedor externo.
- Integrações externas devem ficar atrás de providers pequenos e substituíveis.
- Persistência crítica permanece no PostgreSQL.
- Não adicionar worker, fila, container ou serviço residente sem necessidade comprovada.
- O MVP deve funcionar em modo degradado quando um fornecedor externo estiver indisponível.

## Decisões resumidas

| Recurso | Situação no código | Decisão inicial | Custo/infraestrutura |
| --- | --- | --- | --- |
| Notificações internas | Já existe `Notification` | Manter como fonte de verdade | PostgreSQL; sem serviço adicional |
| Dispositivos push | Já existe `NotificationDevice` | Manter e registrar tokens por plataforma | PostgreSQL; baixo |
| Push Android/iOS/Web | `PushService` existe, mas ainda não envia | Implementar adapter FCM somente quando o fluxo estiver testado | Serviço externo; sem servidor push próprio |
| In-app messages | Não existe model | Adiar até haver fluxo visual definido; criar apenas se o MVP exigir | PostgreSQL; sem ferramenta paga |
| Mapas | Não há dependência Flutter | Avaliar MapLibre + MapTiler; não hospedar tiles agora | Cliente renderiza; sem container |
| WhatsApp | Pastor já possui telefone E.164 | Começar com link `wa.me`; Cloud API somente depois | Custo zero no link; API futura com cobrança por mensagem |
| Telegram | Não existe provider/model | Manter como fase posterior | API externa gratuita; sem container separado |
| E-mail | Não existe provider | Definir interface e integrar apenas quando os fluxos de convite/reset forem testados | Resend ou Brevo free tier; sem servidor SMTP próprio |
| Biometria | Flutter ainda não iniciado | Planejar `local_auth` para desbloqueio local | Biblioteca Flutter; sem dado biométrico no backend |
| QR Code | Credencial já tem token opaco | Implementar geração/leitura no Flutter após design aprovado | Bibliotecas Flutter; sem informação privada no QR |
| Check-in | `EventParticipant.status` já existe | Reutilizar status para presença; não criar `EventAttendance` agora | PostgreSQL existente |
| Passkeys | Não existe | Documentar como evolução futura | Sem impacto no MVP |
| Reconhecimento facial | Não existe | Não implementar | Sem custo e sem risco adicional de privacidade |

## 1. Push notifications

O backend já possui `Notification`, `NotificationDevice` e `PushService`. O estado atual é deliberadamente seguro: quando o push está desabilitado, a notificação permanece no inbox; quando está habilitado, o serviço apenas registra que o adapter FCM ainda não foi configurado.

### Recomendação

Usar Firebase Cloud Messaging como primeiro provider, atrás de uma interface `NotificationProvider` ou equivalente. A página oficial de preços informa Cloud Messaging como **no-cost**. Isso evita manter um serviço próprio de push e cobre Android, iOS e web, desde que cada plataforma tenha sua configuração de cliente correspondente.

Fonte: [Firebase Pricing — Cloud Messaging](https://firebase.google.com/pricing).

OneSignal permanece como alternativa. O plano gratuito atual informa push mobile para até 1.000 usuários ativos mensais, mensagens in-app para esse público e limite de 10.000 assinantes web por envio. É conveniente, mas adiciona uma camada de fornecedor além do FCM; não será incluído agora.

Fonte: [OneSignal Pricing](https://onesignal.com/pricing).

### Falta

- definir o contrato do provider;
- implementar o adapter FCM sem colocar credenciais no código;
- tratar tokens inválidos e desativação de dispositivos;
- testar envio unitário e comportamento degradado;
- adicionar preferências de canal somente quando o fluxo de produto estiver definido.

## 2. Mensagens internas e popups

Notificações internas já persistem título, corpo, entidade, link, estado de leitura e horário. Isso deve continuar independente do push.

`InAppMessage` ainda não deve ser criado automaticamente. Antes, é preciso definir no design onde aparecem banner, modal, confirmação e dismiss. Se o MVP exigir segmentação persistida, o model mínimo deverá conter conteúdo, prioridade, janela de publicação, dismissível, confirmação e um alvo controlado. A segmentação pode reutilizar país, região, igreja, role e usuário sem criar uma tabela genérica de regras prematuramente.

## 3. Mapas

O cliente poderá usar MapLibre Flutter para renderização, com clustering no cliente. Não haverá servidor próprio de tiles nesta etapa.

O uso direto de `tile.openstreetmap.org` não deve ser tratado como uma API de produção sem limites: a política oficial exige atribuição visível, User-Agent identificável, cache, proíbe scraping/prefetch e informa disponibilidade best-effort sem SLA.

Fonte: [OpenStreetMap Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).

MapTiler é a opção hospedada a avaliar para tiles/geocoding. O plano gratuito pausa o serviço quando a cota é atingida, sem cobrança automática, e as bibliotecas de renderização são open source. O limite exato deve ser conferido na conta antes do lançamento.

Fonte: [MapTiler Cloud Pricing](https://www.maptiler.com/cloud/pricing/).

### Falta

- escolher o provedor de tiles após protótipo do mapa;
- definir atribuição e política de cache;
- adicionar `MapProvider` apenas para configuração/geocoding;
- limitar viewport, zoom e quantidade de markers retornados pela API.

## 4. WhatsApp

O MVP deve começar com link `https://wa.me/<telefone>` e mensagem pré-preenchida. Isso abre a conversa no aplicativo do usuário e não exige API, webhook, token ou serviço residente.

A WhatsApp Business Platform não é tratada como gratuita por padrão: a página oficial informa cobrança por mensagem entregue, variando por mercado e categoria. Portanto, a Cloud API fica desacoplada e futura, atrás de `WhatsAppProvider`.

Fonte: [WhatsApp Business Platform Pricing](https://whatsappbusiness.com/products/platform-pricing/).

## 5. Telegram

A Bot API oficial é gratuita para usuários e desenvolvedores. O futuro provider pode enviar comunicados e lembretes e, posteriormente, receber webhook no próprio NestJS. Não criar container exclusivo.

Fonte: [Telegram Bots — official introduction](https://core.telegram.org/bots).

O vínculo de Telegram ID, consentimento e preferências só deve entrar junto com um fluxo de tela e uma necessidade de produto confirmada.

## 6. E-mail

Não hospedar servidor de e-mail. Criar `EmailProvider` somente quando convite, reset de senha e avisos tiverem contratos e templates definidos.

Opções de baixo custo para avaliação:

- **Resend:** plano gratuito de US$ 0/mês, 3.000 e-mails/mês e limite diário de 100; bom para e-mail transacional simples.
- **Brevo:** plano gratuito sem prazo, 300 envios por dia, com e-mail transacional incluído; bom quando o limite diário atende ao volume.

Fontes: [Resend Pricing](https://resend.com/pricing) e [Brevo pricing plans](https://help.brevo.com/hc/en-us/articles/208589409-About-Brevo-s-pricing-plans).

A escolha final deve considerar domínio autenticado, reputação, residência de dados e política de retenção, não somente o limite gratuito.

## 7. Biometria e passkeys

Biometria no Flutter deverá usar `local_auth` somente para desbloquear uma sessão ou segredo local protegido pelo sistema operacional. O backend não recebe impressão digital, imagem facial ou template biométrico.

Passkeys/WebAuthn ficam documentadas como evolução. A autenticação inicial continua email + senha, com tokens revogáveis e rotação de refresh token.

## 8. QR Code, credencial e check-in

`Credential.verificationToken` já existe e é opaco, sem dados pessoais. O QR deve apontar para a validação pública usando esse token, nunca carregar nome, telefone ou outros dados privados.

`EventParticipant.status` já possui estados `ATTENDED` e `ABSENT`; isso é suficiente para o primeiro desenho de check-in. Não criar `EventAttendance` até surgir uma necessidade real de auditoria, dispositivo, horário ou operador diferente do participante.

## 9. Models que não devem ser adicionados agora

- `CredentialVerification`: o token da credencial cobre a primeira versão;
- `EventAttendance`: `EventParticipant.status` cobre presença inicial;
- `ExternalContact`: telefone E.164 do pastor atende ao link WhatsApp;
- `AnalyticsEvent`: usar logs/auditoria existentes até haver caso de uso e retenção definidos;
- `PasskeyCredential`: evolução posterior;
- qualquer fila ou tabela de delivery sem teste de volume que justifique a complexidade.

## Impacto estimado de infraestrutura

- **NestJS:** permanece como único processo de aplicação; nenhum provider exige daemon local.
- **PostgreSQL:** recebe somente as entidades já existentes; eventual `InAppMessage` ou preferências deve ser avaliado em migration separada.
- **Redis/filas:** continuam opcionais e desligados por padrão.
- **Mapas, push, e-mail e Telegram:** chamadas externas sob demanda; falhas devem ser tratadas sem bloquear a persistência principal.
- **Disco:** sem tiles, anexos ou logs de terceiros armazenados localmente além do storage já previsto.

## Próxima etapa técnica

1. Revisar guards e services para confirmar que notificações, credenciais e participantes respeitam escopo e permissões.
2. Criar migrations/seed mínimos e validar PostgreSQL real.
3. Escrever testes de autorização e integração.
4. Só depois criar um novo design visual/UX fora de DOCX e validá-lo.
