import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> bestPosition({Duration sampling = const Duration(seconds: 8)}) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Ative a localização do aparelho para continuar.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização não concedida.');
    }

    Position? best;
    try {
      final first = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 12)));
      best = first;
    } catch (_) {}

    final end = DateTime.now().add(sampling);
    await for (final p in Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0))) {
      if (best == null || p.accuracy < best.accuracy) best = p;
      if (DateTime.now().isAfter(end) || (best?.accuracy ?? 9999) <= 5) break;
    }
    if (best == null) throw Exception('Não foi possível obter a localização.');
    return best;
  }
}
