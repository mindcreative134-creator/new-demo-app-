// filmsclub_flutter_app/lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/media.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import 'media_details_screen.dart';
import 'video_player_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) switchTabCallback; // Used to switch to dedicated tabs if requested

  const HomeScreen({Key? key, required this.switchTabCallback}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Movie> _trendingMovies = [];
  List<TVShow> _popularShows = [];
  List<LiveChannel> _topChannels = [];
  List<LiveChannel> _musicTV = [];
  List<SportsFixture> _liveSports = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    setState(() {
      _loading = true;
    });

    final movies = await ApiService.fetchMovies(sortBy: "rating:desc", pageSize: 10);
    final shows = await ApiService.fetchTVShows(sortBy: "rating:desc", pageSize: 10);
    final channels = await ApiService.fetchChannels();
    final sports = await ApiService.fetchSportsFixtures(status: "Live");

    setState(() {
      _trendingMovies = movies;
      _popularShows = shows;
      
      // Filter channels
      _topChannels = channels.where((c) => c.category == "Entertainment" || c.category == "Sports").take(10).toList();
      _musicTV = channels.where((c) => c.category == "Music").take(10).toList();
      
      _liveSports = sports;
      _loading = false;
    });
  }

  void _showSearchOverlay() {
    final appState = Provider.of<AppState>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff0b0a12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Pull handle
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                      ),
                      // Search Box
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search Movies, TV Channels, Live Sports...",
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () {
                              _searchController.clear();
                              appState.clearSearch();
                              setModalState(() {});
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) async {
                          await appState.triggerGlobalSearch(val);
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Search Results view
                      Expanded(
                        child: appState.isLoading 
                          ? const Center(child: SpinKitRing(color: Colors.deepPurpleAccent, size: 40))
                          : appState.searchQuery.isEmpty 
                            ? const Center(child: Text("Search everything inside the hybrid streaming catalog", style: TextStyle(color: Colors.white38)))
                            : ListView(
                                controller: scrollController,
                                children: [
                                  // 1. Movies & Shows Results
                                  if (appState.searchResults['media']!.isNotEmpty) ...[
                                    _buildSearchResultHeader("Movies & Web Series"),
                                    ...appState.searchResults['media']!.map((m) {
                                      return ListTile(
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.network(m['poster'], width: 40, height: 60, fit: BoxFit.cover, errorBuilder: (c,e,o) => const Icon(Icons.image)),
                                        ),
                                        title: Text(m['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        subtitle: Text("${m['media_type'].toString().toUpperCase()} • ${m['release_year']}", style: const TextStyle(color: Colors.white54)),
                                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => MediaDetailsScreen(tmdbId: m['tmdb_id'], mediaType: m['media_type']),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  ],
                                  
                                  // 2. Channels Results
                                  if (appState.searchResults['channels']!.isNotEmpty) ...[
                                    _buildSearchResultHeader("Live TV Channels"),
                                    ...appState.searchResults['channels']!.map((c) {
                                      final ch = c as LiveChannel;
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: NetworkImage(ch.logo),
                                          radius: 20,
                                        ),
                                        title: Text(ch.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        subtitle: Text("${ch.category} • ${ch.language} • ${ch.quality}", style: const TextStyle(color: Colors.white54)),
                                        trailing: const Icon(Icons.live_tv, color: Colors.purpleAccent, size: 20),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => VideoPlayerScreen(videoUrl: ch.streamUrl, title: ch.name, mediaType: "live_tv"),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResultHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xff0b0a12),
        body: Center(
          child: SpinKitRing(color: Colors.deepPurpleAccent, size: 60),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xff0b0a12),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP HUB BAR
            Container(
              padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
              color: const Color(0xff12101c),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Good Evening", style: TextStyle(color: Colors.white38, fontSize: 13)),
                      Text("Discovery Feed", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.04),
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: _showSearchOverlay,
                    ),
                  ),
                ],
              ),
            ),

            // HERO SLIDER CAROUSEL (Top Movie Spotlight Banner)
            if (_trendingMovies.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildHeroSpotlightBanner(_trendingMovies[0]),
            ],

            // 1. LIVE SPORTS HUB ROW
            if (_liveSports.isNotEmpty) ...[
              _buildSectionHeader("Live Matches (Sports Hub)", onTap: () => widget.switchTabCallback(3)),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _liveSports.length,
                  itemBuilder: (context, index) {
                    final fix = _liveSports[index];
                    return InkWell(
                      onTap: () => widget.switchTabCallback(3),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 250,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.15)),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(fix.sportType.toUpperCase(), style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                const Row(
                                  children: [
                                    CircleAvatar(radius: 3, backgroundColor: Colors.red),
                                    SizedBox(width: 4),
                                    Text("LIVE NOW", style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(fix.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text(fix.score ?? "Click to view scorecard", style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // 2. CONTINUE WATCHING (Resume State Playback Rows)
            if (appState.continueWatching.isNotEmpty) ...[
              _buildSectionHeader("Continue Watching"),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: appState.continueWatching.length,
                  itemBuilder: (context, index) {
                    final item = appState.continueWatching[index];
                    final progressRatio = (item['progress'] as num).toDouble() / (item['duration'] as num).toDouble();
                    
                    return InkWell(
                      onTap: () {
                        // Re-stream from progress point
                        final streamUrl = "${ApiService.baseUrl}/dl/${item['media_id']}/stream"; // Or custom playback route
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(
                              videoUrl: streamUrl,
                              title: item['title'],
                              mediaId: item['media_id'],
                              mediaType: item['media_type'],
                              poster: item['poster'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: item['poster'],
                                    height: 100,
                                    width: 140,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 4,
                                    color: Colors.white24,
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progressRatio.clamp(0.0, 1.0),
                                      child: Container(color: Colors.deepPurpleAccent),
                                    ),
                                  ),
                                ),
                                const Positioned.fill(
                                  child: Center(
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.play_arrow, color: Colors.white, size: 18),
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(item['title'], style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
                            Text(item['media_type'].toString().toUpperCase(), style: const TextStyle(color: Colors.white30, fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // 3. TRENDING MOVIES ROW
            if (_trendingMovies.isNotEmpty) ...[
              _buildSectionHeader("Trending Movies (OTT)", onTap: () => widget.switchTabCallback(1)),
              _buildMovieRow(_trendingMovies),
            ],

            // 4. TOP LIVE TV CHANNELS ROW
            if (_topChannels.isNotEmpty) ...[
              _buildSectionHeader("Popular Live TV Channels", onTap: () => widget.switchTabCallback(2)),
              _buildChannelRow(_topChannels),
            ],

            // 5. POPULAR WEB SERIES ROW
            if (_popularShows.isNotEmpty) ...[
              _buildSectionHeader("Popular Web Series (OTT)", onTap: () => widget.switchTabCallback(1)),
              _buildTVShowRow(_popularShows),
            ],

            // 6. MUSIC TELEVISION CHANNEL ROW
            if (_musicTV.isNotEmpty) ...[
              _buildSectionHeader("Music TV Channels", onTap: () => widget.switchTabCallback(2)),
              _buildChannelRow(_musicTV),
            ],
            
            const SizedBox(height: 45),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, left: 20.0, right: 20.0, bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Text("SEE ALL", style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroSpotlightBanner(Movie movie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => MediaDetailsScreen(tmdbId: movie.tmdbId, mediaType: "movie")));
      },
      child: Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(movie.backdrop),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                child: const Text("SPOTLIGHT", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Text(movie.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(movie.genres.join(" • "), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovieRow(List<Movie> list) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final m = list[index];
          return InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => MediaDetailsScreen(tmdbId: m.tmdbId, mediaType: "movie")));
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: m.poster,
                      height: 140,
                      width: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(m.title, style: const TextStyle(color: Colors.white70, fontSize: 12, overflow: TextOverflow.ellipsis), maxLines: 1),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTVShowRow(List<TVShow> list) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final s = list[index];
          return InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => MediaDetailsScreen(tmdbId: s.tmdbId, mediaType: "tv")));
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: s.poster,
                      height: 140,
                      width: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(s.title, style: const TextStyle(color: Colors.white70, fontSize: 12, overflow: TextOverflow.ellipsis), maxLines: 1),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelRow(List<LiveChannel> list) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final ch = list[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    videoUrl: ch.streamUrl,
                    title: ch.name,
                    mediaType: "live_tv",
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 80,
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(ch.logo),
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.04),
                  ),
                  const SizedBox(height: 8),
                  Text(ch.name, style: const TextStyle(color: Colors.white70, fontSize: 11, overflow: TextOverflow.ellipsis), maxLines: 1, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
