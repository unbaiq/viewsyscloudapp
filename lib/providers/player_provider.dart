import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../services/database_helper.dart';
import '../services/file_manager.dart';
import '../services/video_preload_manager.dart';

// --- Activation State Model & Notifier ---

class ActivationState {
  final bool isActivated;
  final String deviceCode;
  final String screenId;
  final String companyId;
  final String orientation;
  final int syncInterval;
  final bool isLoading;

  ActivationState({
    required this.isActivated,
    required this.deviceCode,
    required this.screenId,
    required this.companyId,
    required this.orientation,
    required this.syncInterval,
    this.isLoading = false,
  });

  ActivationState copyWith({
    bool? isActivated,
    String? deviceCode,
    String? screenId,
    String? companyId,
    String? orientation,
    int? syncInterval,
    bool? isLoading,
  }) {
    return ActivationState(
      isActivated: isActivated ?? this.isActivated,
      deviceCode: deviceCode ?? this.deviceCode,
      screenId: screenId ?? this.screenId,
      companyId: companyId ?? this.companyId,
      orientation: orientation ?? this.orientation,
      syncInterval: syncInterval ?? this.syncInterval,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ActivationNotifier extends StateNotifier<ActivationState> {
  ActivationNotifier()
      : super(ActivationState(
          isActivated: false,
          deviceCode: '------',
          screenId: '',
          companyId: '',
          orientation: 'landscape',
          syncInterval: 10,
          isLoading: true, // Initial loading is true
        )) {
    loadActivationFromPrefs();
  }

  /// Initial load from disk SharedPreferences
  Future<void> loadActivationFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isActivated = prefs.getBool('is_activated') ?? false;
    final deviceCode = prefs.getString('activation_code') ?? '------';
    final screenId = prefs.getString('screen_id') ?? '';
    final companyId = prefs.getString('company_id') ?? '';
    final orientation = prefs.getString('orientation') ?? 'landscape';
    final syncIntervalStr = prefs.getString('sync_interval') ?? '10';
    final syncInterval = int.tryParse(syncIntervalStr) ?? 10;

    state = ActivationState(
      isActivated: isActivated && deviceCode != '------' && screenId.isNotEmpty,
      deviceCode: deviceCode,
      screenId: screenId,
      companyId: companyId,
      orientation: orientation,
      syncInterval: syncInterval,
      isLoading: false, // Finished loading
    );
  }

  /// Registers server authorization details
  Future<void> activateDevice({
    required String screenId,
    required String companyId,
    required String orientation,
    required int syncInterval,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_activated', true);
    await prefs.setString('screen_id', screenId);
    await prefs.setString('company_id', companyId);
    await prefs.setString('orientation', orientation);
    await prefs.setString('sync_interval', syncInterval.toString());

    state = state.copyWith(
      isActivated: true,
      screenId: screenId,
      companyId: companyId,
      orientation: orientation,
      syncInterval: syncInterval,
      isLoading: false, // Ensure loading is false on activation
    );
  }

  /// Update layout orientation dynamically from central CMS sync pings
  Future<void> updateOrientation(String newOrientation) async {
    if (state.orientation == newOrientation) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('orientation', newOrientation);
    state = state.copyWith(orientation: newOrientation);
  }

  /// Refreshes the activation details from the server using the saved device/pairing code.
  Future<bool> refreshActivationDetails() async {
    if (state.deviceCode == '------' || state.deviceCode.isEmpty) return false;

    try {
      final url = Uri.parse('https://viewsys.co.in/api/player/login');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'device_id': state.deviceCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'authorized') {
          final screenId = data['screen_id']?.toString() ?? '';
          final companyId = data['company_id']?.toString() ?? '';
          final orientation = data['orientation']?.toString() ?? 'landscape';
          final syncIntervalStr = data['sync_interval']?.toString() ?? '10';
          final syncInterval = int.tryParse(syncIntervalStr) ?? 10;

          await activateDevice(
            screenId: screenId,
            companyId: companyId,
            orientation: orientation,
            syncInterval: syncInterval,
          );
          return true;
        } else {
          print('Device status is not authorized: ${data['status']}. Deactivating screen.');
          await _deactivateDevice();
          return false;
        }
      } else if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 404 || response.statusCode == 422) {
        print('Login API returned error status: ${response.statusCode}. Deactivating screen.');
        await _deactivateDevice();
        return false;
      }
    } catch (e) {
      print('Failed to refresh activation details: $e');
    }
    return false;
  }

  Future<void> _deactivateDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_activated', false);
    
    // Wipe cached playlists and local files
    await DatabaseHelper.instance.clearPlaylist();
    await FileManager.instance.clearAllCachedMedia();

    // Clear preloaded video controllers
    VideoPreloadManager.instance.clearAll();

    state = state.copyWith(
      isActivated: false,
      screenId: '',
      companyId: '',
    );
  }

  /// Disconnects screen link, wipes SharedPreferences database, and returns to ActivationScreen
  Future<void> disconnect() async {
    state = state.copyWith(isLoading: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_activated');
    await prefs.remove('activation_code');
    await prefs.remove('screen_id');
    await prefs.remove('company_id');
    await prefs.remove('orientation');
    await prefs.remove('sync_interval');

    // Wipe cached playlists and local files
    await DatabaseHelper.instance.clearPlaylist();
    await FileManager.instance.clearAllCachedMedia();

    // Clear preloaded video controllers
    VideoPreloadManager.instance.clearAll();

    state = ActivationState(
      isActivated: false,
      deviceCode: '------',
      screenId: '',
      companyId: '',
      orientation: 'landscape',
      syncInterval: 10,
      isLoading: false,
    );
  }
}

