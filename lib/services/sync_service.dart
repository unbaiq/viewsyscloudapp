import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../providers/player_provider.dart';
import '../models/media_item.dart';
import '../models/ticker_item.dart';
import 'screenshot_service.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  Timer? _timer;
  bool _isSyncing = false;
  bool _isFirstSync = true;
  bool _forceSyncOnStartup = true;
  WidgetRef? _ref;

  /// Starts the synchronization scheduler with a delay to allow activation preferences to load.
  void start(WidgetRef ref) {
    _ref = ref;
    _timer?.cancel();
    _scheduleNextSync(const Duration(milliseconds: 600));
  }

  void _scheduleNextSync(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () async {
      await _performSync();

      final activeRef = _ref;
      if (activeRef != null && activeRef.context.mounted) {
        final state = activeRef.read(activationProvider);
        if (state.isActivated) {
          final interval = state.syncInterval > 0 ? state.syncInterval : 10;
          _scheduleNextSync(Duration(seconds: interval));
        }
      }
    });
  }

  /// Cancels sync scheduler execution.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isFirstSync = true;
    _forceSyncOnStartup = true;
  }

  Future<void> _performSync() async {
    // Avoid double syncing if an operation is still in progress
    if (_isSyncing) return;

    final activeRef = _ref;
    if (activeRef == null || !activeRef.context.mounted) return;

    final actState = activeRef.read(activationProvider);
    print(
      'Sync check called. Activated: ${actState.isActivated}, Device Code: ${actState.deviceCode}, Screen ID: ${actState.screenId}',
    );
    if (!actState.isActivated) return;

    if (_isFirstSync) {
      _isFirstSync = false;
      try {
        await activeRef.read(activationProvider.notifier).refreshActivationDetails();
      } catch (e) {
        print('Initial activation refresh failed: $e');
      }
    }

    if (kIsWeb || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))) {
      // Bypass network sync in Web demo mode or widget test mode
      final currentRef = _ref;
      if (currentRef != null && currentRef.context.mounted) {
        currentRef.read(playlistProvider.notifier).setOnlineStatus(true);
        currentRef.read(playlistProvider.notifier).markInitialized();
      }
      return;
    }

    _isSyncing = true;
    final screenId = actState.screenId;

    try {
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt('playlist_version') ?? 0;
      print(
        'Sync check initiated: Screen ID: $screenId, Local playlist version: $localVersion',
      );

      // Perform sync ping and schedule sync in parallel to run continuously and independently
      await Future.wait([
        _runSyncPing(screenId, localVersion),
        _runScheduleSync(screenId),
      ]);
    } catch (e) {
      print('Sync loop global exception: $e');
      final currentRef = _ref;
      if (currentRef != null && currentRef.context.mounted) {
        currentRef.read(playlistProvider.notifier).setOnlineStatus(false);
      }
    } finally {
      _isSyncing = false;
      final currentRef = _ref;
      if (currentRef != null && currentRef.context.mounted) {
        currentRef.read(playlistProvider.notifier).markInitialized();
      }
    }
  }

  Future<void> _runSyncPing(String screenId, int localVersion) async {
    try {
      final syncUrl = Uri.parse(
        'https://cms.thelocads.com/api/player/sync?screen_id=$screenId&version=$localVersion',
      );

      final response = await http.get(
        syncUrl,
        headers: {'Accept': 'application/json'},
      );

      final currentRef = _ref;
      if (currentRef == null || !currentRef.context.mounted) return;

      currentRef.read(playlistProvider.notifier).setOnlineStatus(true);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final serverVersion = data['version'] as int? ?? localVersion;
          final takeScreenshot = data['take_screenshot'] as bool? ?? false;
          final orientation = data['orientation'] as String?;
          final restartFlag = data['restart'] as bool? ?? false;

          final currentRefAfterFetch = _ref;
          if (currentRefAfterFetch == null || !currentRefAfterFetch.context.mounted) return;

          // Update orientation layout parameters dynamically
          if (orientation != null && orientation.isNotEmpty) {
            final currentActState = currentRefAfterFetch.read(activationProvider);
            if (currentActState.orientation != orientation) {
              await currentRefAfterFetch
                  .read(activationProvider.notifier)
                  .updateOrientation(orientation);
            }
          }

          // Update layout dynamically
          String? layout = data['layout_type']?.toString() ?? data['layout']?.toString();
          if (layout == null && data['data'] is Map) {
            layout = (data['data'] as Map)['layout_type']?.toString() ?? (data['data'] as Map)['layout']?.toString();
          }
          if (layout == null && data['cluster'] is Map) {
            layout = (data['cluster'] as Map)['layout_type']?.toString() ?? (data['cluster'] as Map)['layout']?.toString();
          }
          if (layout != null && layout.isNotEmpty) {
            final currentActState = currentRefAfterFetch.read(activationProvider);
            if (currentActState.layout != layout.trim().toLowerCase()) {
              await currentRefAfterFetch.read(activationProvider.notifier).updateLayout(layout);
            }
          }

          dynamic tickersData = data['header_text'] ?? 
                              data['headerText'] ?? 
                              data['ticker_type'] ?? 
                              data['tickerType'] ?? 
                              data['tickers'] ?? 
                              data['ticker'] ?? 
                              data['ticker_text'] ?? 
                              data['tickerText'] ?? 
                              data['tickers_text'];
                              
          if (tickersData == null && data['data'] is Map) {
            final innerData = data['data'] as Map;
            tickersData = innerData['header_text'] ?? 
                          innerData['headerText'] ?? 
                          innerData['tickers'] ?? 
                          innerData['ticker'] ?? 
                          innerData['ticker_text'] ?? 
                          innerData['tickerText'];
          }
          if (tickersData == null && data['cluster'] is Map) {
            final innerData = data['cluster'] as Map;
            tickersData = innerData['header_text'] ?? 
                          innerData['headerText'] ?? 
                          innerData['tickers'] ?? 
                          innerData['ticker'] ?? 
                          innerData['ticker_text'] ?? 
                          innerData['tickerText'];
          }

          if (tickersData != null) {
            final List<TickerItem> parsedTickers = [];
            if (tickersData is List) {
              for (final item in tickersData) {
                if (item is Map) {
                  parsedTickers.add(TickerItem.fromJson(Map<String, dynamic>.from(item)));
                } else if (item != null) {
                  parsedTickers.add(TickerItem(
                    id: parsedTickers.length + 1,
                    text: item.toString(),
                  ));
                }
              }
            } else if (tickersData is Map) {
              parsedTickers.add(TickerItem.fromJson(Map<String, dynamic>.from(tickersData)));
            } else {
              parsedTickers.add(TickerItem(
                id: 1,
                text: tickersData.toString(),
              ));
            }

            if (parsedTickers.isNotEmpty) {
              print('Parsed ${parsedTickers.length} ticker items from sync successfully: ${parsedTickers.map((e) => e.text).join(", ")}');
              await currentRefAfterFetch.read(tickersProvider.notifier).updateTickers(parsedTickers);
            }
          }

          // Capture screen if requested
          if (takeScreenshot) {
            await ScreenshotService.captureAndUpload(screenId);
          }

          // Handle software restarts (reloads cached lists)
          if (restartFlag) {
            await currentRefAfterFetch.read(activationProvider.notifier).refreshActivationDetails();
            await currentRefAfterFetch.read(playlistProvider.notifier).loadCachedPlaylist();
          }

          // Update local version tracker
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('playlist_version', serverVersion);
        }
      } else {
        print('Sync check returned error status: ${response.statusCode}');
        if (response.statusCode == 422 ||
            response.statusCode == 401 ||
            response.statusCode == 400) {
          try {
            final data = jsonDecode(response.body);
            final isInvalidScreen =
                data is Map &&
                (data['message']?.toString().toLowerCase().contains(
                          'invalid',
                        ) ==
                    true ||
                    data['errors']?.toString().toLowerCase().contains(
                          'screen_id',
                        ) ==
                    true);

            if (isInvalidScreen) {
              print('Screen ID $screenId is reported invalid by server. Attempting to refresh activation...');
              final success = await currentRef
                  .read(activationProvider.notifier)
                  .refreshActivationDetails();
              if (success) {
                print('Activation details refreshed successfully.');
              } else {
                print('Failed to refresh activation, disconnecting screen...');
                await currentRef.read(activationProvider.notifier).disconnect();
              }
            }
          } catch (e) {
            print('Failed to parse sync error response: $e');
          }
        }
      }
    } catch (e) {
      print('Sync ping connection failure: $e');
    }
  }

  Future<void> _runScheduleSync(String screenId) async {
    print('Fetching playlist schedule for Screen ID: $screenId...');
    try {
      final scheduleUrl = Uri.parse(
        'https://cms.thelocads.com/api/player/schedule?screen_id=$screenId',
      );

      final response = await http.get(
        scheduleUrl,
        headers: {'Accept': 'application/json'},
      );

      final currentRef = _ref;
      if (currentRef == null || !currentRef.context.mounted) return;

      if (response.statusCode == 200) {
        print('Raw schedule API response: ${response.body}');
        final data = jsonDecode(response.body);
        
        if (data is Map) {
          String? layout = data['layout_type']?.toString() ?? data['layout']?.toString();
          if (layout == null && data['data'] is Map) {
            layout = (data['data'] as Map)['layout_type']?.toString() ?? (data['data'] as Map)['layout']?.toString();
          }
          if (layout == null && data['cluster'] is Map) {
            layout = (data['cluster'] as Map)['layout_type']?.toString() ?? (data['cluster'] as Map)['layout']?.toString();
          }
          if (layout != null && layout.isNotEmpty) {
            await currentRef.read(activationProvider.notifier).updateLayout(layout);
          }

          dynamic tickersData = data['header_text'] ?? 
                              data['headerText'] ?? 
                              data['ticker_type'] ?? 
                              data['tickerType'] ?? 
                              data['tickers'] ?? 
                              data['ticker'] ?? 
                              data['ticker_text'] ?? 
                              data['tickerText'] ?? 
                              data['tickers_text'];
                              
          if (tickersData == null && data['data'] is Map) {
            final innerData = data['data'] as Map;
            tickersData = innerData['header_text'] ?? 
                          innerData['headerText'] ?? 
                          innerData['tickers'] ?? 
                          innerData['ticker'] ?? 
                          innerData['ticker_text'] ?? 
                          innerData['tickerText'];
          }
          if (tickersData == null && data['cluster'] is Map) {
            final innerData = data['cluster'] as Map;
            tickersData = innerData['header_text'] ?? 
                          innerData['headerText'] ?? 
                          innerData['tickers'] ?? 
                          innerData['ticker'] ?? 
                          innerData['ticker_text'] ?? 
                          innerData['tickerText'];
          }

          if (tickersData != null) {
            final List<TickerItem> parsedTickers = [];
            if (tickersData is List) {
              for (final item in tickersData) {
                if (item is Map) {
                  parsedTickers.add(TickerItem.fromJson(Map<String, dynamic>.from(item)));
                } else if (item != null) {
                  parsedTickers.add(TickerItem(
                    id: parsedTickers.length + 1,
                    text: item.toString(),
                  ));
                }
              }
            } else if (tickersData is Map) {
              parsedTickers.add(TickerItem.fromJson(Map<String, dynamic>.from(tickersData)));
            } else {
              parsedTickers.add(TickerItem(
                id: 1,
                text: tickersData.toString(),
              ));
            }

            if (parsedTickers.isNotEmpty) {
              print('Parsed ${parsedTickers.length} ticker items successfully: ${parsedTickers.map((e) => e.text).join(", ")}');
              await currentRef.read(tickersProvider.notifier).updateTickers(parsedTickers);
            }
          }
        }

        List<dynamic>? playlistData;
        if (data is List) {
          playlistData = data;
        } else if (data is Map && data['playlist'] is List) {
          playlistData = data['playlist'] as List<dynamic>;
        }

        if (playlistData != null) {
          // Parse JSON entries
          final List<MediaItem> items = playlistData.map((json) {
            return MediaItem.fromJson(json as Map<String, dynamic>);
          }).toList();
          print('Parsed ${items.length} media items from schedule.');

          // Caches files internally and updates provider list
          await currentRef.read(playlistProvider.notifier).updatePlaylist(items);
        } else {
          print(
            'Schedule response body is not a list or a valid playlist map.',
          );
        }
      } else {
        print(
          'Schedule fetch returned error status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      print('Schedule synchronization failed: $e');
    }
  }
}
