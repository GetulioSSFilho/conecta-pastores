/**
 * Seed de desenvolvimento.
 *
 * Gera uma base coerente para testar permissoes VISUALMENTE:
 *  - 5 paises, 13 regioes (com subregiao), 30 igrejas, 100+ pastores;
 *  - hierarquia real: liderança global -> nacional -> regional -> supervisor -> pastor;
 *  - acompanhamentos (inclusive nunca acompanhados e >30 dias), canal, solicitacoes,
 *    documentos, credenciais, eventos, formacao e notificacoes;
 *  - usuarios de teste com escopos diferentes (ver README / docs/permissions.md).
 *
 * Idempotente: limpa as tabelas antes. Bloqueado em PRODUCTION.
 */
import { faker } from '@faker-js/faker/locale/pt_BR';
import { Algorithm, hash } from '@node-rs/argon2';
import {
  AudienceType,
  CareStatus,
  ChurchStatus,
  ChurchType,
  Confidentiality,
  CredentialStatus,
  CredentialType,
  DocumentCategory,
  DocumentVisibility,
  EnrollmentStatus,
  EventScopeType,
  EventType,
  MaritalStatus,
  NotificationType,
  PastorStatus,
  PostStatus,
  PostType,
  Prisma,
  PrismaClient,
  RequestPriority,
  RequestStatus,
  ScopeType,
  TrainingKind,
  TrainingStatus,
  UserStatus,
} from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { ALL_PERMISSIONS, PERMISSIONS, SYSTEM_ROLES, splitPermission } from '../src/modules/authorization/permissions.constants';

const prisma = new PrismaClient();
faker.seed(20260911);

const DAY = 86_400_000;
const now = Date.now();
const daysAgo = (d: number) => new Date(now - d * DAY);
const daysAhead = (d: number) => new Date(now + d * DAY);
const token = () => randomBytes(24).toString('base64url');
const pick = <T>(arr: readonly T[]): T => arr[Math.floor(faker.number.float({ min: 0, max: 0.9999 }) * arr.length)];

// ---------------------------------------------------------------------------
// Catalogos
// ---------------------------------------------------------------------------

const P = PERMISSIONS;

/** Permissoes por role. Escopo de dados vem de UserScope, nao da role. */
const ROLE_PERMISSIONS: Record<string, { name: string; rank: number; permissions: string[] }> = {
  [SYSTEM_ROLES.GLOBAL_ADMIN]: { name: 'Administrador global', rank: 100, permissions: ALL_PERMISSIONS },
  [SYSTEM_ROLES.NATIONAL_LEADER]: {
    name: 'Líder nacional',
    rank: 80,
    permissions: [
      P.PASTOR_READ, P.PASTOR_WRITE, P.PASTOR_READ_ADMIN_NOTES, P.CHURCH_READ, P.CHURCH_WRITE, P.GEOGRAPHY_READ,
      P.NETWORK_READ, P.NETWORK_WRITE, P.CARE_READ, P.CARE_WRITE, P.CARE_READ_RESTRICTED,
      P.CHANNEL_READ, P.CHANNEL_WRITE, P.CHANNEL_PUBLISH, P.CHANNEL_READ_STATS,
      P.REQUEST_READ, P.REQUEST_WRITE, P.REQUEST_ASSIGN, P.REQUEST_RESOLVE,
      P.EVENT_READ, P.EVENT_WRITE, P.DOCUMENT_READ, P.DOCUMENT_WRITE,
      P.CREDENTIAL_READ, P.CREDENTIAL_WRITE, P.TRAINING_READ, P.TRAINING_ENROLL, P.TRAINING_MANAGE_ENROLLMENTS,
      P.REPORT_READ, P.REPORT_READ_GLOBAL, P.USER_READ, P.AUDIT_READ,
    ],
  },
  [SYSTEM_ROLES.REGIONAL_LEADER]: {
    name: 'Líder regional',
    rank: 60,
    permissions: [
      P.PASTOR_READ, P.PASTOR_WRITE, P.CHURCH_READ, P.GEOGRAPHY_READ, P.NETWORK_READ, P.NETWORK_WRITE,
      P.CARE_READ, P.CARE_WRITE, P.CARE_READ_RESTRICTED, P.CHANNEL_READ, P.CHANNEL_WRITE, P.CHANNEL_READ_STATS,
      P.REQUEST_READ, P.REQUEST_WRITE, P.REQUEST_ASSIGN, P.REQUEST_RESOLVE, P.EVENT_READ, P.EVENT_WRITE,
      P.DOCUMENT_READ, P.DOCUMENT_WRITE, P.CREDENTIAL_READ, P.TRAINING_READ, P.TRAINING_ENROLL,
      P.TRAINING_MANAGE_ENROLLMENTS, P.REPORT_READ,
    ],
  },
  [SYSTEM_ROLES.SUPERVISOR]: {
    name: 'Supervisor',
    rank: 40,
    permissions: [
      P.PASTOR_READ, P.CHURCH_READ, P.GEOGRAPHY_READ, P.NETWORK_READ, P.CARE_READ, P.CARE_WRITE,
      P.CARE_READ_RESTRICTED, P.CHANNEL_READ, P.REQUEST_READ, P.REQUEST_WRITE, P.REQUEST_ASSIGN,
      P.EVENT_READ, P.EVENT_WRITE, P.DOCUMENT_READ, P.CREDENTIAL_READ, P.TRAINING_READ, P.TRAINING_ENROLL,
      P.REPORT_READ,
    ],
  },
  [SYSTEM_ROLES.PASTOR]: {
    name: 'Pastor',
    rank: 20,
    permissions: [
      P.PASTOR_READ, P.CHURCH_READ, P.GEOGRAPHY_READ, P.NETWORK_READ, P.CHANNEL_READ, P.REQUEST_READ,
      P.REQUEST_WRITE, P.EVENT_READ, P.DOCUMENT_READ, P.CREDENTIAL_READ, P.TRAINING_READ, P.TRAINING_ENROLL,
    ],
  },
  [SYSTEM_ROLES.SECRETARY]: {
    name: 'Secretária',
    rank: 30,
    permissions: [
      P.PASTOR_READ, P.PASTOR_WRITE, P.CHURCH_READ, P.CHURCH_WRITE, P.GEOGRAPHY_READ, P.DOCUMENT_READ,
      P.DOCUMENT_WRITE, P.CREDENTIAL_READ, P.CREDENTIAL_WRITE, P.EVENT_READ, P.EVENT_WRITE, P.REQUEST_READ,
    ],
  },
};

const COUNTRIES = [
  { code: 'BR', code3: 'BRA', name: 'Brasil', phoneCode: '55', currency: 'BRL', locale: 'pt-BR', tz: 'America/Sao_Paulo' },
  { code: 'PT', code3: 'PRT', name: 'Portugal', phoneCode: '351', currency: 'EUR', locale: 'pt-PT', tz: 'Europe/Lisbon' },
  { code: 'US', code3: 'USA', name: 'Estados Unidos', phoneCode: '1', currency: 'USD', locale: 'en-US', tz: 'America/New_York' },
  { code: 'AO', code3: 'AGO', name: 'Angola', phoneCode: '244', currency: 'AOA', locale: 'pt-AO', tz: 'Africa/Luanda' },
  { code: 'MZ', code3: 'MOZ', name: 'Moçambique', phoneCode: '258', currency: 'MZN', locale: 'pt-MZ', tz: 'Africa/Maputo' },
] as const;

