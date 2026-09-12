import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { AppError } from '../src/common/errors/app-error';

/**
 * Testes de autorizacao contra a API real e o banco com seed de desenvolvimento
 * (`npm run seed`). Cobrem o requisito central: esconder botao no Flutter NAO e
 * seguranca - o servidor decide cada acesso.
 *
 * Usuarios (prisma/seed.ts):
 *   admin      GLOBAL_ADMIN     escopo GLOBAL
 *   regional   REGIONAL_LEADER  REGION:BR-MG + SUBTREE
 *   supervisor SUPERVISOR       SUBTREE
 *   pastor     PASTOR           SELF
 */
const PASSWORD = process.env.SEED_DEFAULT_PASSWORD ?? 'Pastoral@2025';

type Session = { access: string; refresh: string; userId: string; pastorId: string | null };

describe('Autorizacao e sessao (e2e)', () => {
  let app: INestApplication;
  const session: Record<string, Session> = {};
  let foreignPastorId: string;

  const api = () => request(app.getHttpServer());
  const get = (path: string, who: string) => api().get(`/api${path}`).set('Authorization', `Bearer ${session[who].access}`);

  async function login(who: string): Promise<Session> {
    const res = await api().post('/api/auth/login').send({ email: `${who}@pastoral.dev`, password: PASSWORD }).expect(200);
    return {
      access: res.body.tokens.accessToken,
      refresh: res.body.tokens.refreshToken,
      userId: res.body.user.id,
      pastorId: res.body.user.pastorId,
    };
  }

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication({ logger: false });
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
        exceptionFactory: (errors) =>
          AppError.validation(
            'Dados invalidos.',
            errors.map((e) => ({ field: e.property, constraints: Object.values(e.constraints ?? {}) })),
          ),
      }),
    );
    await app.init();

    for (const who of ['admin', 'regional', 'supervisor', 'pastor']) session[who] = await login(who);

    const all = await get('/pastors?pageSize=100', 'admin').expect(200);
    foreignPastorId = all.body.data.find((p: { country: { code: string } }) => p.country.code !== 'BR').id;
  });

  afterAll(async () => {
    await app?.close();
  });

  describe('autenticacao', () => {
    it('rejeita senha errada com codigo estavel', async () => {
      const res = await api().post('/api/auth/login').send({ email: 'pastor@pastoral.dev', password: 'Errada@12345' }).expect(401);
      expect(res.body.code).toBe('INVALID_CREDENTIALS');
      expect(res.body.stack).toBeUndefined();
    });

    it('exige token nas rotas protegidas', async () => {
      await api().get('/api/pastors').expect(401);
    });

    it('valida payload e devolve 400 com detalhes por campo', async () => {
      const res = await api().post('/api/auth/login').send({ email: 'nao-e-email', password: '' }).expect(400);
      expect(res.body.code).toBe('VALIDATION_ERROR');
      expect(Array.isArray(res.body.details)).toBe(true);
    });
  });

  describe('escopo de pastores', () => {
    it('pastor le o proprio perfil (SELF)', async () => {
      await get(`/pastors/${session.pastor.pastorId}`, 'pastor').expect(200);
    });

    it.each(['pastor', 'supervisor', 'regional'])('%s recebe 403 OUT_OF_SCOPE fora do escopo', async (who) => {
      const res = await get(`/pastors/${foreignPastorId}`, who).expect(403);
      expect(res.body.code).toBe('OUT_OF_SCOPE');
    });

    it('supervisor le subordinado; pastor nao le colega', async () => {
      const network = await get('/network?pageSize=5', 'supervisor').expect(200);
      const subordinate = network.body.data.find((p: { id: string }) => p.id !== session.pastor.pastorId)?.id;
      expect(subordinate).toBeDefined();
      await get(`/pastors/${subordinate}`, 'supervisor').expect(200);
      await get(`/pastors/${subordinate}`, 'pastor').expect(403);
    });

    it('registro inexistente devolve 404', async () => {
      await get('/pastors/00000000-0000-4000-8000-000000000000', 'admin').expect(404);
    });

    it('listagem respeita o escopo', async () => {
      const [admin, supervisor, regional] = await Promise.all([
        get('/pastors?pageSize=1', 'admin'),
        get('/pastors?pageSize=1', 'supervisor'),
        get('/pastors?pageSize=1', 'regional'),
      ]);
      expect(supervisor.body.meta.total).toBeLessThan(regional.body.meta.total);
      expect(regional.body.meta.total).toBeLessThan(admin.body.meta.total);
    });
  });

  describe('permissoes e confidencialidade', () => {
    it('permissao ausente devolve 403 FORBIDDEN', async () => {
      const res = await get('/care', 'pastor').expect(403);
      expect(res.body.code).toBe('FORBIDDEN');
    });

    it('supervisor nao ve acompanhamento CONFIDENCIAL de terceiros', async () => {
      const res = await get('/care?pageSize=100', 'supervisor').expect(200);
      const leaked = res.body.data.filter(
        (c: { confidentiality: string; performedBy: { id: string } }) =>
          c.confidentiality === 'CONFIDENTIAL' && c.performedBy.id !== session.supervisor.userId,
      );
      expect(leaked).toHaveLength(0);
    });

    it('administrador com care.read_confidential ve registros confidenciais', async () => {
      const res = await get('/care?pageSize=100', 'admin').expect(200);
      expect(res.body.data.some((c: { confidentiality: string }) => c.confidentiality === 'CONFIDENTIAL')).toBe(true);
    });

    it('filtros por pastor em solicitacoes e agenda respeitam o escopo', async () => {
      await get(`/requests?pastorId=${session.pastor.pastorId}`, 'supervisor').expect(200);
      await get(`/events?pastorId=${session.pastor.pastorId}`, 'supervisor').expect(200);
      expect((await get(`/requests?pastorId=${foreignPastorId}`, 'supervisor').expect(403)).body.code).toBe('OUT_OF_SCOPE');
      expect((await get(`/events?pastorId=${foreignPastorId}`, 'pastor').expect(403)).body.code).toBe('OUT_OF_SCOPE');
    });
  });

  describe('dashboards', () => {
    it('dashboard pessoal nao exige report.read', async () => {
      await get('/reports/dashboard/pastor', 'pastor').expect(200);
    });

    it('dashboard do lider nao inclui o proprio lider', async () => {
      const res = await get('/reports/dashboard/leader', 'supervisor').expect(200);
      expect(res.body.nextCare.some((p: { id: string }) => p.id === session.supervisor.pastorId)).toBe(false);
    });

    it('distribuicao por pais respeita o escopo', async () => {
      const [admin, supervisor] = await Promise.all([
        get('/reports/distribution/countries', 'admin').expect(200),
        get('/reports/distribution/countries', 'supervisor').expect(200),
      ]);
      expect(admin.body.length).toBeGreaterThan(supervisor.body.length);
    });
  });

  describe('sessoes', () => {
    it('refresh rotaciona e o reuso do token antigo revoga a cadeia', async () => {
      const own = await login('secretaria');
      const rotated = await api().post('/api/auth/refresh').send({ refreshToken: own.refresh }).expect(200);

      const reuse = await api().post('/api/auth/refresh').send({ refreshToken: own.refresh }).expect(401);
      expect(reuse.body.code).toBe('SESSION_REVOKED');

      // O token emitido na rotacao tambem deixa de valer.
      await api().get('/api/auth/me').set('Authorization', `Bearer ${rotated.body.accessToken}`).expect(401);
    });

    it('logout revoga o access token imediatamente', async () => {
      const own = await login('nacional');
      await api().post('/api/auth/logout').set('Authorization', `Bearer ${own.access}`).send({}).expect(204);
      await api().get('/api/auth/me').set('Authorization', `Bearer ${own.access}`).expect(401);
    });
  });
});
