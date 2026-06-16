import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../providers/player_provider.dart';

class HeartbeatService {
  static final HeartbeatService instance = HeartbeatService._init();
  HeartbeatService._init();

  Timer? _timer;

  /// Starts the telemetry heartbeat checker executing every 5 minutes.
  void start(WidgetRef ref) {
    _timer?.cancel();
    // Immediate call on activation, then trigger periodically
    _sendHeartbeat(ref);
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _sendHeartbeat(ref));
  }

  /// Cancels telemetry heartbeat checker execution.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sendHeartbeat(WidgetRef ref) async {
    final state = ref.read(activationProvider);
    if (!state.isActivated) return;

    final coords = await _determinePosition();
    final screenIdInt = int.tryParse(state.screenId) ?? 0;

    try {
      final url = Uri.parse('https://viewsys.co.in/api/player/heartbeat');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'screen_id': screenIdInt,
          'app_version': '1.0',
          'latitude': coords['latitude'],
          'longitude': coords['longitude'],
        }),
      );

      if (response.statusCode == 200) {
        print('Heartbeat status ok: ${response.body}');
      } else {
        print('Heartbeat error status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Heartbeat connection failed: $e');
    }
  }

  /// Determines geolocation. Falls back to default values if permission is denied/service is disabled.
  Future<Map<String, double>> _determinePosition() async {
    const defaultCoords = {'latitude': 28.61, 'longitude': 77.23};
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return defaultCoords;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return defaultCoords;
      }

      if (permission == LocationPermission.deniedForever) return defaultCoords;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 4),
      );
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      print('Geolocation lookup failure, using fallbacks: $e');
      return defaultCoords;
    }
  }
}
