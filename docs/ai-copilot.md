# Copiloto pastoral com NVIDIA NIM

O copiloto transforma dados já autorizados da plataforma em próximas ações pequenas e práticas. Ele não substitui o discernimento pastoral e não recebe anotações confidenciais por padrão.

## O que muda para cada papel

- **Pastor local:** prepara o próximo acompanhamento, organiza agenda, transforma uma conversa em próxima ação e recomenda formações curtas.
- **Líder de pastores:** prioriza a cadência de cuidado, prepara conversas com liderados, acompanha solicitações e identifica quem precisa de contato — sempre exibindo fatos, como dias desde o último acompanhamento.
- **Gestor de líderes:** compara regiões dentro do próprio escopo, encontra gargalos de acompanhamento, monta pauta de reunião e sugere delegação.
- **Presidente:** recebe um resumo executivo da rede, evolução, concentração de demandas e perguntas para investigação antes de tomar decisões.

## Entrega inicial

`GET /api/ai/copilot` monta o contexto no backend, respeitando as mesmas regras de permissão dos dashboards. A tela **Assistente IA** apresenta um resumo, até quatro sugestões e um link para a área operacional correspondente.

O fluxo é:

1. O backend identifica o papel e consulta apenas dados do escopo do usuário.
2. A NVIDIA NIM recebe fatos agregados e não recebe a chave nem dados diretamente do Flutter.
3. O modelo responde em JSON; o backend valida campos e caminhos permitidos.
4. Se a chave não existir, o NIM estiver indisponível ou todos os fallbacks falharem, entram sugestões determinísticas locais.

## NIM e resiliência

O cliente usa o endpoint OpenAI-compatible da NVIDIA (`NVIDIA_BASE_URL`) e a mesma cadeia de modelos usada pela aplicação da igreja. Configure `NVIDIA_MODEL` e `NVIDIA_MODEL_FALLBACKS` no ambiente da API; nunca no app mobile.

O fallback possui três camadas para a evolução do produto:

- retry/modelo alternativo dentro do NIM;
- modo local determinístico para manter a experiência disponível;
- futuramente, outro provedor gratuito somente depois de validar termos, privacidade e disponibilidade.

## Próximas evoluções de maior impacto

1. **Nota para plano de cuidado:** ditado ou texto livre vira resumo, próxima ação e data sugerida para revisão humana.
2. **Pauta de reunião:** a liderança escolhe uma equipe e recebe fatos, perguntas e decisões pendentes.
3. **Busca por linguagem natural:** “quem não teve acompanhamento em abril na minha região?” vira filtro auditável, sem permitir ampliar o escopo.
4. **Rascunho de comunicação:** comunicados e lembretes em português simples, com aprovação antes do envio.
5. **Resumo semanal:** envio opcional de uma síntese por papel, com links de origem e data dos dados.
6. **Formação personalizada:** recomendações de trilhas com base em função e progresso, sem rotular pessoas.

## Guardrails obrigatórios

- autorização e escopo decididos no servidor, nunca pelo prompt ou pelo Flutter;
- não enviar `adminNotes`, notas confidenciais ou contatos fora do escopo;
- mostrar origem e data dos fatos quando a resposta evoluir para análises;
- nenhuma mensagem, cuidado, alteração cadastral ou decisão é gravada sem confirmação humana;
- registrar auditoria de prompts, modelo, resultado e ação confirmada, sem guardar segredo;
- tratar qualquer texto cadastrado como dado não confiável para evitar prompt injection;
- métricas de qualidade: sugestões abertas, ações concluídas, correções humanas, latência, fallback e custo.
