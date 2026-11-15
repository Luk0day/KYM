class StoreFilter {
  const StoreFilter({
    this.query = '',
    this.city,
    this.onlyWithPending = false,
  });

  final String query;
  final String? city;
  final bool onlyWithPending;

  /// Filtros do BottomSheet (cidade e pendências), sem contar a busca.
  bool get hasSheetFilters => city != null || onlyWithPending;

  bool get isEmpty => query.trim().isEmpty && !hasSheetFilters;

  StoreFilter copyWith({
    String? query,
    String? city,
    bool clearCity = false,
    bool? onlyWithPending,
  }) {
    return StoreFilter(
      query: query ?? this.query,
      city: clearCity ? null : (city ?? this.city),
      onlyWithPending: onlyWithPending ?? this.onlyWithPending,
    );
  }
}
