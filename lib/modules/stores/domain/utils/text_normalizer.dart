/// Normalização para busca: minúsculas, sem acentos e com espaços colapsados.
abstract final class TextNormalizer {
  static const Map<String, String> _accents = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };

  static final RegExp _spaces = RegExp(r'\s+');

  /// Acentos soltos (U+0300 a U+036F), de texto decomposto: "e" seguido de "´".
  static bool _isCombiningMark(int rune) => rune >= 0x0300 && rune <= 0x036F;

  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      if (_isCombiningMark(rune)) {
        continue;
      }
      final char = String.fromCharCode(rune);
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString().trim().replaceAll(_spaces, ' ');
  }
}
