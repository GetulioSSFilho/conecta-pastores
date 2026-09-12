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
    role: 'Pastor Sênior',
    church: 'Igreja Monte Carmo',
    location: 'Belo Horizonte · MG · Brasil',
    email: 'joao@igrejamontecarmo.org',
    phone: '+55 31 98877-6655',
    credential: '001928',
    validUntil: '12/2027',
    bio:
        'Pastor desde 2010. Servindo com dedicação ao Reino de Deus e ao cuidado de pessoas.',
    imageAsset: 'assets/images/pastor_joao.png',
  );

  static const carlos = PastorProfile(
    initials: 'PC',
    name: 'Pr. Carlos Mendes',
    role: 'Líder regional',
    church: 'Igreja Esperança Viva',
    location: 'São Paulo · SP · Brasil',
    email: 'carlos@esperancaviva.org',
    phone: '+55 11 98888-1122',
    credential: '000741',
    validUntil: '08/2028',
    bio:
        'Liderando uma rede de pastores com foco em cuidado, formação e unidade.',
    imageAsset: 'assets/images/pastor_carlos.png',
  );

  static const ana = PastorProfile(
    initials: 'AS',
    name: 'Pra. Ana Souza',
    role: 'Pastora',
    church: 'Comunidade da Graça',
    location: 'Curitiba · PR · Brasil',
    email: 'ana@comunidadedagraca.org',
    phone: '+55 41 97777-2255',
    credential: '002314',
    validUntil: '03/2028',
    bio:
        'Servindo famílias e líderes através de acompanhamento próximo e formação.',
    imageAsset: 'assets/images/pastora_ana.png',
  );

  static const marcos = PastorProfile(
    initials: 'ML',
    name: 'Pr. Marcos Lima',
    role: 'Pastor',
    church: 'Igreja Batista Central',
    location: 'Recife · PE · Brasil',
    email: 'marcos@ibcentral.org',
    phone: '+55 81 96666-3311',
    credential: '001550',
    validUntil: '11/2027',
    bio: 'Acompanhando comunidades locais e desenvolvendo novos líderes.',
    imageAsset: 'assets/images/pastor_marcos.png',
  );

  static const lucas = PastorProfile(
    initials: 'PL',
    name: 'Pr. Lucas Ferreira',
    role: 'Pastor',
    church: 'Igreja da Ponte',
    location: 'Goiânia · GO · Brasil',
    email: 'lucas@igrejadaponte.org',
    phone: '+55 62 95555-4422',
    credential: '002101',
    validUntil: '07/2027',
    bio: 'Pastor dedicado ao cuidado pastoral e à missão urbana.',
    imageAsset: 'assets/images/pastor_carlos.png',
  );

  static const marta = PastorProfile(
    initials: 'PM',
    name: 'Pra. Marta Oliveira',
    role: 'Pastora',
    church: 'Igreja Vida Plena',
    location: 'Salvador · BA · Brasil',
    email: 'marta@vidaplena.org',
    phone: '+55 71 94444-5533',
    credential: '001877',
    validUntil: '10/2027',
    bio: 'Servindo no discipulado e na formação de equipes de cuidado.',
    imageAsset: 'assets/images/pastora_lucia.png',
  );

  static const andre = PastorProfile(
    initials: 'PA',
    name: 'Pr. André Costa',
    role: 'Pastor',
    church: 'Comunidade do Caminho',
    location: 'Brasília · DF · Brasil',
    email: 'andre@comunidadedocaminho.org',
    phone: '+55 61 93333-6644',
    credential: '002401',
    validUntil: '05/2028',
    bio: 'Cuidando de pessoas e fortalecendo a conexão entre igrejas.',
    imageAsset: 'assets/images/pastor_marcos.png',
  );
}
