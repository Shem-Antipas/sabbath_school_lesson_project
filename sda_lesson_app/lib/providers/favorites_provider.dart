import 'package:flutter_riverpod/flutter_riverpod.dart';

// The Notifier Class
class FavoritesNotifier extends StateNotifier<List<String>> {
  FavoritesNotifier() : super([]);

  void toggleFavorite(String bookCode) {
    if (state.contains(bookCode)) {
      state = state.where((code) => code != bookCode).toList();
    } else {
      state = [...state, bookCode];
    }
  }

  void clearAll() {
    state = [];
  }
}

// THE PROVIDER (Ensure the types inside < > are correct)
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
      return FavoritesNotifier();
    });
