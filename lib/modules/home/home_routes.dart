import '../auth/domain/entities/user_role_permissions.dart';
import '../scanner/scanner_routes.dart';

abstract final class HomeRoutes {
  static const String root = '/home';

  static const String painelPath = '/painel';
  static const String lojasPath = '/lojas';
  static const String agendaPath = '/agenda';
  static const String qrCodesPath = '/qr-codes';
  static const String perfilPath = '/perfil';
  static const String lojaPath = '/lojas/:id';

  static const String painel = '$root$painelPath';
  static const String lojas = '$root$lojasPath';
  static const String agenda = '$root$agendaPath';
  static const String qrCodes = '$root$qrCodesPath';
  static const String perfil = '$root$perfilPath';

  /// Detalhe da loja, aberto por cima da casca (mesmo modelo do leitor de QR).
  static String loja(String id) => '$root/lojas/$id';

  static String of(AppDestination destination) => switch (destination) {
    AppDestination.painel => painel,
    AppDestination.lojas => lojas,
    // O leitor abre em tela cheia, fora do shell.
    AppDestination.qr => ScannerRoutes.root,
    AppDestination.agenda => agenda,
    AppDestination.qrCodes => qrCodes,
    AppDestination.perfil => perfil,
  };

  /// Destino da aba que contém [path], inclusive rotas internas dela
  /// (ex.: /home/lojas/123). Devolve null fora das abas.
  static AppDestination? destinationOf(String path) {
    for (final destination in AppDestination.values) {
      final route = of(destination);
      if (path == route || path.startsWith('$route/')) return destination;
    }
    return null;
  }
}
