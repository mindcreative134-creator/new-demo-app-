// filmsclub_flutter_app/lib/providers/app_state.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  String _userId = "";
  List<dynamic> _watchlist = [];
  List<dynamic> _continueWatching = [];
  
  bool _isLoading = false;
  bool _isSearching = false;
  String _searchQuery = "";
  Map<String, List<dynamic>> _searchResults = {
    "media": [],
    "channels": [],
    "editorials": [],
    "sports": []
  };

  // Getters
  String get userId => _userId;
  List<dynamic> get watchlist => _watchlist;
  List<dynamic> get continueWatching => _continueWatching;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;
  Map<String, List<dynamic>> get searchResults => _searchResults;

  // Initialize and load user data
  Future<void> initUser() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString("user_unique_id");
    
    if (storedId == null) {
      // Generate a persistent user ID for analytics tracking
      var rand = Random();
      storedId = "user_${rand.nextInt(1000000) + 100000}";
      await prefs.setString("user_unique_id", storedId);
    }
    
    _userId = storedId;
    
    // Fetch data from backend API
    await fetchWatchlist();
    await fetchContinueWatching();
    
    _isLoading = false;
    notifyListeners();
  }

  // --- Watchlist Action Handlers ---

  Future<void> fetchWatchlist() async {
    if (_userId.isEmpty) return;
    _watchlist = await ApiService.getWatchlist(_userId);
    notifyListeners();
  }

  bool isAddedToWatchlist(int mediaId) {
    return _watchlist.any((item) => item['media_id'] == mediaId);
  }

  Future<void> toggleWatchlist(int mediaId, String mediaType, String title, String poster) async {
    final added = isAddedToWatchlist(mediaId);
    final success = await ApiService.syncWatchlistAction(_userId, mediaId, mediaType, title, poster, !added);
    
    if (success) {
      await fetchWatchlist();
      // Track action in analytics server
      ApiService.trackUserAction(_userId, added ? "remove_watchlist" : "add_watchlist", mediaId.toString(), title);
    }
  }

  // --- Continue Watching Action Handlers ---

  Future<void> fetchContinueWatching() async {
    if (_userId.isEmpty) return;
    _continueWatching = await ApiService.getContinueWatching(_userId);
    notifyListeners();
  }

  Future<void> saveContinueProgress(int mediaId, String mediaType, String title, String poster, double progress, double duration) async {
    final success = await ApiService.updateContinueWatching(_userId, mediaId, mediaType, title, poster, progress, duration);
    if (success) {
      await fetchContinueWatching();
    }
  }

  // --- Unified Global Search Handler ---

  void clearSearch() {
    _searchQuery = "";
    _isSearching = false;
    _searchResults = {
      "media": [],
      "channels": [],
      "editorials": [],
      "sports": []
    };
    notifyListeners();
  }

  Future<void> triggerGlobalSearch(String query) async {
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }
    
    _searchQuery = query;
    _isSearching = true;
    notifyListeners();
    
    _searchResults = await ApiService.searchEverything(query);
    
    // Track search action in background analytics
    ApiService.trackUserAction(_userId, "search", "query", query);
    
    _isSearching = false;
    notifyListeners();
  }
}
