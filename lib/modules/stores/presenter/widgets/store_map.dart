import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_colors.dart';
import 'store_map_fallback.dart';

/// Mapa do OpenStreetMap com a posição da loja (sem chave de API). Se os
/// blocos do mapa não carregarem (sem internet ou servidor fora do ar), troca
/// por [StoreMapFallback] em vez de travar a tela.
class StoreMap extends StatefulWidget {
  const StoreMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.storeName,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String storeName;
  final String? address;

  @override
  State<StoreMap> createState() => _StoreMapState();
}

class _StoreMapState extends State<StoreMap> {
  bool _tilesFailed = false;

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (_tilesFailed) return;
    // O callback roda durante o build do mapa; adia o setState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _tilesFailed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tilesFailed) return StoreMapFallback(address: widget.address);

    final point = LatLng(widget.latitude, widget.longitude);
    return Semantics(
      label: 'Mapa com a localização da ${widget.storeName}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 16,
                  // Sem gestos: o mapa não disputa a rolagem da página.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'br.edu.ifpe.mobile.kym',
                    errorTileCallback: _onTileError,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 56,
                        height: 56,
                        child: const _StorePin(),
                      ),
                    ],
                  ),
                  const SimpleAttributionWidget(
                    source: Text('© OpenStreetMap contributors'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marcador do Figma: loja num círculo laranja com halo.
class _StorePin extends StatelessWidget {
  const _StorePin();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.accent.withValues(alpha: 0.18),
    ),
    alignment: Alignment.center,
    child: Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent,
      ),
      child: const Icon(Icons.storefront, size: 20, color: AppColors.onAccent),
    ),
  );
}
