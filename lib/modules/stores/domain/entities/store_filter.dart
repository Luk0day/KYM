/// Abas de filtro da tela (chips do Figma).
enum StoreFilterKind { todas, comAtrasadas, preventivas, corretivas }

class StoreFilter {
  const StoreFilter({this.query = '', this.kind = StoreFilterKind.todas});

  final String query;
  final StoreFilterKind kind;

  bool get isEmpty => query.trim().isEmpty && kind == StoreFilterKind.todas;

  StoreFilter copyWith({String? query, StoreFilterKind? kind}) {
    return StoreFilter(query: query ?? this.query, kind: kind ?? this.kind);
  }
}