/** Regioes com cidades e coordenadas reais aproximadas (base para o mapa). */
const REGIONS = [
  { country: 'BR', code: 'BR-MG', name: 'Minas Gerais', cities: [['Belo Horizonte', -19.9167, -43.9345], ['Betim', -19.9678, -44.1983], ['Contagem', -19.9317, -44.0536], ['Uberlândia', -18.9186, -48.2772]] },
  { country: 'BR', code: 'BR-MG-RMBH', name: 'Região Metropolitana de Belo Horizonte', parent: 'BR-MG', cities: [['Nova Lima', -19.9858, -43.8467], ['Sabará', -19.8886, -43.8069]] },
  { country: 'BR', code: 'BR-SP', name: 'São Paulo', cities: [['São Paulo', -23.5505, -46.6333], ['Campinas', -22.9099, -47.0626], ['Santos', -23.9608, -46.3336]] },
  { country: 'BR', code: 'BR-RJ', name: 'Rio de Janeiro', cities: [['Rio de Janeiro', -22.9068, -43.1729], ['Niterói', -22.8832, -43.1034]] },
  { country: 'BR', code: 'BR-BA', name: 'Bahia', cities: [['Salvador', -12.9777, -38.5016], ['Feira de Santana', -12.2664, -38.9663]] },
  { country: 'BR', code: 'BR-PR', name: 'Paraná', cities: [['Curitiba', -25.4284, -49.2733], ['Londrina', -23.3045, -51.1696]] },
  { country: 'BR', code: 'BR-DF', name: 'Distrito Federal', cities: [['Brasília', -15.7939, -47.8828]] },
  { country: 'PT', code: 'PT-11', name: 'Lisboa', cities: [['Lisboa', 38.7223, -9.1393], ['Sintra', 38.8029, -9.3817]] },
  { country: 'PT', code: 'PT-13', name: 'Porto', cities: [['Porto', 41.1579, -8.6291], ['Braga', 41.5454, -8.4265]] },
  { country: 'US', code: 'US-FL', name: 'Florida', cities: [['Orlando', 28.5383, -81.3792], ['Miami', 25.7617, -80.1918]] },
  { country: 'US', code: 'US-MA', name: 'Massachusetts', cities: [['Boston', 42.3601, -71.0589], ['Framingham', 42.2793, -71.4162]] },
  { country: 'AO', code: 'AO-LUA', name: 'Luanda', cities: [['Luanda', -8.839, 13.2894], ['Viana', -8.9035, 13.3749]] },
  { country: 'MZ', code: 'MZ-MPM', name: 'Maputo', cities: [['Maputo', -25.9692, 32.5732], ['Matola', -25.9622, 32.4589]] },
] as const;

const MINISTRY_ROLES = [
  { key: 'SENIOR_PASTOR', name: 'Pastor sênior', rank: 10 },
  { key: 'CAMPUS_PASTOR', name: 'Pastor de campus', rank: 20 },
  { key: 'ASSOCIATE_PASTOR', name: 'Pastor auxiliar', rank: 30 },
  { key: 'YOUTH_PASTOR', name: 'Pastor de jovens', rank: 40 },
  { key: 'MISSIONARY', name: 'Missionário', rank: 50 },
  { key: 'CHURCH_PLANTER', name: 'Plantador de igrejas', rank: 60 },
];

const CARE_TYPES = [
  { key: 'CONVERSATION', name: 'Conversa', icon: 'forum', color: '#0F766E', rank: 1 },
  { key: 'CALL', name: 'Telefonema', icon: 'call', color: '#2563EB', rank: 2 },
  { key: 'MEETING', name: 'Reunião', icon: 'groups', color: '#7C3AED', rank: 3 },
  { key: 'VISIT', name: 'Visita', icon: 'home', color: '#D97706', rank: 4 },
  { key: 'MINISTERIAL', name: 'Acompanhamento ministerial', icon: 'church', color: '#0E7490', rank: 5 },
  { key: 'ADMINISTRATIVE', name: 'Acompanhamento administrativo', icon: 'assignment', color: '#475569', rank: 6 },
  { key: 'OTHER', name: 'Outro', icon: 'more_horiz', color: '#64748B', rank: 7 },
];

const REQUEST_CATEGORIES = [
  { key: 'TALK_LEADERSHIP', name: 'Conversar com a liderança', icon: 'record_voice_over', slaHours: 72 },
  { key: 'CARE', name: 'Acompanhamento', icon: 'handshake', slaHours: 72 },
  { key: 'MINISTERIAL_HELP', name: 'Ajuda ministerial', icon: 'church', slaHours: 120 },
  { key: 'ADMIN_HELP', name: 'Ajuda administrativa', icon: 'assignment', slaHours: 120 },
  { key: 'DOCUMENTATION', name: 'Documentação', icon: 'description', slaHours: 168 },
  { key: 'CREDENTIAL', name: 'Credencial', icon: 'badge', slaHours: 168 },
  { key: 'TRAINING', name: 'Treinamento', icon: 'school', slaHours: 168 },
  { key: 'MISSION', name: 'Missão', icon: 'public', slaHours: 168 },
  { key: 'SUPPORT', name: 'Suporte', icon: 'support_agent', slaHours: 48 },
];

const CARE_SUMMARIES = [
  'Conversa sobre rotina ministerial e família',
  'Alinhamento do planejamento da igreja local',
  'Visita pastoral à família',
  'Acompanhamento da liderança de células',
  'Ligação de acompanhamento mensal',
  'Reunião sobre formação de novos líderes',
  'Conversa sobre descanso e agenda',
  'Acompanhamento administrativo da congregação',
];

/** Biografias curtas, reais para a leitura da interface (sem lorem ipsum). */
const BIOGRAPHIES: Record<string, string[]> = {
  SENIOR_PASTOR: [
    'Serve na formação de líderes e no cuidado das igrejas da região, promovendo unidade, maturidade e cooperação entre os pastores.',
    'Dedica seu ministério à liderança pastoral, ao desenvolvimento de novas comunidades e ao acompanhamento próximo das equipes locais.',
  ],
  CAMPUS_PASTOR: [
    'Acompanha pastores e equipes de uma área da região, ajudando a transformar desafios locais em planos de cuidado e crescimento.',
    'Atua na supervisão pastoral e na integração entre as igrejas, com atenção à saúde dos líderes e à vida das comunidades.',
  ],
  ASSOCIATE_PASTOR: [
    'Atua no cuidado das famílias, na pregação e na organização da vida comunitária, servindo em parceria com a liderança da igreja.',
    'Serve a igreja local com foco em discipulado, visitas pastorais e formação de voluntários para o cuidado de pessoas.',
  ],
  YOUTH_PASTOR: [
    'Desenvolve o ministério com adolescentes e jovens, formando líderes e criando espaços seguros de discipulado e comunhão.',
    'Dedica-se à formação de jovens e ao fortalecimento das famílias, conectando a nova geração à missão da igreja local.',
  ],
  MISSIONARY: [
    'Serve em frentes missionárias e apoia igrejas em formação, com atenção à cultura local, ao discipulado e à capacitação de líderes.',
  ],
  CHURCH_PLANTER: [
    'Trabalha na implantação e no fortalecimento de novas comunidades, reunindo equipes locais e estabelecendo uma rotina saudável de cuidado.',
  ],
};

