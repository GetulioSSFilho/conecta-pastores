/// Retratos temporários para a demonstração enquanto as fotos reais não vêm
/// do cadastro. O índice combina gênero e número, evitando repetir a mesma
/// imagem dentro da árvore mockada.
abstract final class DemoPastorPhotos {
  // Os índices foram auditados visualmente e separados por gênero para que
  // os nomes femininos e masculinos da demonstração nunca recebam um retrato
  // incompatível. Os dois PNGs extras completam o total masculino sem repetir
  // as fotos usadas nos nós fixos do organograma.
  static const _maleTreeIndexes = [
    0,
    2,
    6,
    8,
    10,
    12,
    13,
    14,
    16,
    18,
    20,
    22,
    24,
    26,
    28,
    30,
    32,
    36,
    38,
    40,
    42,
    44,
    46,
    48,
    50,
    52,
    54,
    56,
    58,
    60,
    62,
    64,
    66,
    68,
    70,
    72,
    74,
    76,
    78,
    80,
    82,
    84,
    86,
    88,
    90,
    92,
    94,
    96,
    98,
    100,
    102,
    106,
    108,
    110,
    112,
    113,
    114,
    116,
    117,
    118,
    120,
    122,
    124,
    126,
    128,
    130,
    136,
    138,
    140,
    142,
    144,
    146,
    148,
  ];

  static const _femaleTreeIndexes = [
    1,
    3,
    4,
    5,
    7,
    9,
    11,
    15,
    17,
    19,
    21,
    23,
    25,
    27,
    29,
    31,
    33,
    34,
    35,
    37,
    39,
    41,
    43,
    45,
    47,
    49,
    51,
    53,
    55,
    57,
    59,
    61,
    63,
    65,
    67,
    69,
    71,
    73,
    75,
    77,
    79,
    81,
    83,
    85,
    87,
    89,
    91,
    93,
    95,
    97,
    99,
    101,
    103,
    104,
    105,
    107,
    109,
    111,
    115,
    119,
    121,
    123,
    125,
    127,
    129,
    131,
    132,
    133,
    134,
    135,
    137,
    139,
    141,
    143,
    145,
    147,
    149,
  ];

  static String _mock(int index) =>
      'assets/images/mock_pastores/pastor_${index.toString().padLeft(3, '0')}.jpg';

  static const _maleExtras = [
    'assets/images/pastor_joao.png',
    'assets/images/pastor_marcos.png',
  ];

  static bool isFemaleName(String name) =>
      RegExp(r'^(Pra\.|Pastora)\s', caseSensitive: false).hasMatch(name);

  static String _nextMaleExtra(int index) =>
      _maleExtras[index % _maleExtras.length];

  static String nextFemalePhoto(int index) =>
      _mock(_femaleTreeIndexes[index % _femaleTreeIndexes.length]);

  static String nextMalePhoto(int index) {
    if (index < _maleTreeIndexes.length) return _mock(_maleTreeIndexes[index]);
    return _nextMaleExtra(index - _maleTreeIndexes.length);
  }

  /// Fallback estável para listas ligadas à API quando o pastor ainda não
  /// possui uma foto cadastrada.
  static String forPastor({required String id, required String name}) {
    final numericId = int.tryParse(
      RegExp(r'(\d+)$').firstMatch(id)?.group(1) ?? '',
    );
    final seed = '$id$name';
    final hash = seed.codeUnits.fold<int>(
      17,
      (value, code) => value * 31 + code,
    );
    final photoIndex = numericId ?? hash.abs();
    if (isFemaleName(name)) {
      return nextFemalePhoto(photoIndex);
    }
    return nextMalePhoto(
      photoIndex % (_maleTreeIndexes.length + _maleExtras.length),
    );
  }
}
