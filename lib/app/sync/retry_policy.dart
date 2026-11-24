/// Quantas vezes um item falho é reenviado e quanto se espera entre as
/// tentativas. A espera dobra a cada falha: 30 s, 1 min, 2 min, 4 min…
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 5,
    this.baseDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(minutes: 30),
  });

  /// Depois de tantas falhas o item só volta à fila por ação manual (B16).
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Espera antes da próxima tentativa de um item que já falhou [attempts]
  /// vezes.
  Duration delayFor(int attempts) {
    if (attempts <= 0) return Duration.zero;
    // Limita o expoente para não estourar o inteiro em valores absurdos.
    final factor = 1 << (attempts - 1).clamp(0, 20);
    final delay = baseDelay * factor;
    return delay > maxDelay ? maxDelay : delay;
  }

  /// Quando o item pode ser tentado de novo. Nulo = já pode.
  DateTime? nextAttemptAt(int attempts, DateTime? lastAttemptAt) {
    if (attempts <= 0 || lastAttemptAt == null) return null;
    return lastAttemptAt.add(delayFor(attempts));
  }

  bool isDue(int attempts, DateTime? lastAttemptAt, DateTime now) {
    final next = nextAttemptAt(attempts, lastAttemptAt);
    return next == null || !now.isBefore(next);
  }
}