const CARE_NOTES = [
  'A conversa foi acolhedora e terminou com dois encaminhamentos para a próxima semana.',
  'Foram revisados os desafios da igreja local e combinada uma conversa com a equipe de liderança.',
  'O pastor compartilhou avanços no cuidado das famílias e pediu apoio para organizar a agenda.',
  'Foi identificado um bom momento para retomar o acompanhamento e fortalecer a rotina de descanso.',
];

const REQUEST_DESCRIPTIONS = [
  'Gostaria de conversar sobre os próximos passos para cuidar melhor da equipe da igreja.',
  'Preciso de orientação para atualizar os documentos e manter meu cadastro pastoral em dia.',
  'Solicito apoio para organizar uma atividade de formação com a liderança local.',
  'Quero alinhar uma visita pastoral e os encaminhamentos para a comunidade.',
  'Preciso de ajuda para encontrar uma formação adequada para este momento do ministério.',
];

const CHANNEL_CONTENT = [
  'Confira as orientações, os prazos e os próximos passos para toda a rede pastoral.',
  'Este comunicado reúne as informações principais e os responsáveis por cada encaminhamento.',
  'Uma reflexão para cultivar descanso, presença e cuidado no ritmo do ministério.',
  'Conheça a nova comunidade e ore pelos pastores e famílias que estão iniciando esse trabalho.',
  'Veja a programação, os temas e as informações de participação do encontro.',
  'Uma mensagem breve da liderança para orientar o trabalho pastoral deste semestre.',
  'O manual foi revisado com orientações práticas para o cuidado pastoral cotidiano.',
];

// ---------------------------------------------------------------------------
// Execucao
// ---------------------------------------------------------------------------

async function reset(): Promise<void> {
  const tables = await prisma.$queryRaw<Array<{ tablename: string }>>`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename <> '_prisma_migrations'
  `;
  if (tables.length === 0) return;
  const list = tables.map((t) => `"public"."${t.tablename}"`).join(', ');
  await prisma.$executeRawUnsafe(`TRUNCATE TABLE ${list} RESTART IDENTITY CASCADE`);
}

