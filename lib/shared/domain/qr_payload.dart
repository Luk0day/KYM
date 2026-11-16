/// Formato do texto dos QR Codes do KYM. Dart puro.
///
/// ```
/// kym:1:S:<qr_token>   -> loja
/// kym:1:E:<qr_token>   -> equipamento
/// ```
///
/// O `<qr_token>` é o uuid da coluna `qr_token` (e não o `id`), em minúsculas.
/// Assim, um QR impresso é invalidado gerando um token novo, sem mexer no
/// registro. Não há assinatura criptográfica: o token só identifica, quem
/// autoriza é o servidor (RLS).

/// O que o QR Code identifica.
enum QrTargetType {
  store('S'),
  equipment('E');

  const QrTargetType(this.code);

  /// Letra gravada no texto do QR (`S` ou `E`).
  final String code;

  /// Aceita a letra em maiúscula ou minúscula. `null` se não for conhecida.
  static QrTargetType? fromCode(String code) {
    final upper = code.toUpperCase();
    for (final type in values) {
      if (type.code == upper) return type;
    }
    return null;
  }
}

/// Conteúdo de um QR do KYM: o tipo e o `qr_token`.
class QrPayload {
  /// Identifica o sistema no início do texto.
  static const String prefix = 'kym';

  /// Única versão do formato aceita hoje.
  static const int currentVersion = 1;

  static const String _separator = ':';

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  /// Cria um payload. O [token] é normalizado (espaços nas pontas e
  /// maiúsculas) e deve ser um uuid; senão lança [ArgumentError], para que
  /// `encode()` nunca gere um QR inválido.
  QrPayload({required this.type, required String token})
    : token =
          _normalizeToken(token) ??
          (throw ArgumentError.value(token, 'token', 'uuid inválido'));

  final QrTargetType type;

  /// uuid em minúsculas.
  final String token;

  /// Texto a gravar no QR Code. É o inverso de [parse].
  String encode() =>
      [prefix, '$currentVersion', type.code, token].join(_separator);

  /// Interpreta o texto lido pela câmera. Nunca lança.
  ///
  /// Tolera espaços (inclusive quebra de linha) e maiúsculas. Só a versão
  /// [currentVersion] é aceita.
  static QrParseResult parse(String raw) {
    final parts = raw.split(_separator).map((p) => p.trim()).toList();

    // Qualquer coisa que não comece com "kym" é de outro sistema (URL, texto
    // livre, outro app). Em "https://x", o primeiro trecho é "https".
    if (parts.first.toLowerCase() != prefix) return const QrForeign();

    // É do KYM, mas sem versão não há o que interpretar.
    if (parts.length < 2) return const QrMalformed();

    final version = _parseVersion(parts[1]);
    if (version == null) return const QrMalformed();

    // Versões futuras podem mudar a forma do texto: não olha o resto.
    if (version != currentVersion) return QrUnsupportedVersion(version);

    if (parts.length != 4) return const QrMalformed();

    final type = QrTargetType.fromCode(parts[2]);
    final token = _normalizeToken(parts[3]);
    if (type == null || token == null) return const QrMalformed();

    return QrValid(QrPayload(type: type, token: token));
  }

  static int? _parseVersion(String text) =>
      RegExp(r'^\d+$').hasMatch(text) ? int.tryParse(text) : null;

  /// uuid em minúsculas, ou `null` se [text] não for um uuid.
  static String? _normalizeToken(String text) {
    final token = text.trim().toLowerCase();
    return _uuid.hasMatch(token) ? token : null;
  }

  @override
  bool operator ==(Object other) =>
      other is QrPayload && other.type == type && other.token == token;

  @override
  int get hashCode => Object.hash(type, token);

  @override
  String toString() => 'QrPayload(${type.name}, $token)';
}

/// Resultado de [QrPayload.parse]. Use `switch` para tratar todos os casos.
sealed class QrParseResult {
  const QrParseResult();
}

/// QR do KYM, de loja ou de equipamento.
final class QrValid extends QrParseResult {
  const QrValid(this.payload);

  final QrPayload payload;

  @override
  bool operator ==(Object other) =>
      other is QrValid && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;
}

/// QR de outro sistema: o app deve recusar.
final class QrForeign extends QrParseResult {
  const QrForeign();
}

/// QR do KYM numa versão que este app não conhece ("atualize o app").
final class QrUnsupportedVersion extends QrParseResult {
  const QrUnsupportedVersion(this.version);

  final int version;

  @override
  bool operator ==(Object other) =>
      other is QrUnsupportedVersion && other.version == version;

  @override
  int get hashCode => version.hashCode;
}

/// Começa como QR do KYM, mas está quebrado (uuid inválido, tipo
/// desconhecido, partes faltando ou sobrando).
final class QrMalformed extends QrParseResult {
  const QrMalformed();
}
