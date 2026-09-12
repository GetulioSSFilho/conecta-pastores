# Design aprovado para as áreas faltantes

Este documento é a porta de entrada visual antes de qualquer nova tela Flutter. Ele estende os tokens e componentes de `docs/design_system.md` e usa `docs/design_system.png` como referência de densidade, cor, tipografia e enquadramento.

## Regra visual comum

- Mobile: `Scaffold`, cabeçalho compacto com voltar/título/ação, conteúdo em rolagem, cards brancos sobre `AppColors.background`, largura útil de 390 px.
- Web: mesmo conteúdo em painel central do shell, máximo de 1180 px; listas podem virar duas colunas, mas não tabelas pesadas.
- Ações primárias usam `AppButton`; filtros usam chips; pessoas usam `AppAvatar`; estado e status usam os componentes existentes.
- Nenhum formulário usa wizard: título, campos agrupados em cards e CTA fixo no final do fluxo.
- Todos os cards com dados têm ação explícita e destino definido no contrato de mock.

## Matriz das novas telas

| Área | Composição | Ação principal | Destino |
| --- | --- | --- | --- |
| Pastores | cabeçalho + busca + chips de status + lista de pessoas | `Novo pastor` | `PastorFormScreen` |
| Cadastro de pastor | voltar + avatar + dados pessoais + vínculo ministerial + localização | `Salvar pastor` | lista atualizada e perfil |
| Igrejas | cabeçalho + busca + filtro país + cards de igreja com pastor líder | `Nova igreja` | `ChurchFormScreen` |
| Cadastro de igreja | voltar + identidade + endereço + pastor responsável | `Salvar igreja` | lista atualizada e detalhe |
| Cuidado pastoral | resumo de pendências + filtros + cards de acompanhamento | `Registrar acompanhamento` | `CareFormScreen` |
| Registrar acompanhamento | pastor selecionado + tipo + data + observação + próximo contato | `Salvar acompanhamento` | cuidado e perfil do pastor |
| Administração | resumo de acesso + cards de usuários/roles + preferências | `Gerenciar acessos` | modal mockado com confirmação |
| Relatórios | métricas + barras por país + crescimento + exportar | filtros de período | filtros alteram os mesmos dados |

## Wireframes de referência

### Lista de pastores

```text
<  Pastores                              +
   [ Buscar por nome, cidade... ]
   [Todos] [Ativos] [Sem acompanhamento]
   42 pastores                          Ver mapa
   ┌─────────────────────────────────────┐
   │ avatar  Pr. João Silva          >   │
   │         Pastor Sênior · BH           │
   │         Igreja Monte Carmo  [Ativo]  │
   └─────────────────────────────────────┘
```

### Cadastro de pastor

```text
<  Novo pastor
   [ avatar ]  Adicionar foto
   Dados pessoais
   [Nome completo] [Nome pastoral]
   [E-mail]       [Telefone]
   Vínculo ministerial
   [Igreja] [Função]
   Localização
   [País] [Cidade] [Estado]
                 [Cancelar] [Salvar pastor]
```

### Igrejas

```text
<  Igrejas                              +
   [ Buscar igreja ou cidade... ] [País]
   128 igrejas                         + Nova igreja
   ┌───────────────────┐ ┌─────────────┐
   │ Igreja Monte Carmo│ │ Esperança   │
   │ Belo Horizonte    │ │ São Paulo   │
   │ Pr. João Silva >  │ │ Pr. Carlos >│
   └───────────────────┘ └─────────────┘
```

### Cuidado pastoral

```text
<  Cuidado pastoral                    +
   [Pendentes] [Esta semana] [Todos]
   7 precisam de atenção
   ┌─────────────────────────────────────┐
   │ Pr. Marcos Lima             [Atenção]│
   │ Último contato há 42 dias            │
   │ [Registrar contato]              >   │
   └─────────────────────────────────────┘
```

### Relatórios/Administração

Usam o mesmo cabeçalho do Dashboard web da referência: métricas em cards no topo, visualização principal em card amplo, e ações secundárias discretas. Administração usa três cards de acesso (“Usuários”, “Papéis”, “Auditoria”) e não expõe controles técnicos na primeira dobra.

## Dados mockados e contrato de navegação

Uma única `MockAppDataStore` alimenta pastores, igrejas e acompanhamentos. Cada pastor referencia `churchId`; cada igreja referencia `leadPastorId`; cada acompanhamento referencia `pastorId`. Salvar um formulário adiciona o registro ao store e notifica as listas. Tocar em:

- pessoa → `ProfileScreen` do mesmo registro;
- igreja → detalhe no próprio card/modal, com pastor líder acionável;
- “Registrar contato” → formulário já preenchido com o pastor;
- país/filtro → atualiza a lista sem trocar de fonte de dados;
- métricas → lista correspondente com filtro inicial;
- exportar/ações sem backend → feedback mockado visível.

## Validação antes do Flutter

- [x] Composição derivada dos tokens e componentes do design system existente.
- [x] Estados vazios, busca, filtros, erro e formulário definidos.
- [x] Destinos e vínculos de dados definidos antes da implementação.
- [x] Densidade conferida contra as composições de Lista/Rede, Perfil, Agenda e Dashboard em `docs/design_system.png`.
- [ ] Goldens das novas telas e revisão final lado a lado com a referência, após implementação.

