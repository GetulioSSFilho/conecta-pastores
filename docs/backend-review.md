# Revisão do backend

**Data:** 2026-09-09  
**Status:** revisão estática inicial concluída; validação com PostgreSQL e testes automatizados ainda pendentes.

## O que está consistente

- Guards globais de throttling, JWT e permissões estão registrados no `AppModule`.
- O `PermissionsGuard` lê permissões do principal autenticado e não depende do Flutter.
- `ScopeResolver` produz filtros de pastores e igrejas e possui cache curto para a árvore regional.
- Cuidado pastoral aplica confidencialidade e escopo de pastor.
- Documentos validam acesso ao pastor antes de upload/download/remoção.
- Credenciais possuem token opaco para verificação pública e não expõem dados privados no token.
- Notificações são isoladas por `userId`; tokens de dispositivo são armazenados separadamente.
- O catálogo de permissões centraliza as chaves usadas nas rotas.

## Ajuste realizado

- A rota `PUT /requests/:id/status` e o método correspondente agora usam `request.resolve`. Antes usavam `request.assign`, apesar de `request.resolve` já existir no catálogo.

## Pendências encontradas

### Solicitações

- `assign`, `changeStatus` e `remove` precisam de testes para garantir que a mutação respeita escopo do registro, além da permissão de ação.
- A política precisa decidir se `request.assign` e `request.resolve` implicam leitura do registro ou se a autorização deve consultar um filtro próprio.
- O destinatário de notificações e a visibilidade de comentários internos precisam de testes de ator, solicitante e responsável.

### Eventos

- `create` valida a presença de `scopeRefId`, mas ainda não comprova se o valor pertence ao tipo de escopo informado.
- `create` não valida escopo dos `pastorIds` nem `churchId` antes de criar participantes/evento.
- `update` precisa repetir a validação de datas (`endsAt > startsAt`) e de escopo.
- A listagem atualmente resolve eventos globais, do organizador ou de participantes diretos; a regra para eventos de país/região/igreja deve ser definida e testada antes de ampliar a consulta.

### Geografia

- Escrita de países/regiões exige `geography.write` no controller, mas o service não recebe o ator. Isso é aceitável somente se essa permissão for sempre global; se houver administração regional, será necessário aplicar escopo na escrita.

### Canal

- A implementação atual permite audiência `ALL` ou `USER` no service. Audiências por país, região, igreja, role e subtree ainda não estão implementadas e não devem ser anunciadas no Flutter como disponíveis.

### Dados e execução

- Não há migrations, seed ou testes automatizados no diretório `apps/api`.
- O build e o typecheck passam, mas ainda não comprovam comportamento com PostgreSQL real.
- Push FCM está preparado por configuração, porém o adapter de envio ainda não existe.

## Critério para sair desta etapa

- Corrigir ou formalizar as regras de escopo acima.
- Criar migration e seed reproduzíveis.
- Executar testes de autorização com pelo menos administrador global, líder regional/supervisor e pastor comum.
- Confirmar `403` para acesso fora do escopo, `404` para entidade inexistente e isolamento de dados confidenciais.
- Só então iniciar o novo design visual/UX do Flutter. Nenhuma tela Flutter deve ser criada antes disso.
