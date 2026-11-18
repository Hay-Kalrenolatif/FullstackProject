/// Deteksi koneksi untuk aturan "offline = jangan ajukan apa-apa".
///
/// Di web (panel admin) notifier ini sengaja tidak dipakai: browser tidak
/// memberi hasil yang bisa dipercaya, dan panel admin memang tidak punya mode
/// offline — kegagalan request sudah cukup memberitahu operator.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> online = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> start() async {
    if (kIsWeb || _sub != null) return;
    try {
      _apply(await Connectivity().checkConnectivity());
      _sub = Connectivity().onConnectivityChanged.listen(_apply);
    } catch (_) {
      // Platform tanpa plugin connectivity: anggap online, biarkan request yang
      // bicara. Salah menyimpulkan "offline" akan mengunci tombol pengajuan.
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final none = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    online.value = !none;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
