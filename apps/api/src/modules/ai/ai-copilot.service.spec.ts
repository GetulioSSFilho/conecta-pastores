import { AiCopilotService } from './ai-copilot.service';
import type { AuthenticatedUser } from '../authorization/authorization.types';

const user = (overrides: Partial<AuthenticatedUser> = {}): AuthenticatedUser => ({
  id: 'user-1',
  email: 'pastor@pastoral.dev',
  firstName: 'João',
  lastName: 'Silva',
  locale: 'pt-BR',
  timezone: 'America/Sao_Paulo',
  pastorId: 'pastor-1',
  roles: ['PASTOR'],
  permissions: [],
  scopes: [],
  sessionId: 'session-1',
  ...overrides,
});

describe('AiCopilotService', () => {
  it('mantém sugestões úteis sem chave da NVIDIA', async () => {
    const service = new AiCopilotService(
      { isEnabled: false } as never,
      { pastor: jest.fn().mockResolvedValue({ nextEvent: null, openRequests: 0 }) } as never,
    );

    const result = await service.getFor(user());

    expect(result.source).toBe('local');
    expect(result.enabled).toBe(false);
    expect(result.suggestions.length).toBeGreaterThan(0);
  });

  it('valida a resposta do NIM e descarta caminhos não permitidos', async () => {
    const service = new AiCopilotService(
      {
        isEnabled: true,
        complete: jest.fn().mockResolvedValue({
          model: 'meta/llama-3.1-8b-instruct',
          text: JSON.stringify({
            summary: 'Resumo curto.',
            suggestions: [
              {
                title: 'Abrir cuidado',
                description: 'Comece pelos acompanhamentos mais antigos.',
                priority: 'alta',
                actionLabel: 'Ver cuidado',
                actionPath: '/care',
              },
              {
                title: 'Não deve sair',
                description: 'Caminho externo.',
                priority: 'alta',
                actionLabel: 'Abrir',
                actionPath: 'https://exemplo.invalid',
              },
            ],
          }),
        }),
        parseJson: (raw: string) => JSON.parse(raw),
      } as never,
      { pastor: jest.fn(), leader: jest.fn() } as never,
    );

    const result = await service.getFor(
      user({ roles: ['SUPERVISOR'], permissions: ['report.read'] as never }),
    );

    expect(result.source).toBe('nvidia-nim');
    expect(result.model).toBe('meta/llama-3.1-8b-instruct');
    expect(result.suggestions).toHaveLength(1);
    expect(result.suggestions[0].actionPath).toBe('/care');
  });

  it('navega por intenção local apenas para áreas autorizadas', async () => {
    const service = new AiCopilotService(
      { isEnabled: false } as never,
      {} as never,
    );

    const agenda = await service.navigate(
      user({ permissions: ['event.read'] as never }),
      'Abrir minha agenda',
    );
    const rede = await service.navigate(
      user({ permissions: [] }),
      'Quero ver minha rede',
    );
    const relatorios = await service.navigate(
      user({ permissions: ['event.read'] as never }),
      'Abrir relatórios gerenciais',
    );

    expect(agenda.actionPath).toBe('/calendar');
    expect(rede.actionPath).toBeNull();
    expect(relatorios.actionPath).toBeNull();
  });
});
