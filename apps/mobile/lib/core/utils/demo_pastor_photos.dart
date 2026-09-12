/// Retratos temporários para a demonstração enquanto as fotos reais não vêm
/// do cadastro. O índice combina gênero e número, evitando repetir a mesma
/// imagem dentro da árvore mockada.
abstract final class DemoPastorPhotos {
  static String tree(int index) {
    return 'assets/images/mock_pastores/pastor_${index.toString().padLeft(3, '0')}.jpg';
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
    final photoIndex = (numericId ?? hash.abs()) % 150;
    return tree(photoIndex);
  }
}
