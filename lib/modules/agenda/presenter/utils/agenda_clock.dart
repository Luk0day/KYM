/// Relógio da agenda, injetável para que os testes fixem o dia de hoje.
class AgendaClock {
  const AgendaClock([this.now = DateTime.now]);

  final DateTime Function() now;
}
