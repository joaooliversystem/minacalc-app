import 'package:maplibre_gl/maplibre_gl.dart';

import '../core/constants.dart';

class OfflineMapService {
  Future<OfflineRegion> downloadAround({
    required double latitude,
    required double longitude,
    required void Function(double progress) onProgress,
  }) async {
    const delta = 0.015;
    final bounds = LatLngBounds(
      southwest: LatLng(latitude - delta, longitude - delta),
      northeast: LatLng(latitude + delta, longitude + delta),
    );
    final definition = OfflineRegionDefinition(
      bounds: bounds,
      mapStyleUrl: AppConstants.mapStyleUrl,
      minZoom: 12,
      maxZoom: 15,
      includeIdeographs: false,
    );
    await setOfflineTileCountLimit(30000);
    return downloadOfflineRegion(
      definition,
      metadata: {
        'name': 'MinaCalc ${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}',
        'created_at': DateTime.now().toIso8601String(),
      },
      onEvent: (event) {
        if (event is InProgress) onProgress(event.progress.clamp(0.0, 1.0).toDouble());
        if (event is Success) onProgress(1.0);
      },
    );
  }

  Future<List<OfflineRegion>> regions() => getListOfRegions();
  Future<void> remove(int id) async {
    await deleteOfflineRegion(id);
    await clearAmbientCache();
  }
}
