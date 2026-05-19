// filmsclub_flutter_app/lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media.dart';

class ApiService {
  // Set your local backend address. 10.0.2.2 is the default IP used by the Android emulator
  // to reference the localhost of the development machine running the server.
  static const String baseUrl = "https://new-demo-app.onrender.com";

  // --- OTT SECTION API ---
  
  static Future<List<Movie>> fetchMovies({String sortBy = "updated_on:desc", int page = 1, int pageSize = 40}) async {
    final url = Uri.parse("$baseUrl/api/movies?sort_by=$sortBy&page=$page&page_size=$pageSize");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['movies'] as List? ?? [];
        return list.map((item) => Movie.fromJson(item)).toList();
      }
    } catch (e) {
      print("Error fetching movies: $e");
    }
    return [];
  }

  static Future<List<TVShow>> fetchTVShows({String sortBy = "updated_on:desc", int page = 1, int pageSize = 40}) async {
    final url = Uri.parse("$baseUrl/api/tvshows?sort_by=$sortBy&page=$page&page_size=$pageSize");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['tv_shows'] as List? ?? [];
        return list.map((item) => TVShow.fromJson(item)).toList();
      }
    } catch (e) {
      print("Error fetching TV shows: $e");
    }
    return [];
  }

  static Future<dynamic> fetchMediaDetails(int tmdbId, {int? season, int? episode}) async {
    String endpoint = "$baseUrl/api/id/$tmdbId";
    if (season != null && episode != null) {
      endpoint += "?season_number=$season&episode_number=$episode";
    } else if (season != null) {
      endpoint += "?season_number=$season";
    }
    final url = Uri.parse(endpoint);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['type'] == 'movie') {
          return Movie.fromJson(data);
        } else if (data['type'] == 'tv') {
          return TVShow.fromJson(data);
        }
        return data;
      }
    } catch (e) {
      print("Error fetching media details: $e");
    }
    return null;
  }

  static Future<List<dynamic>> fetchSimilarMedia(int tmdbId, String mediaType) async {
    final url = Uri.parse("$baseUrl/api/similar/?tmdb_id=$tmdbId&media_type=$mediaType&page_size=10");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['similar_media'] as List? ?? [];
        return list.map((item) {
          if (mediaType == 'movie') {
            return Movie.fromJson(item);
          } else {
            return TVShow.fromJson(item);
          }
        }).toList();
      }
    } catch (e) {
      print("Error fetching similar media: $e");
    }
    return [];
  }

  // --- LIVE TV SECTION API ---

  static Future<List<LiveChannel>> fetchChannels({String? category}) async {
    String endpoint = "$baseUrl/api/channels?page_size=50";
    if (category != null) {
      endpoint += "&category=$category";
    }
    final url = Uri.parse(endpoint);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['channels'] as List? ?? [];
        return list.map((item) => LiveChannel.fromJson(item)).toList();
      }
    } catch (e) {
      print("Error fetching live channels: $e");
    }
    return [];
  }

  // --- EDITORIAL POSTS API ---

  static Future<List<EditorialPost>> fetchEditorialPosts({String? category}) async {
    String endpoint = "$baseUrl/api/editorial?page_size=30";
    if (category != null) {
      endpoint += "&category=$category";
    }
    final url = Uri.parse(endpoint);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['posts'] as List? ?? [];
        return list.map((item) => EditorialPost.fromJson(item)).toList();
      }
    } catch (e) {
      print("Error fetching editorial posts: $e");
    }
    return [];
  }

  // --- SPORTS HUB API ---

  static Future<List<SportsFixture>> fetchSportsFixtures({String? sportType, String? status}) async {
    String endpoint = "$baseUrl/api/sports/fixtures";
    List<String> queryParams = [];
    if (sportType != null) queryParams.add("sport_type=$sportType");
    if (status != null) queryParams.add("status=$status");
    if (queryParams.isNotEmpty) {
      endpoint += "?" + queryParams.join("&");
    }
    
    final url = Uri.parse(endpoint);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List list = json.decode(response.body) as List? ?? [];
        return list.map((item) => SportsFixture.fromJson(item)).toList();
      }
    } catch (e) {
      print("Error fetching sports fixtures: $e");
    }
    return [];
  }

  // --- WATCHLIST & CONTINUE WATCHING ---

  static Future<bool> syncWatchlistAction(String userId, int mediaId, String mediaType, String title, String poster, bool add) async {
    final url = add 
      ? Uri.parse("$baseUrl/api/user/watchlist?user_id=$userId&media_id=$mediaId&media_type=$mediaType&title=${Uri.encodeComponent(title)}&poster=${Uri.encodeComponent(poster)}")
      : Uri.parse("$baseUrl/api/user/watchlist?user_id=$userId&media_id=$mediaId");

    try {
      final response = add 
        ? await http.post(url)
        : await http.delete(url);
      if (response.statusCode == 200) {
        return json.decode(response.body)['status'] == 'success';
      }
    } catch (e) {
      print("Error syncing watchlist action: $e");
    }
    return false;
  }

  static Future<List<dynamic>> getWatchlist(String userId) async {
    final url = Uri.parse("$baseUrl/api/user/watchlist?user_id=$userId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List? ?? [];
      }
    } catch (e) {
      print("Error fetching watchlist: $e");
    }
    return [];
  }

  static Future<bool> updateContinueWatching(String userId, int mediaId, String mediaType, String title, String poster, double progress, double duration) async {
    final url = Uri.parse("$baseUrl/api/user/continue?user_id=$userId&media_id=$mediaId&media_type=$mediaType&title=${Uri.encodeComponent(title)}&poster=${Uri.encodeComponent(poster)}&progress=$progress&duration=$duration");
    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        return json.decode(response.body)['status'] == 'success';
      }
    } catch (e) {
      print("Error updating continue watching: $e");
    }
    return false;
  }

  static Future<List<dynamic>> getContinueWatching(String userId) async {
    final url = Uri.parse("$baseUrl/api/user/continue?user_id=$userId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List? ?? [];
      }
    } catch (e) {
      print("Error fetching continue watching list: $e");
    }
    return [];
  }

  // --- ANALYTICS AND TRACKING ---

  static Future<void> trackUserAction(String userId, String action, String mediaId, String mediaTitle) async {
    final url = Uri.parse("$baseUrl/api/analytics/track?user_id=$userId&action=$action&media_id=$mediaId&media_title=${Uri.encodeComponent(mediaTitle)}");
    try {
      await http.post(url);
    } catch (e) {
      print("Error tracking user event: $e");
    }
  }

  // --- UNIFIED GLOBAL SEARCH ENGINE ---

  static Future<Map<String, List<dynamic>>> searchEverything(String query) async {
    final url = Uri.parse("$baseUrl/api/search/all?query=${Uri.encodeComponent(query)}");
    Map<String, List<dynamic>> results = {
      "media": [],
      "channels": [],
      "editorials": [],
      "sports": []
    };
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final mediaList = data['media'] as List? ?? [];
        results['media'] = mediaList;
        
        final channelsList = data['channels'] as List? ?? [];
        results['channels'] = channelsList.map((c) => LiveChannel.fromJson(c)).toList();
        
        final editorialList = data['editorials'] as List? ?? [];
        results['editorials'] = editorialList.map((e) => EditorialPost.fromJson(e)).toList();
        
        final sportsList = data['sports'] as List? ?? [];
        results['sports'] = sportsList.map((f) => SportsFixture.fromJson(f)).toList();
      }
    } catch (e) {
      print("Global search failed: $e");
    }
    return results;
  }
}
