import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _hasNetwork = false;

  bool get hasNetwork => _hasNetwork;
  Stream<bool> get changes => _controller.stream;

  Future<void> start() async {
    final now = await _connectivity.checkConnectivity();
    _update(now);
    _sub = _connectivity.onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    final value = results.any((r) => r != ConnectivityResult.none);
    if (value == _hasNetwork) return;
    _hasNetwork = value;
    _controller.add(value);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
