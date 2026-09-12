import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type AiMessage = {
  role: 'system' | 'user' | 'assistant';
  content: string;
};

export interface AiCompletion {
  text: string;
  model: string;
}

/**
 * Cliente pequeno e server-side para a API OpenAI-compatible da NVIDIA NIM.
 *
 * A chave nunca chega ao Flutter. A cadeia de modelos pode ser trocada por
 * ambiente para acompanhar a disponibilidade do endpoint gratuito.
 */
@Injectable()
export class NvidiaAiService {
  private readonly logger = new Logger(NvidiaAiService.name);
  private readonly apiKey: string | undefined;
  private readonly baseUrl: string;
  private readonly models: string[];
  private readonly timeoutMs: number;

  // Mantemos a mesma cadeia validada no app da igreja. Em produção, prefira
  // definir NVIDIA_MODEL_FALLBACKS no ambiente e revisar a disponibilidade.
  private static readonly DEFAULT_MODELS = [
    'meta/llama-3.1-8b-instruct',
    'mistralai/mistral-small-4-119b-2603',
    'nvidia/nemotron-3-nano-30b-a3b',
    'qwen/qwen3-next-80b-a3b-instruct',
    'stepfun-ai/step-3.7-flash',
    'openai/gpt-oss-20b',
    'nvidia/nemotron-3-super-120b-a12b',
    'minimaxai/minimax-m3',
    'z-ai/glm-5.2',
    'deepseek-ai/deepseek-v4-flash',
  ];

  constructor(private readonly config: ConfigService) {
    this.apiKey = this.config.get<string>('NVIDIA_API_KEY');
    this.baseUrl = this.config.get<string>(
      'NVIDIA_BASE_URL',
      'https://integrate.api.nvidia.com/v1',
    );
    this.timeoutMs = Number(this.config.get<string>('NVIDIA_TIMEOUT_MS', '20000'));
    const primary = this.config.get<string>('NVIDIA_MODEL');
    const fallbacks = this.config.get<string>('NVIDIA_MODEL_FALLBACKS');
    const configured = [primary, ...(fallbacks?.split(',') ?? [])]
      .map((model) => model?.trim())
      .filter((model): model is string => Boolean(model));
    this.models = configured.length ? configured : NvidiaAiService.DEFAULT_MODELS;

    if (!this.apiKey) {
      this.logger.warn('NVIDIA_API_KEY não configurada; IA usará sugestões locais.');
    }
  }

  get isEnabled(): boolean {
    return Boolean(this.apiKey);
  }

  async complete(
    messages: AiMessage[],
    options: { temperature?: number; maxTokens?: number; jsonMode?: boolean } = {},
  ): Promise<AiCompletion> {
    if (!this.apiKey) throw new Error('NVIDIA NIM desabilitado.');

    let lastError = 'erro desconhecido';
    for (const model of this.models) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
      try {
        const response = await fetch(`${this.baseUrl.replace(/\/$/, '')}/chat/completions`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model,
            messages,
            temperature: options.temperature ?? 0.2,
            max_tokens: options.maxTokens ?? 700,
            ...(options.jsonMode ? { response_format: { type: 'json_object' } } : {}),
          }),
          signal: controller.signal,
        });
        const payload = (await response.json()) as {
          choices?: Array<{ message?: { content?: string | null } }>;
          error?: { message?: string };
        };
        if (!response.ok) {
          lastError = payload.error?.message ?? `HTTP ${response.status}`;
          continue;
        }
        const text = payload.choices?.[0]?.message?.content?.trim();
        if (text) return { text, model };
        lastError = 'resposta vazia';
      } catch (error) {
        lastError = error instanceof Error ? error.message : 'falha de rede';
      } finally {
        clearTimeout(timeout);
      }
      this.logger.warn(`Modelo NVIDIA ${model} falhou; tentando fallback.`);
    }
    throw new Error(`Todos os modelos NVIDIA falharam: ${lastError}`);
  }

  parseJson<T>(raw: string): T {
    let value = raw.trim();
    const fenced = value.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
    if (fenced?.[1]) value = fenced[1].trim();
    else {
      const first = value.indexOf('{');
      const last = value.lastIndexOf('}');
      if (first >= 0 && last > first) value = value.slice(first, last + 1);
    }
    return JSON.parse(value) as T;
  }
}
