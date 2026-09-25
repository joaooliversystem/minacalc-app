import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uuid/uuid.dart';

import '../../controllers/app_controller.dart';
import '../../core/constants.dart';
import '../../core/i18n.dart';
import '../theme.dart';

class MapScreen extends StatefulWidget {
  final AppController controller;
  const MapScreen({super.key, required this.controller});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? map;
  bool styleReady = false;
  bool downloading = false;
  double downloadProgress = 0;
  List<Map<String, dynamic>> points = [];

  @override
  void initState() {
    super.initState();
    _reloadPoints();
  }

  Future<void> _reloadPoints() async {
    points = await widget.controller.mapPoints();
    if (mounted) setState(() {});
    if (styleReady) await _drawPoints();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(widget.controller.language);
    return Stack(
      children: [
        MapLibreMap(
          styleString: AppConstants.mapStyleUrl,
          initialCameraPosition: const CameraPosition(target: LatLng(-14.2350, -51.9253), zoom: 3.5),
          myLocationEnabled: true,
          myLocationTrackingMode: MyLocationTrackingMode.none,
          onMapCreated: (controller) {
            map = controller;
            Future<void>.delayed(const Duration(milliseconds: 350), _tryInitialGps);
          },
          onStyleLoadedCallback: () async {
            styleReady = true;
            await _drawPoints();
          },
          onMapLongClick: (_, latLng) => _openPointSheet(latLng, source: 'manual'),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: Row(children: [
              Expanded(
                child: Material(
                  color: MinaTheme.panel.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('${points.length} ${s.t('mapMarkers')} • ${AppConstants.mapAttribution}', style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _centerOnGps, icon: const Icon(Icons.my_location)),
            ]),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 20,
          child: SafeArea(
            top: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (downloading)
                Container(
                  width: 220,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: MinaTheme.panel, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s.t('downloadMap')} ${(downloadProgress * 100).toStringAsFixed(0)}%'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: downloadProgress, color: MinaTheme.yellow),
                  ]),
                ),
              FloatingActionButton.extended(heroTag: 'offline-map', onPressed: downloading ? null : _downloadCurrentArea, icon: const Icon(Icons.download_for_offline_outlined), label: Text(s.t('downloadMap'))),
              const SizedBox(height: 8),
              FloatingActionButton.extended(heroTag: 'add-gps-point', onPressed: _addGpsPoint, icon: const Icon(Icons.add_location_alt_outlined), label: Text(s.t('addPoint'))),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _tryInitialGps() async {
    try {
      final p = await widget.controller.location.bestPosition(sampling: const Duration(seconds: 2));
      await map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 15));
    } catch (_) {
      if (points.isNotEmpty) {
        final lat = (points.first['lat'] as num?)?.toDouble();
        final lng = (points.first['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) await map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14));
      }
    }
  }

  Future<void> _centerOnGps() async {
    try {
      final p = await widget.controller.location.bestPosition(sampling: const Duration(seconds: 3));
      await map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 16));
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _addGpsPoint() async {
    try {
      final p = await widget.controller.location.bestPosition();
      if (!mounted) return;
      await _openPointSheet(LatLng(p.latitude, p.longitude), source: 'gps', accuracy: p.accuracy);
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _openPointSheet(LatLng position, {required String source, double accuracy = 0}) async {
    final label = TextEditingController();
    final notes = TextEditingController();
    final availablePlans = (await widget.controller.plans()).where((p) => (p['status'] ?? '') == 'Ativo').toList();
    String type = 'operation';
    String planId = '';
    final s = AppStrings(widget.controller.language);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: StatefulBuilder(builder: (context, setLocal) => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s.t('markerTitle'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: type,
            decoration: InputDecoration(labelText: s.t('type')),
            items: [
              DropdownMenuItem(value: 'operation', child: Text(s.t('operation'))),
              DropdownMenuItem(value: 'equipment', child: Text(s.t('equipment'))),
              DropdownMenuItem(value: 'technical_item', child: Text(s.t('technicalItem'))),
              DropdownMenuItem(value: 'explosive', child: Text(s.t('controlledItem'))),
              DropdownMenuItem(value: 'other', child: Text(s.t('other'))),
            ],
            onChanged: (v) => setLocal(() => type = v ?? 'other'),
          ),
          if (availablePlans.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: planId.isEmpty ? null : planId,
              decoration: InputDecoration(labelText: s.t('plan')),
              items: [
                DropdownMenuItem(value: '', child: Text('—')),
                ...availablePlans.map((p) => DropdownMenuItem(value: '${p['id']}', child: Text('${p['name'] ?? p['code'] ?? p['id']}'))),
              ],
              onChanged: (v) => setLocal(() => planId = v ?? ''),
            ),
          ],
          const SizedBox(height: 12),
          TextField(controller: label, decoration: InputDecoration(labelText: s.t('identification'))),
          const SizedBox(height: 12),
          TextField(controller: notes, maxLines: 3, decoration: InputDecoration(labelText: s.t('observations'))),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: Text('${source == 'gps' ? s.t('gps') : s.t('manual')} • ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}${accuracy > 0 ? ' • ±${accuracy.toStringAsFixed(1)} m' : ''}', style: const TextStyle(color: Colors.white60, fontSize: 12))),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('save').toUpperCase())),
        ])),
      ),
    );
    if (saved == true) {
      final id = 'map-${const Uuid().v4()}';
      await widget.controller.saveMapPoint({
        'id': id,
        'client_uuid': id,
        'type': type,
        'plan_id': planId,
        'label': label.text.trim(),
        'notes': notes.text.trim(),
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': accuracy,
        'source': source,
        'active': true,
      });
      await _reloadPoints();
    }
    label.dispose();
    notes.dispose();
  }

  Future<void> _drawPoints() async {
    final controller = map;
    if (controller == null || !styleReady) return;
    await controller.clearCircles();
    for (final point in points) {
      final lat = (point['lat'] as num?)?.toDouble();
      final lng = (point['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final color = switch (point['type']) {
        'equipment' => '#3EA6FF',
        'technical_item' => '#EEEEEE',
        'explosive' => '#FF4545',
        'operation' => '#FFC51B',
        _ => '#9E9E9E',
      };
      await controller.addCircle(CircleOptions(
        geometry: LatLng(lat, lng),
        circleColor: color,
        circleRadius: 8,
        circleStrokeColor: '#111111',
        circleStrokeWidth: 2,
      ));
    }
  }

  Future<void> _downloadCurrentArea() async {
    if (!widget.controller.connectivity.hasNetwork) return _snack(AppStrings(widget.controller.language).t('mapNeedsInternet'));
    setState(() { downloading = true; downloadProgress = 0; });
    try {
      final p = await widget.controller.location.bestPosition(sampling: const Duration(seconds: 3));
      await widget.controller.offlineMaps.downloadAround(latitude: p.latitude, longitude: p.longitude, onProgress: (v) {
        if (mounted) setState(() => downloadProgress = v);
      });
      _snack(AppStrings(widget.controller.language).t('mapReady'));
    } catch (e) {
      _snack('${AppStrings(widget.controller.language).t('mapDownloadFailed')}: $e');
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