async function main(): Promise<void> {
  if (process.env.APP_ENV === 'PRODUCTION') {
    throw new Error('Seed de desenvolvimento bloqueado em PRODUCTION.');
  }

  const started = Date.now();
  console.log('> Limpando base...');
  await reset();

  // ---------------- Acesso ----------------
  console.log('> Permissoes e roles...');
  await prisma.permission.createMany({
    data: ALL_PERMISSIONS.map((key) => ({ key, ...splitPermission(key) })),
  });
  const permissions = await prisma.permission.findMany();
  const permIdByKey = new Map(permissions.map((p) => [p.key, p.id]));

  const roleIdByKey = new Map<string, string>();
  for (const [key, def] of Object.entries(ROLE_PERMISSIONS)) {
    const role = await prisma.role.create({
      data: { key, name: def.name, rank: def.rank, isSystem: true },
    });
    roleIdByKey.set(key, role.id);
    await prisma.rolePermission.createMany({
      data: def.permissions.map((k) => ({ roleId: role.id, permissionId: permIdByKey.get(k)! })),
    });
  }

  // ---------------- Geografia ----------------
  console.log('> Geografia...');
  const countryIdByCode = new Map<string, string>();
  for (const c of COUNTRIES) {
    const created = await prisma.country.create({
      data: {
        code: c.code,
        code3: c.code3,
        name: c.name,
        phoneCode: c.phoneCode,
        currency: c.currency,
        defaultLocale: c.locale,
        defaultTimezone: c.tz,
      },
    });
    countryIdByCode.set(c.code, created.id);
  }

  const regionIdByCode = new Map<string, string>();
  for (const r of REGIONS) {
    const parentCode = 'parent' in r ? r.parent : undefined;
    const created = await prisma.region.create({
      data: {
        countryId: countryIdByCode.get(r.country)!,
        parentId: parentCode ? regionIdByCode.get(parentCode) : undefined,
        code: r.code,
        name: r.name,
        level: parentCode ? 1 : 0,
      },
    });
    regionIdByCode.set(r.code, created.id);
  }

  await prisma.ministryRole.createMany({ data: MINISTRY_ROLES });
  const ministryRoles = await prisma.ministryRole.findMany();
  const ministryRoleId = (key: string) => ministryRoles.find((m) => m.key === key)!.id;

  // ---------------- Igrejas ----------------
  console.log('> Igrejas...');
  type ChurchSeed = { id: string; regionCode: string; countryCode: string; city: string; tz: string };
  const churches: ChurchSeed[] = [];
  let churchSeq = 1;

  // Distribui 30 igrejas: sede por região + campus/congregações nas maiores.
  const extraPerRegion: Record<string, number> = { 'BR-MG': 4, 'BR-SP': 3, 'BR-RJ': 2, 'BR-BA': 1, 'BR-PR': 1, 'PT-11': 1, 'US-FL': 1, 'AO-LUA': 1, 'BR-MG-RMBH': 1, 'MZ-MPM': 1, 'US-MA': 1 };
  const mainChurchNames: Record<string, string> = {
    'BR-MG': 'Igreja Monte Carmo',
    'BR-SP': 'Igreja Esperança Viva',
    'BR-RJ': 'Igreja da Ponte',
    'BR-BA': 'Igreja Vida Plena',
    'BR-PR': 'Comunidade da Graça',
    'BR-DF': 'Comunidade do Caminho',
    'PT-11': 'Igreja Esperança de Lisboa',
    'PT-13': 'Igreja Porto da Graça',
    'US-FL': 'Igreja Vida em Orlando',
    'US-MA': 'Comunidade Brasileira de Boston',
    'AO-LUA': 'Igreja Fonte de Vida',
    'MZ-MPM': 'Igreja Caminho de Maputo',
  };
  for (const r of REGIONS) {
    const country = COUNTRIES.find((c) => c.code === r.country)!;
    const total = 1 + (extraPerRegion[r.code] ?? 0);
    let mainId: string | undefined;
    const mainName = mainChurchNames[r.code] ?? `Igreja de ${r.cities[0][0]}`;
    for (let i = 0; i < total; i++) {
      const [city, lat, lng] = r.cities[i % r.cities.length];
      const type = i === 0 ? ChurchType.MAIN : i % 3 === 0 ? ChurchType.CONGREGATION : ChurchType.CAMPUS;
      const code = `${r.country}-${String(churchSeq++).padStart(3, '0')}`;
      const created = await prisma.church.create({
        data: {
          code,
          name: type === ChurchType.MAIN
            ? mainName
            : `${mainName} · ${type === ChurchType.CAMPUS ? 'Campus' : 'Congregação'} ${i}`,
          type,
          status: i === total - 1 && r.code === 'BR-BA' ? ChurchStatus.PLANTING : ChurchStatus.ACTIVE,
          parentId: type === ChurchType.MAIN ? undefined : mainId,
          countryId: countryIdByCode.get(r.country)!,
          regionId: regionIdByCode.get(r.code)!,
          city,
          address: faker.location.streetAddress(),
          postalCode: faker.location.zipCode(),
          latitude: new Prisma.Decimal((lat + faker.number.float({ min: -0.04, max: 0.04 })).toFixed(7)),
          longitude: new Prisma.Decimal((lng + faker.number.float({ min: -0.04, max: 0.04 })).toFixed(7)),
          phoneE164: `+${country.phoneCode}${faker.string.numeric(r.country === 'BR' ? 11 : 9)}`,
          email: `contato.${code.toLowerCase()}@igreja.org`,
          timezone: country.tz,
          foundedAt: faker.date.between({ from: '1985-01-01', to: '2023-12-31' }),
          membersEstimate: faker.number.int({ min: 80, max: 4200 }),
        },
      });
      if (type === ChurchType.MAIN) mainId = created.id;
      churches.push({ id: created.id, regionCode: r.code, countryCode: r.country, city, tz: country.tz });
    }
  }

  // ---------------- Pastores + hierarquia ----------------
  console.log('> Pastores e hierarquia...');
  type PastorSeed = { id: string; name: string; churchId: string; countryCode: string; regionCode: string };
  const pastors: PastorSeed[] = [];

  const createPastor = async (
    church: ChurchSeed,
    opts: {
      first?: string;
      last?: string;
      female?: boolean;
      roleKey: string;
      status?: PastorStatus;
      title?: string;
      biography?: string;
    },
  ): Promise<PastorSeed> => {
    const female = opts.female ?? faker.datatype.boolean({ probability: 0.28 });
    const first = opts.first ?? faker.person.firstName(female ? 'female' : 'male');
    const last = opts.last ?? `${faker.person.lastName()} ${faker.person.lastName()}`;
    const prefix = female ? 'Pra.' : 'Pr.';
    const country = COUNTRIES.find((c) => c.code === church.countryCode)!;
    const married = faker.datatype.boolean({ probability: 0.8 });
    const created = await prisma.pastor.create({
      data: {
        firstName: first,
        lastName: last,
        pastoralName: `${prefix} ${first} ${last.split(' ')[0]}`,
        // Sem foto externa: o app usa iniciais. Evita dependencia de rede e bloqueio de CORS.
        photoUrl: null,
        email: faker.internet.email({ firstName: first, lastName: last.split(' ')[0], provider: 'pastoral.dev' }).toLowerCase(),
        phoneE164: `+${country.phoneCode}${faker.string.numeric(church.countryCode === 'BR' ? 11 : 9)}`,
        whatsappE164: `+${country.phoneCode}${faker.string.numeric(church.countryCode === 'BR' ? 11 : 9)}`,
        birthDate: faker.date.birthdate({ min: 28, max: 68, mode: 'age' }),
        maritalStatus: married ? MaritalStatus.MARRIED : pick([MaritalStatus.SINGLE, MaritalStatus.WIDOWED]),
        spouseName: married ? faker.person.firstName(female ? 'male' : 'female') : undefined,
        countryId: countryIdByCode.get(church.countryCode)!,
        regionId: regionIdByCode.get(church.regionCode)!,
        city: church.city,
        address: faker.location.streetAddress(),
        locale: country.locale,
        timezone: country.tz,
        churchId: church.id,
        ministryRoleId: ministryRoleId(opts.roleKey),
        ministryTitle: opts.title ?? (female ? 'Pastora' : 'Pastor'),
        joinedAt: faker.date.between({ from: '1995-01-01', to: '2022-12-31' }),
        ordainedAt: faker.date.between({ from: '2000-01-01', to: '2024-06-30' }),
        status: opts.status ?? PastorStatus.ACTIVE,
        biography: opts.biography ?? pick(BIOGRAPHIES[opts.roleKey] ?? BIOGRAPHIES.ASSOCIATE_PASTOR),
      },
    });
    const seed = { id: created.id, name: created.pastoralName, churchId: church.id, countryCode: church.countryCode, regionCode: church.regionCode };
    pastors.push(seed);
    return seed;
  };

  const edges: Array<[string, string]> = [];
  const link = (supervisor: PastorSeed, subordinate: PastorSeed) => edges.push([supervisor.id, subordinate.id]);
  const mainChurchOf = (regionCode: string) => churches.find((c) => c.regionCode === regionCode)!;

  // Topo
  const globalLeader = await createPastor(mainChurchOf('BR-MG'), {
    first: 'Samuel',
    last: 'Andrade Rocha',
    female: false,
    roleKey: 'SENIOR_PASTOR',
    title: 'Bispo',
    biography: 'Coordena a visão pastoral da rede e acompanha as lideranças nacionais, promovendo unidade e cuidado entre as igrejas.',
  });

  // Lideres nacionais
  const nationalBR = await createPastor(mainChurchOf('BR-SP'), {
    first: 'Marcos',
    last: 'Oliveira Prado',
    female: false,
    roleKey: 'SENIOR_PASTOR',
    title: 'Líder nacional',
    biography: 'Lidera o trabalho pastoral no Brasil, apoiando as lideranças regionais e fortalecendo a cooperação entre as igrejas.',
  });
  const nationalIntl = await createPastor(mainChurchOf('PT-11'), {
    first: 'Ricardo',
    last: 'Figueiredo Costa',
    female: false,
    roleKey: 'SENIOR_PASTOR',
    title: 'Líder nacional',
    biography: 'Acompanha as comunidades de língua portuguesa fora do Brasil e promove formação para pastores e líderes locais.',
  });
  link(globalLeader, nationalBR);
  link(globalLeader, nationalIntl);

  const supervisorsByRegion = new Map<string, PastorSeed[]>();
  let regionalMG: PastorSeed | undefined;
  let supervisorMG: PastorSeed | undefined;
  let pastorMG: PastorSeed | undefined;

  for (const r of REGIONS) {
    if (r.code === 'BR-MG-RMBH') continue; // coberta pelo regional de MG
    const regionChurches = churches.filter((c) => c.regionCode === r.code || (r.code === 'BR-MG' && c.regionCode === 'BR-MG-RMBH'));
    const national = r.country === 'BR' ? nationalBR : nationalIntl;

    const regional = await createPastor(regionChurches[0], {
      roleKey: 'SENIOR_PASTOR',
      title: 'Líder regional',
      ...(r.code === 'BR-MG'
        ? {
            first: 'Carlos',
            last: 'Mendes Duarte',
            female: false,
            biography: 'Lidera a região de Minas Gerais com foco no cuidado dos pastores, na formação de líderes e na saúde das igrejas locais.',
          }
        : {}),
    });
    link(national, regional);
    if (r.code === 'BR-MG') regionalMG = regional;

    // O exemplo visual usa duas frentes de supervisão em Minas Gerais.
    const supervisorCount = r.code === 'BR-MG' ? 2 : r.code === 'BR-SP' ? 2 : 1;
    const sups: PastorSeed[] = [];
    for (let s = 0; s < supervisorCount; s++) {
      const sup = await createPastor(regionChurches[(s + 1) % regionChurches.length], {
        roleKey: 'CAMPUS_PASTOR',
        title: 'Supervisor',
        ...(r.code === 'BR-MG' && s === 0
          ? { first: 'Paulo', last: 'Ribeiro Lima', female: false }
          : r.code === 'BR-MG' && s === 1
          ? { first: 'Renata', last: 'Almeida Costa', female: true }
          : {}),
      });
      link(regional, sup);
      sups.push(sup);
      if (r.code === 'BR-MG' && s === 0) supervisorMG = sup;
    }
    supervisorsByRegion.set(r.code, sups);
  }

  // Pastores de base ate completar 100+.
  const baseRegions = REGIONS.filter((r) => r.code !== 'BR-MG-RMBH').map((r) => r.code);
  const weights: Record<string, number> = { 'BR-MG': 18, 'BR-SP': 14, 'BR-RJ': 8, 'BR-BA': 6, 'BR-PR': 6, 'BR-DF': 4, 'PT-11': 5, 'PT-13': 4, 'US-FL': 5, 'US-MA': 3, 'AO-LUA': 4, 'MZ-MPM': 3 };
  const statuses = [PastorStatus.ACTIVE, PastorStatus.ACTIVE, PastorStatus.ACTIVE, PastorStatus.ACTIVE, PastorStatus.ACTIVE, PastorStatus.IN_TRAINING, PastorStatus.MISSIONARY, PastorStatus.ON_LEAVE];
  const demoPastors = [
    {
      first: 'João',
      last: 'Silva Araújo',
      female: false,
      roleKey: 'ASSOCIATE_PASTOR',
      title: 'Pastor titular',
      biography: 'Serve na Igreja Monte Carmo com foco em pregação, discipulado e cuidado das famílias da comunidade.',
    },
    {
      first: 'Ana',
      last: 'Souza Oliveira',
      female: true,
      roleKey: 'ASSOCIATE_PASTOR',
      title: 'Pastora auxiliar',
      biography: 'Atua no discipulado e no cuidado de mulheres e famílias, formando voluntários para a vida comunitária.',
    },
    {
      first: 'Marcos',
      last: 'Lima Ferreira',
      female: false,
      roleKey: 'YOUTH_PASTOR',
      title: 'Pastor de jovens',
      biography: 'Desenvolve o ministério com adolescentes e jovens, fortalecendo o discipulado e a formação de novas lideranças.',
    },
    {
      first: 'Eduardo',
      last: 'Costa Nogueira',
      female: false,
      roleKey: 'ASSOCIATE_PASTOR',
      title: 'Pastor auxiliar',
      biography: 'Serve no acompanhamento de pequenos grupos e na integração de novos membros à igreja local.',
    },
  ];

  for (const code of baseRegions) {
    const sups = supervisorsByRegion.get(code)!;
    const regionChurches = churches.filter((c) => c.regionCode === code || (code === 'BR-MG' && c.regionCode === 'BR-MG-RMBH'));
    for (let i = 0; i < weights[code]; i++) {
      const demo = code === 'BR-MG' && i < demoPastors.length
          ? demoPastors[i]
          : null;
      const p = await createPastor(regionChurches[i % regionChurches.length], {
        roleKey: demo?.roleKey ?? pick(['ASSOCIATE_PASTOR', 'YOUTH_PASTOR', 'CAMPUS_PASTOR', 'MISSIONARY', 'CHURCH_PLANTER']),
        status: demo != null ? PastorStatus.ACTIVE : pick(statuses),
        ...(demo ?? {}),
      });
      const supervisorIndex = code === 'BR-MG' && i < demoPastors.length
          ? i < 2
              ? 0
              : 1
          : i % sups.length;
      link(sups[supervisorIndex], p);
      if (demo?.first === 'João') pastorMG = p;
    }
  }

  // Pastor fora da rede de MG, usado no teste de 403.
  await prisma.pastoralRelationship.createMany({
    data: edges.map(([supervisorId, subordinateId]) => ({ supervisorId, subordinateId, startedAt: daysAgo(faker.number.int({ min: 60, max: 1500 })) })),
  });

  // Lideres de igreja: primeiro pastor de cada igreja sede.
  for (const church of churches) {
    const lead = pastors.find((p) => p.churchId === church.id);
    if (lead) {
      await prisma.church.update({ where: { id: church.id }, data: { leadPastorId: lead.id } }).catch(() => undefined);
    }
  }

  // Closure a partir das arestas (mesma SQL do HierarchyService.rebuildClosure).
  await prisma.$executeRawUnsafe(`
    INSERT INTO pastoral_closure (ancestor_id, descendant_id, depth)
    WITH RECURSIVE edges AS (
      SELECT supervisor_id AS parent, subordinate_id AS child
      FROM pastoral_relationships WHERE is_active = true AND type = 'SUPERVISION'
    ),
    paths AS (
      SELECT p.id AS ancestor_id, p.id AS descendant_id, 0 AS depth FROM pastors p WHERE p.deleted_at IS NULL
      UNION ALL
      SELECT paths.ancestor_id, e.child, paths.depth + 1 FROM paths JOIN edges e ON e.parent = paths.descendant_id WHERE paths.depth < 32
    )
    SELECT ancestor_id, descendant_id, MIN(depth) FROM paths GROUP BY ancestor_id, descendant_id
  `);

  // ---------------- Usuarios de teste ----------------
  console.log('> Usuarios de teste...');
  const password = process.env.SEED_DEFAULT_PASSWORD ?? 'Pastoral@2025';
  const passwordHash = await hash(password, { algorithm: Algorithm.Argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 });

  const createUser = async (
    email: string,
    firstName: string,
    lastName: string,
    roleKey: string,
    scopes: Array<{ type: ScopeType; refId?: string }>,
    pastor?: PastorSeed,
  ) => {
    const user = await prisma.user.create({
      data: { email, firstName, lastName, passwordHash, status: UserStatus.ACTIVE, locale: 'pt-BR', timezone: 'America/Sao_Paulo' },
    });
    await prisma.userRole.create({ data: { userId: user.id, roleId: roleIdByKey.get(roleKey)! } });
    await prisma.userScope.createMany({ data: scopes.map((s) => ({ userId: user.id, type: s.type, refId: s.refId ?? null })) });
    if (pastor) await prisma.pastor.update({ where: { id: pastor.id }, data: { userId: user.id } });
    return user;
  };

  const admin = await createUser('admin@pastoral.dev', 'Samuel', 'Andrade', SYSTEM_ROLES.GLOBAL_ADMIN, [{ type: ScopeType.GLOBAL }], globalLeader);
  const national = await createUser('nacional@pastoral.dev', 'Marcos', 'Oliveira', SYSTEM_ROLES.NATIONAL_LEADER, [
    { type: ScopeType.COUNTRY, refId: countryIdByCode.get('BR') },
    { type: ScopeType.SUBTREE },
  ], nationalBR);
  const regional = await createUser('regional@pastoral.dev', 'Carlos', 'Mendes', SYSTEM_ROLES.REGIONAL_LEADER, [
    { type: ScopeType.REGION, refId: regionIdByCode.get('BR-MG') },
    { type: ScopeType.SUBTREE },
  ], regionalMG);
  const supervisor = await createUser('supervisor@pastoral.dev', 'Paulo', 'Ribeiro', SYSTEM_ROLES.SUPERVISOR, [{ type: ScopeType.SUBTREE }], supervisorMG);
  const pastorUser = await createUser('pastor@pastoral.dev', 'João', 'Silva', SYSTEM_ROLES.PASTOR, [{ type: ScopeType.SELF }], pastorMG);
  const secretary = await createUser('secretaria@pastoral.dev', 'Luciana', 'Campos', SYSTEM_ROLES.SECRETARY, [{ type: ScopeType.COUNTRY, refId: countryIdByCode.get('BR') }]);
  const leaders = [admin, national, regional, supervisor];

  // ---------------- Cuidado pastoral ----------------
  console.log('> Acompanhamentos...');
  await prisma.pastoralCareType.createMany({ data: CARE_TYPES });
  const careTypes = await prisma.pastoralCareType.findMany();

  const supervisorOf = new Map(edges.map(([sup, sub]) => [sub, sup]));
  const userByPastor = new Map([
    [globalLeader.id, admin.id], [nationalBR.id, national.id], [regionalMG!.id, regional.id], [supervisorMG!.id, supervisor.id],
  ]);

  const cares: Prisma.PastoralCareCreateManyInput[] = [];
  pastors.forEach((p, idx) => {
    // ~12% nunca acompanhados; parte com >30 dias: indicadores do dashboard ficam realistas.
    if (idx % 8 === 5) return;
    const count = faker.number.int({ min: 1, max: 5 });
    const newestDaysAgo = idx % 5 === 0 ? faker.number.int({ min: 35, max: 90 }) : faker.number.int({ min: 1, max: 28 });
    const performer = userByPastor.get(supervisorOf.get(p.id) ?? '') ?? pick(leaders).id;
    for (let c = 0; c < count; c++) {
      const occurred = daysAgo(newestDaysAgo + c * faker.number.int({ min: 12, max: 40 }));
      const isLatest = c === 0;
      cares.push({
        pastorId: p.id,
        performedById: performer,
        createdById: performer,
        typeId: pick(careTypes).id,
        occurredAt: occurred,
        status: CareStatus.DONE,
        summary: pick(CARE_SUMMARIES),
        notes: pick(CARE_NOTES),
        nextAction: isLatest ? 'Retomar a conversa e verificar os encaminhamentos' : undefined,
        nextCareAt: isLatest && idx % 3 !== 0 ? daysAhead(faker.number.int({ min: 0, max: 21 })) : undefined,
        confidentiality: c % 7 === 3 ? Confidentiality.CONFIDENTIAL : c % 5 === 2 ? Confidentiality.RESTRICTED : Confidentiality.NORMAL,
        durationMinutes: faker.number.int({ min: 20, max: 90 }),
        location: pick(['Presencial', 'Videochamada', 'Telefone', 'Igreja local']),
      });
    }
  });
  await prisma.pastoralCare.createMany({ data: cares });

  await prisma.$executeRawUnsafe(`
    UPDATE pastors p SET
      last_care_at = (SELECT max(occurred_at) FROM pastoral_cares c WHERE c.pastor_id = p.id AND c.deleted_at IS NULL AND c.status = 'DONE' AND c.occurred_at <= now()),
      next_care_at = (SELECT min(next_care_at) FROM pastoral_cares c WHERE c.pastor_id = p.id AND c.deleted_at IS NULL AND c.next_care_at >= now())
  `);

  // ---------------- Solicitacoes ----------------
  console.log('> Solicitacoes...');
  await prisma.requestCategory.createMany({ data: REQUEST_CATEGORIES.map((c, i) => ({ ...c, rank: i })) });
  const categories = await prisma.requestCategory.findMany();
  const reqStatuses = [RequestStatus.OPEN, RequestStatus.OPEN, RequestStatus.IN_PROGRESS, RequestStatus.WAITING, RequestStatus.RESOLVED, RequestStatus.CLOSED];
  const requesters = [pastorUser, supervisor, regional];
  for (let i = 0; i < 24; i++) {
    const requester = requesters[i % requesters.length];
    const reqPastor = requester.id === pastorUser.id ? pastorMG! : requester.id === supervisor.id ? supervisorMG! : pick(pastors);
    const status = pick(reqStatuses);
    const created = daysAgo(faker.number.int({ min: 0, max: 45 }));
    const request = await prisma.request.create({
      data: {
        categoryId: pick(categories).id,
        requesterId: requester.id,
        pastorId: reqPastor.id,
        assigneeId: status === RequestStatus.OPEN ? undefined : regional.id,
        subject: pick(['Conversa com a liderança', 'Atualização da credencial', 'Apoio para evento local', 'Documentação da igreja', 'Inscrição em treinamento', 'Apoio em missão']),
        description: pick(REQUEST_DESCRIPTIONS),
        status,
        priority: pick([RequestPriority.NORMAL, RequestPriority.NORMAL, RequestPriority.HIGH, RequestPriority.LOW, RequestPriority.URGENT]),
        resolvedAt: status === RequestStatus.RESOLVED || status === RequestStatus.CLOSED ? daysAgo(1) : undefined,
        closedAt: status === RequestStatus.CLOSED ? daysAgo(0) : undefined,
        resolution: status === RequestStatus.RESOLVED || status === RequestStatus.CLOSED ? 'Encaminhamento concluído com o solicitante.' : undefined,
        createdAt: created,
      },
    });
    await prisma.requestTimelineEntry.createMany({
      data: [
        { requestId: request.id, authorId: requester.id, kind: 'SYSTEM', message: 'Solicitação aberta', createdAt: created },
        ...(status !== RequestStatus.OPEN
          ? [
              { requestId: request.id, authorId: regional.id, kind: 'ASSIGNMENT', message: 'Atribuída para acompanhamento', metadata: { to: regional.id }, createdAt: new Date(created.getTime() + 3_600_000) },
              { requestId: request.id, authorId: regional.id, kind: 'COMMENT', message: 'Vamos conversar ainda esta semana.', createdAt: new Date(created.getTime() + 7_200_000) },
            ]
          : []),
      ],
    });
  }

  // ---------------- Canal ----------------
  console.log('> Canal...');
  const allUserIds = [admin, national, regional, supervisor, pastorUser, secretary].map((u) => u.id);
  const posts = [
    { type: PostType.URGENT, title: 'Encontro Geral dos Pastores 2026', summary: 'Inscrições abertas até 20/09.', pinned: true, ack: true },
    { type: PostType.ANNOUNCEMENT, title: 'Nova política de credenciais', summary: 'Credenciais passam a ter validação por QR Code.', pinned: false, ack: true },
    { type: PostType.DEVOTIONAL, title: 'Devocional: descanso no ministério', summary: 'Uma reflexão sobre Marcos 6:31.', pinned: false, ack: false },
    { type: PostType.NEWS, title: 'Nova igreja plantada em Salvador', summary: 'Celebramos a abertura da congregação.', pinned: false, ack: false },
    { type: PostType.EVENT, title: 'Conferência de liderança — Lisboa', summary: 'Evento internacional em novembro.', pinned: false, ack: false },
    { type: PostType.VIDEO, title: 'Mensagem do Bispo Samuel', summary: 'Vídeo com orientações para o semestre.', pinned: false, ack: false },
    { type: PostType.DOCUMENT, title: 'Manual de cuidado pastoral', summary: 'Documento de referência atualizado.', pinned: false, ack: false },
  ];
  for (const [i, p] of posts.entries()) {
    const post = await prisma.channelPost.create({
      data: {
        authorId: i % 2 === 0 ? admin.id : national.id,
        type: p.type,
        status: PostStatus.PUBLISHED,
        title: p.title,
        summary: p.summary,
        content: CHANNEL_CONTENT[i],
        videoUrl: p.type === PostType.VIDEO ? 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' : undefined,
        isPinned: p.pinned,
        requiresAck: p.ack,
        publishedAt: daysAgo(i * 3),
        audienceCount: allUserIds.length,
        readCount: i === 0 ? 0 : Math.min(allUserIds.length, 3 + i),
        audiences: { create: [{ type: AudienceType.ALL }] },
      },
    });
    if (i > 0) {
      await prisma.postRead.createMany({
        data: allUserIds.filter((u) => u !== pastorUser.id || i > 3).map((userId) => ({ postId: post.id, userId, readAt: daysAgo(i) })),
        skipDuplicates: true,
      });
    }
  }

  // ---------------- Documentos (arquivos reais no storage local) ----------------
  console.log('> Documentos e credenciais...');
  const storageRoot = resolve(process.cwd(), process.env.STORAGE_LOCAL_PATH ?? './.storage');
  const pdf = Buffer.from(
    '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj 4 0 obj<</Length 58>>stream\nBT /F1 18 Tf 72 760 Td (Plataforma Pastoral - documento) Tj ET\nendstream endobj 5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n',
  );
  const docPastors = [pastorMG!, supervisorMG!, regionalMG!, ...pastors.slice(10, 40)];
  for (const [i, p] of docPastors.entries()) {
    const category = pick([DocumentCategory.CERTIFICATE, DocumentCategory.MINISTERIAL_DOCUMENT, DocumentCategory.IDENTIFICATION, DocumentCategory.AUTHORIZATION, DocumentCategory.PASTORAL_DOCUMENT]);
    const key = `pastors/${p.id}/documents/${faker.string.uuid()}-documento.pdf`;
    mkdirSync(dirname(join(storageRoot, key)), { recursive: true });
    writeFileSync(join(storageRoot, key), pdf);
    const expiresIn = i % 4 === 0 ? faker.number.int({ min: 5, max: 55 }) : faker.number.int({ min: 120, max: 900 });
    await prisma.document.create({
      data: {
        category,
        title: {
          CERTIFICATE: 'Certificado de ordenação',
          MINISTERIAL_DOCUMENT: 'Carta de apresentação ministerial',
          IDENTIFICATION: 'Documento de identificação',
          AUTHORIZATION: 'Autorização para celebração',
          PASTORAL_DOCUMENT: 'Registro pastoral',
          OTHER: 'Documento',
        }[category],
        storageKey: key,
        storageBucket: 'local',
        mimeType: 'application/pdf',
        sizeBytes: BigInt(pdf.length),
        visibility: DocumentVisibility.SUPERVISION_CHAIN,
        confidentiality: category === DocumentCategory.IDENTIFICATION ? Confidentiality.RESTRICTED : Confidentiality.NORMAL,
        issuedAt: daysAgo(faker.number.int({ min: 60, max: 900 })),
        expiresAt: daysAhead(expiresIn),
        pastorId: p.id,
        uploadedById: secretary.id,
      },
    });
  }

  let credSeq = 1;
  for (const p of pastors.slice(0, 70)) {
    const expired = credSeq % 17 === 0;
    await prisma.credential.create({
      data: {
        number: `PP-2026-${String(credSeq++).padStart(6, '0')}`,
        pastorId: p.id,
        type: pick([CredentialType.MINISTERIAL, CredentialType.MINISTERIAL, CredentialType.ORDINATION, CredentialType.MISSIONARY]),
        status: expired ? CredentialStatus.EXPIRED : CredentialStatus.ACTIVE,
        issuedAt: daysAgo(faker.number.int({ min: 400, max: 700 })),
        expiresAt: expired ? daysAgo(10) : daysAhead(faker.number.int({ min: 90, max: 700 })),
        verificationToken: token(),
        issuedById: secretary.id,
      },
    });
  }

  // ---------------- Agenda ----------------
  console.log('> Agenda...');
  const eventDescriptions: Record<string, string> = {
    'Acompanhamento com Pr. João': 'Conversa de cuidado e revisão dos próximos encaminhamentos do ministério.',
    'Reunião de supervisores de MG': 'Encontro on-line para alinhar o cuidado dos pastores e os próximos passos da região.',
    'Visita à Igreja Betim': 'Visita à equipe local para conhecer os projetos e apoiar a liderança da comunidade.',
    'Treinamento de cuidado pastoral': 'Formação prática sobre escuta, acompanhamento e encaminhamentos pastorais.',
    'Encontro Geral dos Pastores': 'Momento de comunhão, alinhamento e celebração com toda a rede pastoral.',
    'Culto de celebração': 'Celebração comunitária com a equipe e as famílias da igreja local.',
    'Conferência de liderança — Lisboa': 'Encontro internacional para compartilhar experiências e fortalecer lideranças.',
    'Viagem missionária a Luanda': 'Viagem de apoio à equipe local e formação de novos líderes em Luanda.',
    'Acompanhamento com Pra. Ana': 'Conversa de cuidado sobre a rotina ministerial e o desenvolvimento da equipe.',
    'Curso de liderança de células': 'Curso on-line para formar líderes de pequenos grupos e fortalecer o discipulado.',
  };
  const eventDefs: Array<{ type: EventType; scope: EventScopeType; title: string; inDays: number; hour: number; hours: number; ref?: string; online?: boolean }> = [
    { type: EventType.CARE_MEETING, scope: EventScopeType.INDIVIDUAL, title: 'Acompanhamento com Pr. João', inDays: 0, hour: 17, hours: 1 },
    { type: EventType.MEETING, scope: EventScopeType.REGION, title: 'Reunião de supervisores de MG', inDays: 2, hour: 19, hours: 2, ref: regionIdByCode.get('BR-MG'), online: true },
    { type: EventType.VISIT, scope: EventScopeType.INDIVIDUAL, title: 'Visita à Igreja Betim', inDays: 4, hour: 13, hours: 3 },
    { type: EventType.TRAINING, scope: EventScopeType.COUNTRY, title: 'Treinamento de cuidado pastoral', inDays: 7, hour: 12, hours: 4, ref: countryIdByCode.get('BR') },
    { type: EventType.CONGRESS, scope: EventScopeType.GLOBAL, title: 'Encontro Geral dos Pastores', inDays: 14, hour: 22, hours: 3 },
    { type: EventType.SERVICE, scope: EventScopeType.CHURCH, title: 'Culto de celebração', inDays: 3, hour: 19, hours: 2, ref: churches[0].id },
    { type: EventType.CONFERENCE, scope: EventScopeType.GLOBAL, title: 'Conferência de liderança — Lisboa', inDays: 60, hour: 9, hours: 8 },
    { type: EventType.MISSION, scope: EventScopeType.COUNTRY, title: 'Viagem missionária a Luanda', inDays: 30, hour: 11, hours: 72, ref: countryIdByCode.get('AO') },
    { type: EventType.CARE_MEETING, scope: EventScopeType.INDIVIDUAL, title: 'Acompanhamento com Pra. Ana', inDays: 1, hour: 12, hours: 1 },
    { type: EventType.COURSE, scope: EventScopeType.REGION, title: 'Curso de liderança de células', inDays: 10, hour: 19, hours: 2, ref: regionIdByCode.get('BR-SP'), online: true },
  ];
  for (const e of eventDefs) {
    const start = new Date(new Date(now + e.inDays * DAY).setUTCHours(e.hour, 0, 0, 0));
    const event = await prisma.event.create({
      data: {
        type: e.type,
        scope: e.scope,
        scopeRefId: e.ref,
        title: e.title,
        description: eventDescriptions[e.title] ?? 'Atividade da rede pastoral.',
        location: e.online ? undefined : pick(['Igreja sede', 'Sala de reuniões', 'Auditório principal']),
        isOnline: e.online ?? false,
        meetingUrl: e.online ? 'https://meet.google.com/abc-defg-hij' : undefined,
        startsAt: start,
        endsAt: new Date(start.getTime() + e.hours * 3_600_000),
        churchId: e.scope === EventScopeType.CHURCH ? e.ref : undefined,
        organizerId: e.scope === EventScopeType.INDIVIDUAL ? supervisor.id : regional.id,
      },
    });
    await prisma.eventParticipant.createMany({
      data: [
        { eventId: event.id, userId: supervisor.id },
        { eventId: event.id, userId: pastorUser.id, pastorId: pastorMG!.id },
        { eventId: event.id, userId: regional.id },
      ],
      skipDuplicates: true,
    });
  }

  // ---------------- Formacao ----------------
  console.log('> Formacao...');
  const trainings = [
    { code: 'CP-101', title: 'Fundamentos do cuidado pastoral', kind: TrainingKind.COURSE, mandatory: true, modules: 5 },
    { code: 'LD-201', title: 'Liderança de líderes', kind: TrainingKind.TRACK, mandatory: false, modules: 6 },
    { code: 'AD-110', title: 'Gestão administrativa da igreja', kind: TrainingKind.TRAINING, mandatory: true, modules: 4 },
    { code: 'MS-150', title: 'Missões transculturais', kind: TrainingKind.WORKSHOP, mandatory: false, modules: 3 },
  ];
  const trainingSummaries: Record<string, string> = {
    'CP-101': 'Princípios práticos para ouvir, acompanhar e encaminhar pessoas com responsabilidade.',
    'LD-201': 'Ferramentas para desenvolver líderes saudáveis e multiplicar o cuidado na igreja.',
    'AD-110': 'Rotinas essenciais para organizar equipes, recursos e processos da igreja local.',
    'MS-150': 'Fundamentos para servir em diferentes culturas com respeito, presença e sensibilidade.',
  };
  const trainingDescriptions: Record<string, string> = {
    'CP-101': 'Uma formação introdutória para pastores e líderes que desejam construir uma rotina consistente de cuidado pastoral.',
    'LD-201': 'Uma trilha de desenvolvimento para quem acompanha outros líderes e precisa cultivar clareza, limites e encorajamento.',
    'AD-110': 'Conteúdo aplicado à administração responsável da igreja, com foco em planejamento e prestação de contas.',
    'MS-150': 'Uma oficina para preparar equipes que atuam em contextos culturais diferentes do seu contexto de origem.',
  };
  const moduleTopics: Record<string, string[]> = {
    'CP-101': ['A escuta que acolhe', 'Limites do cuidado', 'Plano de acompanhamento', 'Encaminhamentos responsáveis', 'Cuidado de quem cuida'],
    'LD-201': ['Liderança servidora', 'Conversas de desenvolvimento', 'Delegação saudável', 'Conflitos e reconciliação', 'Formação de equipes', 'Multiplicação de líderes'],
    'AD-110': ['Planejamento anual', 'Organização financeira', 'Gestão de voluntários', 'Comunicação e registros'],
    'MS-150': ['Presença intercultural', 'Parcerias locais', 'Discipulado contextualizado'],
  };
  for (const t of trainings) {
    const training = await prisma.training.create({
      data: {
        code: t.code,
        kind: t.kind,
        status: TrainingStatus.PUBLISHED,
        title: t.title,
        summary: trainingSummaries[t.code],
        description: trainingDescriptions[t.code],
        workloadMinutes: t.modules * 45,
        isMandatory: t.mandatory,
        modules: {
          create: Array.from({ length: t.modules }, (_, i) => ({
            title: `Módulo ${i + 1}: ${moduleTopics[t.code][i]}`,
            description: `Neste módulo, você vai praticar ${moduleTopics[t.code][i].toLowerCase()}.`,
            contentType: pick(['VIDEO', 'PDF', 'TEXT']),
            contentBody: `Material de apoio do módulo ${i + 1}, com orientações, perguntas para reflexão e uma atividade prática.`,
            durationMinutes: 45,
            position: i + 1,
          })),
        },
      },
      include: { modules: true },
    });
    // Dedup: os pastores de teste podem cair tambem na fatia (unique training_id+pastor_id).
    const enrolled = [...new Map([pastorMG!, supervisorMG!, regionalMG!, ...pastors.slice(20, 55)].map((p) => [p.id, p])).values()];
    for (const [i, p] of enrolled.entries()) {
      const done = (i * 7 + t.modules) % (t.modules + 1);
      const pct = Math.round((done / t.modules) * 100);
      await prisma.trainingEnrollment.create({
        data: {
          trainingId: training.id,
          pastorId: p.id,
          status: pct === 100 ? EnrollmentStatus.COMPLETED : pct > 0 ? EnrollmentStatus.IN_PROGRESS : EnrollmentStatus.ENROLLED,
          startedAt: pct > 0 ? daysAgo(40) : undefined,
          completedAt: pct === 100 ? daysAgo(3) : undefined,
          dueAt: t.mandatory ? daysAhead(i % 3 === 0 ? -5 : 30) : undefined,
          progressPct: pct,
          progress: {
            create: training.modules.slice(0, done).map((m) => ({ moduleId: m.id, completed: true, completedAt: daysAgo(5), secondsSpent: 2400 })),
          },
          ...(pct === 100
            ? { certificate: { create: { number: `CERT-2026-${faker.string.numeric(6)}`, verificationToken: token() } } }
            : {}),
        },
      });
    }
  }

  // ---------------- Notificacoes ----------------
  console.log('> Notificacoes...');
  const notifFor = (userId: string) => [
    { userId, type: NotificationType.CHANNEL_POST, title: 'Novo comunicado', body: 'Encontro Geral dos Pastores 2026', link: '/channel' },
    { userId, type: NotificationType.EVENT, title: 'Evento próximo', body: 'Reunião de supervisores de MG em 2 dias', link: '/calendar' },
    { userId, type: NotificationType.REQUEST, title: 'Solicitação atualizada', body: 'Sua solicitação recebeu um comentário', link: '/requests', readAt: daysAgo(1) },
    { userId, type: NotificationType.DOCUMENT, title: 'Documento vencendo', body: 'Um documento vence nos próximos 30 dias', link: '/documents' },
    { userId, type: NotificationType.TRAINING, title: 'Treinamento atribuído', body: 'Fundamentos do cuidado pastoral', link: '/training', readAt: daysAgo(4) },
  ];
  await prisma.notification.createMany({ data: allUserIds.flatMap(notifFor) });

  // ---------------- Resumo ----------------
  const counts = await prisma.$transaction([
    prisma.country.count(), prisma.region.count(), prisma.church.count(), prisma.pastor.count(),
    prisma.pastoralRelationship.count(), prisma.pastoralClosure.count(), prisma.pastoralCare.count(),
    prisma.request.count(), prisma.channelPost.count(), prisma.document.count(), prisma.credential.count(),
    prisma.event.count(), prisma.training.count(), prisma.trainingEnrollment.count(), prisma.notification.count(),
  ]);
  const labels = ['paises', 'regioes', 'igrejas', 'pastores', 'relacoes', 'closure', 'acompanhamentos', 'solicitacoes', 'posts', 'documentos', 'credenciais', 'eventos', 'treinamentos', 'matriculas', 'notificacoes'];
  console.log('\nSeed concluído em', ((Date.now() - started) / 1000).toFixed(1), 's');
  console.table(Object.fromEntries(labels.map((l, i) => [l, counts[i]])));
  console.log(`\nUsuarios de teste (senha: ${password}):`);
  console.table([
    { email: 'admin@pastoral.dev', role: 'GLOBAL_ADMIN', escopo: 'GLOBAL' },
    { email: 'nacional@pastoral.dev', role: 'NATIONAL_LEADER', escopo: 'COUNTRY:BR + SUBTREE' },
    { email: 'regional@pastoral.dev', role: 'REGIONAL_LEADER', escopo: 'REGION:BR-MG + SUBTREE' },
    { email: 'supervisor@pastoral.dev', role: 'SUPERVISOR', escopo: 'SUBTREE' },
    { email: 'pastor@pastoral.dev', role: 'PASTOR', escopo: 'SELF' },
    { email: 'secretaria@pastoral.dev', role: 'SECRETARY', escopo: 'COUNTRY:BR' },
  ]);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
