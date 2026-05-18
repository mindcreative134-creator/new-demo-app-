// filmsclub_flutter_app/lib/models/media.dart

class QualityDetail {
  final String quality;
  final String id;
  final String name;
  final String size;

  QualityDetail({
    required this.quality,
    required this.id,
    required this.name,
    required this.size,
  });

  factory QualityDetail.fromJson(Map<String, dynamic> json) {
    return QualityDetail(
      quality: json['quality'] ?? 'HD',
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      size: json['size'] ?? '',
    );
  }
}

class Episode {
  final int episodeNumber;
  final String title;
  final String episodeBackdrop;
  final List<QualityDetail> telegram;

  Episode({
    required this.episodeNumber,
    required this.title,
    required this.episodeBackdrop,
    required this.telegram,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    var list = json['telegram'] as List? ?? [];
    List<QualityDetail> tgList = list.map((i) => QualityDetail.fromJson(i)).toList();
    return Episode(
      episodeNumber: json['episode_number'] ?? 1,
      title: json['title'] ?? '',
      episodeBackdrop: json['episode_backdrop'] ?? '',
      telegram: tgList,
    );
  }
}

class Season {
  final int seasonNumber;
  final List<Episode> episodes;

  Season({
    required this.seasonNumber,
    required this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    var list = json['episodes'] as List? ?? [];
    List<Episode> epList = list.map((i) => Episode.fromJson(i)).toList();
    return Season(
      seasonNumber: json['season_number'] ?? 1,
      episodes: epList,
    );
  }
}

class Movie {
  final int tmdbId;
  final String title;
  final List<String> genres;
  final String description;
  final double rating;
  final int releaseYear;
  final String poster;
  final String backdrop;
  final String mediaType;
  final int runtime;
  final String rip;
  final List<QualityDetail> telegram;

  Movie({
    required this.tmdbId,
    required this.title,
    required this.genres,
    required this.description,
    required this.rating,
    required this.releaseYear,
    required this.poster,
    required this.backdrop,
    required this.mediaType,
    required this.runtime,
    required this.rip,
    required this.telegram,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    var genList = List<String>.from(json['genres'] ?? []);
    var tgList = (json['telegram'] as List? ?? []).map((i) => QualityDetail.fromJson(i)).toList();
    return Movie(
      tmdbId: json['tmdb_id'] ?? 0,
      title: json['title'] ?? '',
      genres: genList,
      description: json['description'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      releaseYear: json['release_year'] ?? 2026,
      poster: json['poster'] ?? '',
      backdrop: json['backdrop'] ?? '',
      mediaType: json['media_type'] ?? 'movie',
      runtime: json['runtime'] ?? 0,
      rip: json['rip'] ?? 'WEBRip',
      telegram: tgList,
    );
  }
}

class TVShow {
  final int tmdbId;
  final String title;
  final List<String> genres;
  final String description;
  final double rating;
  final int releaseYear;
  final String poster;
  final String backdrop;
  final String mediaType;
  final int totalSeasons;
  final int totalEpisodes;
  final String status;
  final String rip;
  final List<Season> seasons;

  TVShow({
    required this.tmdbId,
    required this.title,
    required this.genres,
    required this.description,
    required this.rating,
    required this.releaseYear,
    required this.poster,
    required this.backdrop,
    required this.mediaType,
    required this.totalSeasons,
    required this.totalEpisodes,
    required this.status,
    required this.rip,
    required this.seasons,
  });

  factory TVShow.fromJson(Map<String, dynamic> json) {
    var genList = List<String>.from(json['genres'] ?? []);
    var seaList = (json['seasons'] as List? ?? []).map((i) => Season.fromJson(i)).toList();
    return TVShow(
      tmdbId: json['tmdb_id'] ?? 0,
      title: json['title'] ?? '',
      genres: genList,
      description: json['description'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      releaseYear: json['release_year'] ?? 2026,
      poster: json['poster'] ?? '',
      backdrop: json['backdrop'] ?? '',
      mediaType: json['media_type'] ?? 'tv',
      totalSeasons: json['total_seasons'] ?? 0,
      totalEpisodes: json['total_episodes'] ?? 0,
      status: json['status'] ?? 'Ended',
      rip: json['rip'] ?? 'WEBRip',
      seasons: seaList,
    );
  }
}

class LiveChannel {
  final String id;
  final String name;
  final String logo;
  final String category;
  final String language;
  final String streamUrl;
  final String? epgId;
  final String? description;
  final String quality;
  final String country;

  LiveChannel({
    required this.id,
    required this.name,
    required this.logo,
    required this.category,
    required this.language,
    required this.streamUrl,
    this.epgId,
    this.description,
    required this.quality,
    required this.country,
  });

  factory LiveChannel.fromJson(Map<String, dynamic> json) {
    return LiveChannel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'] ?? '',
      category: json['category'] ?? 'Entertainment',
      language: json['language'] ?? 'Hindi',
      streamUrl: json['stream_url'] ?? '',
      epgId: json['epg_id'],
      description: json['description'],
      quality: json['quality'] ?? 'HD',
      country: json['country'] ?? 'India',
    );
  }
}

class EditorialPost {
  final String id;
  final String title;
  final String content;
  final String banner;
  final String category;
  final List<String> tags;
  final String author;
  final DateTime publishedOn;

  EditorialPost({
    required this.id,
    required this.title,
    required this.content,
    required this.banner,
    required this.category,
    required this.tags,
    required this.author,
    required this.publishedOn,
  });

  factory EditorialPost.fromJson(Map<String, dynamic> json) {
    return EditorialPost(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      banner: json['banner'] ?? '',
      category: json['category'] ?? 'General',
      tags: List<String>.from(json['tags'] ?? []),
      author: json['author'] ?? 'Admin',
      publishedOn: DateTime.parse(json['published_on'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class SportsFixture {
  final String id;
  final String title;
  final String teamA;
  final String teamB;
  final String teamALogo;
  final String teamBLogo;
  final String sportType;
  final String status;
  final String? score;
  final DateTime startTime;
  final String? streamUrl;
  final String? highlightsUrl;

  SportsFixture({
    required this.id,
    required this.title,
    required this.teamA,
    required this.teamB,
    required this.teamALogo,
    required this.teamBLogo,
    required this.sportType,
    required this.status,
    this.score,
    required this.startTime,
    this.streamUrl,
    this.highlightsUrl,
  });

  factory SportsFixture.fromJson(Map<String, dynamic> json) {
    return SportsFixture(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      teamA: json['team_a'] ?? '',
      teamB: json['team_b'] ?? '',
      teamALogo: json['team_a_logo'] ?? '',
      teamBLogo: json['team_b_logo'] ?? '',
      sportType: json['sport_type'] ?? 'Cricket',
      status: json['status'] ?? 'Scheduled',
      score: json['score'],
      startTime: DateTime.parse(json['start_time'] ?? DateTime.now().toIso8601String()),
      streamUrl: json['stream_url'],
      highlightsUrl: json['highlights_url'],
    );
  }
}
