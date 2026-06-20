import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../providers/player_provider.dart';
import '../providers/zone_content_provider.dart';
import '../models/media_item.dart';

class ZoneContentService {
  static final ZoneContentService instance = ZoneContentService._init();
  ZoneContentService._init();

  Timer? _timer;
  bool _isSyncing = false;
  WidgetRef? _ref;

  /// Starts the zone content polling loop.
  void start(WidgetRef ref) {
    _ref = ref;
    _timer?.cancel();
    // Delay initial sync to let main layout stabilize
    _scheduleNextSync(const Duration(seconds: 2));
  }

  void _scheduleNextSync(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () async {
      await _performSync();

      final activeRef = _ref;
      if (activeRef != null && activeRef.context.mounted) {
        final state = activeRef.read(activationProvider);
        if (state.isActivated) {
          // Re-use sync interval from main activation state
          final interval = state.syncInterval > 0 ? state.syncInterval : 10;
          _scheduleNextSync(Duration(seconds: interval));
        } else {
          // Stop polling if deactivated
          stop();
        }
      }
    });
  }

  /// Stops the polling loop.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isSyncing = false;
    _ref = null;
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;
    final activeRef = _ref;
    if (activeRef == null || !activeRef.context.mounted) return;

    final actState = activeRef.read(activationProvider);
    if (!actState.isActivated || actState.layout != 'half_split') return;

    if (kIsWeb || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))) {
      // Mock data for web demo mode
      final mockItem = MediaItem(
        id: 9999,
        url: 'https://cms.thelocads.com/assets/images/logo.png',
        type: 'image',
        duration: 10,
        order: 1,
      );
      activeRef.read(zoneContentProvider.notifier).updateItem(mockItem);
      return;
    }

    _isSyncing = true;
    final screenId = actState.screenId;

    try {
      // TODO: Confirm correct backend URL for "right zone content" with backend team.
      // Re-using the schedule sync endpoint as a placeholder that will return the unified JSON.
      final scheduleUrl = Uri.parse(
        'https://cms.thelocads.com/api/player/schedule?screen_id=$screenId',
      );

      final response = await http.get(
        scheduleUrl,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Defensive multi-key fallback pattern for the zone content field
        // TODO: Update field names when confirmed by backend team
        dynamic zoneData = data['zone_content'] ?? data['right_zone'] ?? data['cms_content'];

        if (zoneData == null && data['data'] is Map) {
          final innerData = data['data'] as Map;
          zoneData = innerData['zone_content'] ?? innerData['right_zone'] ?? innerData['cms_content'];
        }
        
        if (zoneData == null && data['cluster'] is Map) {
          final innerData = data['cluster'] as Map;
          zoneData = innerData['zone_content'] ?? innerData['right_zone'] ?? innerData['cms_content'];
        }

        if (zoneData != null && zoneData is Map<String, dynamic>) {
          final item = MediaItem.fromJson(zoneData);
          // Assuming caching is handled dynamically by Image.network or VideoPlayer 
          // (or extending FileManager if needed, but keeping it simple for now)
          if (activeRef.context.mounted) {
            activeRef.read(zoneContentProvider.notifier).updateItem(item);
          }
        } else if (zoneData is List && zoneData.isNotEmpty && zoneData.first is Map) {
           final item = MediaItem.fromJson(zoneData.first as Map<String, dynamic>);
           if (activeRef.context.mounted) {
             activeRef.read(zoneContentProvider.notifier).updateItem(item);
           }
        } else {
          // Empty state from CMS
          if (activeRef.context.mounted) {
             activeRef.read(zoneContentProvider.notifier).setLoading(false);
          }
        }
      } else {
        print('Zone Content API returned error status: ${response.statusCode}');
        if (activeRef.context.mounted) {
          activeRef.read(zoneContentProvider.notifier).setError('HTTP ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Zone Content synchronization failed: $e');
      if (activeRef.context.mounted) {
        activeRef.read(zoneContentProvider.notifier).setError('Sync failed: $e');
      }
    } finally {
      _isSyncing = false;
    }
  }
}
