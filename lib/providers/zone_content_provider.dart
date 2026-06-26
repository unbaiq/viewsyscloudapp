import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/media_item.dart';

class ZoneContentState {
  final List<MediaItem> items;
  final int currentIndex;
  final bool isLoading;
  final String? errorMessage;

  const ZoneContentState({
    this.items = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  MediaItem? get item {
    if (items.isEmpty) return null;
    if (currentIndex >= items.length) return items[0];
    return items[currentIndex];
  }

  ZoneContentState copyWith({
    List<MediaItem>? items,
    int? currentIndex,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ZoneContentState(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ZoneContentNotifier extends StateNotifier<ZoneContentState> {
  ZoneContentNotifier() : super(const ZoneContentState(isLoading: true));

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String message) {
    state = state.copyWith(isLoading: false, errorMessage: message);
  }

  void updateItems(List<MediaItem> newItems) {
    if (state.items.length == newItems.length) {
      bool isIdentical = true;
      for (int i = 0; i < newItems.length; i++) {
        final a = state.items[i];
        final b = newItems[i];
        if (a.id != b.id || a.url != b.url || a.localPath != b.localPath) {
          isIdentical = false;
          break;
        }
      }
      if (isIdentical) return;
    }

    int nextIndex = state.currentIndex;
    if (nextIndex >= newItems.length) {
      nextIndex = 0;
    }
    
    state = ZoneContentState(
      items: newItems,
      currentIndex: nextIndex,
      isLoading: false,
    );
  }

  void updateItem(MediaItem item) {
    updateItems([item]);
  }

  void nextItem() {
    if (state.items.isEmpty) return;
    int next = state.currentIndex + 1;
    if (next >= state.items.length) {
      next = 0;
    }
    state = state.copyWith(currentIndex: next);
  }
}

final zoneContentProvider = StateNotifierProvider<ZoneContentNotifier, ZoneContentState>((ref) {
  return ZoneContentNotifier();
});

final leftZoneProvider = StateNotifierProvider<ZoneContentNotifier, ZoneContentState>((ref) {
  return ZoneContentNotifier();
});

final centerZoneProvider = StateNotifierProvider<ZoneContentNotifier, ZoneContentState>((ref) {
  return ZoneContentNotifier();
});

final rightZoneProvider = StateNotifierProvider<ZoneContentNotifier, ZoneContentState>((ref) {
  return ZoneContentNotifier();
});

final topRightZoneProvider = StateNotifierProvider<ZoneContentNotifier, ZoneContentState>((ref) {
  return ZoneContentNotifier();
});

final bottomLeftZoneProvider = StateNotifierProvider<ZoneContentNotifier, ZoneContentState>((ref) {
  return ZoneContentNotifier();
});

final bottomRightZoneProvider = StateNotifierProvider<ZoneContentNotifier, ZoneContentState>((ref) {
  return ZoneContentNotifier();
});
