class PastorProfile {
  const PastorProfile({
    required this.initials,
    required this.name,
    required this.role,
    required this.church,
    required this.location,
    required this.email,
    required this.phone,
    required this.credential,
    required this.validUntil,
    required this.bio,
    this.imageAsset,
  });

  final String initials;
  final String name;
  final String role;
  final String church;
  final String location;
  final String email;
  final String phone;
  final String credential;
  final String validUntil;
  final String bio;
  final String? imageAsset;
}

abstract final class MockPastors {
  static const joao = PastorProfile(
    initials: 'JS',
    name: 'Pr. João Silva',
    role: 'Pastor titular',
    church: 'Lagoinha Betim',
    location: 'Betim · MG · Brasil',
    email: 'joao@lagoinha.demo',
    phone: '+55 31 98877-6655',
    credential: '001928',
    validUntil: '12/2027',
    bio:
        'Serve na Lagoinha Betim com foco em pregação, discipulado e cuidado das famílias da comunidade.',
    imageAsset: 'assets/images/pastor_joao.png',
  );

  static const carlos = PastorProfile(
    initials: 'RM',
    name: 'Pr. Rodinei Medeiros',
    role: 'Sobre-regional',
    church: 'Lagoinha Betim',
    location: 'Betim · MG · Brasil',
    email: 'rodinei@lagoinha.demo',
    phone: '+55 11 98888-1122',
    credential: '000741',
    validUntil: '08/2028',
    bio:
        'Atua na liderança regional da Lagoinha Betim, apoiando pastores, líderes e o cuidado das igrejas locais.',
    imageAsset: 'assets/images/mock_pastores/rodinei_medeiros.jpg',
  );

  static const ana = PastorProfile(
    initials: 'AS',
    name: 'Pra. Ana Souza',
    role: 'Pastora auxiliar',
    church: 'Lagoinha PTB',
    location: 'Betim · MG · Brasil',
    email: 'ana@comunidadedagraca.org',
    phone: '+55 41 97777-2255',
    credential: '002314',
    validUntil: '03/2028',
    bio:
        'Atua no discipulado e no cuidado de mulheres e famílias, formando voluntários para a vida comunitária.',
    imageAsset: 'assets/images/pastora_ana.png',
  );

  static const marcos = PastorProfile(
    initials: 'ML',
    name: 'Pr. Marcos Lima',
    role: 'Pastor de jovens',
    church: 'Lagoinha Citrolândia',
    location: 'São Paulo · SP · Brasil',
    email: 'marcos@ibcentral.org',
    phone: '+55 81 96666-3311',
    credential: '001550',
    validUntil: '11/2027',
    bio:
        'Desenvolve o ministério com adolescentes e jovens, fortalecendo o discipulado e a formação de novas lideranças.',
    imageAsset: 'assets/images/pastor_marcos.png',
  );

  static const lucas = PastorProfile(
    initials: 'PL',
    name: 'Pr. Lucas Ferreira',
    role: 'Pastor auxiliar',
    church: 'Lagoinha Marimbá',
    location: 'Betim · MG · Brasil',
    email: 'lucas@igrejadaponte.org',
    phone: '+55 62 95555-4422',
    credential: '002101',
    validUntil: '07/2027',
    bio:
        'Serve no acompanhamento de pequenos grupos e na integração de novos membros à igreja local.',
    imageAsset: 'assets/images/pastor_carlos.png',
  );

  static const marta = PastorProfile(
    initials: 'PM',
    name: 'Pra. Marta Oliveira',
    role: 'Pastora de formação',
    church: 'Igreja Vida Plena',
    location: 'Salvador · BA · Brasil',
    email: 'marta@vidaplena.org',
    phone: '+55 71 94444-5533',
    credential: '001877',
    validUntil: '10/2027',
    bio:
        'Dedica-se à formação de equipes de cuidado e ao acompanhamento de líderes da igreja local.',
  );

  static const andre = PastorProfile(
    initials: 'PA',
    name: 'Pr. André Costa',
    role: 'Pastor auxiliar',
    church: 'Comunidade do Caminho',
    location: 'Brasília · DF · Brasil',
    email: 'andre@comunidadedocaminho.org',
    phone: '+55 61 93333-6644',
    credential: '002401',
    validUntil: '05/2028',
    bio:
        'Serve no cuidado de pessoas e no fortalecimento da conexão entre igrejas e lideranças locais.',
  );
}