final activationProvider = StateNotifierProvider<ActivationNotifier, ActivationState>((ref) {
  return ActivationNotifier();
});

// --- Playlist Playback State Model & Notifier ---

class PlaylistState {
  final List<MediaItem> items;
  final int currentIndex;
  final bool isLoading;
  final String? errorMessage;
  final bool hasInitialized;

  PlaylistState({
    required this.items,
    this.currentIndex = 0,
    this.isLoading = false,
    this.errorMessage,
    this.hasInitialized = false,
  });

  PlaylistState copyWith({
    List<MediaItem>? items,
    int? currentIndex,
    bool? isLoading,
    String? errorMessage,
    bool? hasInitialized,
  }) {
    return PlaylistState(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      hasInitialized: hasInitialized ?? this.hasInitialized,
    );
  }
}

class PlaylistNotifier extends StateNotifier<PlaylistState> {
  PlaylistNotifier() : super(PlaylistState(items: [], hasInitialized: false)) {
    loadCachedPlaylist();
  }

  /// Load cached items from DB on startup
  Future<void> loadCachedPlaylist() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await DatabaseHelper.instance.getPlaylist();
      state = PlaylistState(
        items: items,
        currentIndex: _findFirstValidIndex(items),
        isLoading: false,
        hasInitialized: items.isNotEmpty,
      );

      if (items.isNotEmpty) {
        // Resolve orientations in the background and update state when done
        _resolveOrientations(items).then((resolved) {
          state = state.copyWith(items: resolved);
          _preloadNextItem();
        });
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load cached playlist: $e',
      );
    }
  }

  /// Mark that initial sync/check has completed
  void markInitialized() {
    if (!state.hasInitialized) {
      state = state.copyWith(hasInitialized: true);
    }
  }

  /// Replaces the playlist schedule with new server schema, caches media files,
  /// and updates SQLite database.
  Future<void> updatePlaylist(List<MediaItem> newItems) async {
    state = state.copyWith(isLoading: true);
    try {
      // 1. Download and cache media files locally in background in parallel
      final List<MediaItem> cachedItems = await Future.wait(
        newItems.map((item) async {
          final localPath = await FileManager.instance.downloadFile(item.url, item.id, item.type);
          return item.copyWith(localPath: localPath);
        }),
      );

      // 2. Save items to Database
      await DatabaseHelper.instance.savePlaylist(cachedItems);

      // 3. Clean up unreferenced files from local storage
      await FileManager.instance.cleanUnusedFiles(cachedItems);

      // Pre-resolve orientations in background before updating UI state so playing is instant!
      final resolvedItems = await _resolveOrientations(cachedItems);

      // 4. Update memory state
      state = PlaylistState(
        items: resolvedItems,
        currentIndex: _findFirstValidIndex(resolvedItems),
        isLoading: false,
        hasInitialized: true,
      );
      _preloadNextItem();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update playlist: $e',
      );
    }
  }

  /// Increments sequence pointer to select the next valid scheduled item.
  void nextItem() {
    if (state.items.isEmpty) return;

    final startIdx = state.currentIndex;
    int nextIdx = (startIdx + 1) % state.items.length;
    final now = DateTime.now();

    // Loop through checklist to find the next active item
    while (nextIdx != startIdx) {
      if (state.items[nextIdx].isValidNow(now)) {
        state = state.copyWith(currentIndex: nextIdx);
        _preloadNextItem();
        return;
      }
      nextIdx = (nextIdx + 1) % state.items.length;
    }

    // Default to first index if nothing is valid or everything is checked
  }

  /// Helper to locate first valid index according to scheduling rules
  int _findFirstValidIndex(List<MediaItem> list) {
    if (list.isEmpty) return 0;
    final now = DateTime.now();
    for (int i = 0; i < list.length; i++) {
      if (list[i].isValidNow(now)) {
        return i;
      }
    }
    return 0;
  }

  /// Pre-resolves the orientation (landscape/portrait) for all items in the playlist.
  Future<List<MediaItem>> _resolveOrientations(List<MediaItem> items) async {
    // Return items directly. Resolving orientation of all media items by initializing
    // network players/downloading image streams is extremely expensive and causes
    // severe network stuttering/pauses during video playback.
    return items;
  }

  /// Finds the next valid index starting after the current index.
  int getNextValidIndex() {
    if (state.items.isEmpty) return -1;
    final startIdx = state.currentIndex;
    int nextIdx = (startIdx + 1) % state.items.length;
    final now = DateTime.now();

    while (nextIdx != startIdx) {
      if (state.items[nextIdx].isValidNow(now)) {
        return nextIdx;
      }
      nextIdx = (nextIdx + 1) % state.items.length;
    }
    return -1;
  }

  /// Triggers background preloading for the next video item.
  void _preloadNextItem() {
    final nextIdx = getNextValidIndex();
    if (nextIdx != -1) {
      final nextItem = state.items[nextIdx];
      if (nextItem.type == 'video') {
        VideoPreloadManager.instance.preload(nextItem);
      }
      // Keep only the current item and the next item controllers
      final currentItem = state.items[state.currentIndex];
      VideoPreloadManager.instance.keepOnly([currentItem.id, nextItem.id]);
    }
  }
}

final playlistProvider = StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
  return PlaylistNotifier();
});
