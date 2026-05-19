// filmsclub_flutter_app/lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/sports_hub_screen.dart';
import 'screens/news_screen.dart';
import 'screens/media_details_screen.dart';
import 'screens/video_player_screen.dart';
import 'services/api_service.dart';
import 'models/media.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..initUser()),
      ],
      child: const FilmsClubApp(),
    ),
  );
}

class FilmsClubApp extends StatelessWidget {
  const FilmsClubApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infinity Stream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff0b0a12),
        primaryColor: Colors.deepPurpleAccent,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.pinkAccent,
          surface: Color(0xff12101c),
        ),
      ),
      home: const MainCoordinatorScreen(),
    );
  }
}

class MainCoordinatorScreen extends StatefulWidget {
  const MainCoordinatorScreen({Key? key}) : super(key: key);

  @override
  _MainCoordinatorScreenState createState() => _MainCoordinatorScreenState();
}

class _MainCoordinatorScreenState extends State<MainCoordinatorScreen> {
  int _currentIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(switchTabCallback: _onTabSwitched),
      const OttBrowsingScreen(),
      const LiveTvBrowsingScreen(),
      const SportsHubScreen(),
      const NewsScreen(),
    ];
  }

  void _onTabSwitched(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSwitched,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xff12101c),
          selectedItemColor: Colors.purpleAccent,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Feed"),
            BottomNavigationBarItem(icon: Icon(Icons.movie), label: "OTT"),
            BottomNavigationBarItem(icon: Icon(Icons.tv), label: "Live TV"),
            BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: "Sports"),
            BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: "News"),
          ],
        ),
      ),
    );
  }
}

// ================= OTT SECTION SUB-SCREEN =================

class OttBrowsingScreen extends StatefulWidget {
  const OttBrowsingScreen({Key? key}) : super(key: key);

  @override
  _OttBrowsingScreenState createState() => _OttBrowsingScreenState();
}

class _OttBrowsingScreenState extends State<OttBrowsingScreen> {
  String _activeTab = "Movies"; // "Movies" or "TV Shows"
  String _selectedGenre = "All";
  List<Movie> _movies = [];
  List<TVShow> _shows = [];
  bool _loading = true;

  final List<String> _movieGenres = ["All", "Bollywood", "Hollywood", "South", "Anime", "Hindi Dubbed", "4K Movies", "Trending"];
  final List<String> _showGenres = ["All", "Netflix Series", "Amazon Series", "Hindi Series", "Korean Drama", "Anime Series"];

  @override
  void initState() {
    super.initState();
    loadMedia();
  }

  Future<void> loadMedia() async {
    setState(() {
      _loading = true;
    });

    if (_activeTab == "Movies") {
      // Query movies list
      String sortParam = "rating:desc";
      if (_selectedGenre == "Trending") sortParam = "rating:desc";
      
      final data = await ApiService.fetchMovies(sortBy: sortParam);
      
      // Filter list locally based on mock genre keyword if needed
      if (_selectedGenre != "All" && _selectedGenre != "Trending") {
        _movies = data.where((m) => m.genres.any((g) => g.toLowerCase().contains(_selectedGenre.toLowerCase()))).toList();
      } else {
        _movies = data;
      }
    } else {
      // Query TV shows list
      final data = await ApiService.fetchTVShows();
      if (_selectedGenre != "All") {
        _shows = data.where((s) => s.genres.any((g) => g.toLowerCase().contains(_selectedGenre.toLowerCase()))).toList();
      } else {
        _shows = data;
      }
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeGenres = _activeTab == "Movies" ? _movieGenres : _showGenres;
    return Scaffold(
      backgroundColor: const Color(0xff0b0a12),
      appBar: AppBar(
        title: const Text("OTT Streaming Section", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff12101c),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _activeTab = "Movies";
                      _selectedGenre = "All";
                    });
                    loadMedia();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: _activeTab == "Movies" ? Colors.purpleAccent : Colors.transparent, width: 2)),
                    ),
                    child: Text("MOVIES", style: TextStyle(color: _activeTab == "Movies" ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _activeTab = "TV Shows";
                      _selectedGenre = "All";
                    });
                    loadMedia();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: _activeTab == "TV Shows" ? Colors.purpleAccent : Colors.transparent, width: 2)),
                    ),
                    child: Text("TV & WEB SERIES", style: TextStyle(color: _activeTab == "TV Shows" ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Sub-genres horizontal scroll
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xff12101c).withOpacity(0.5),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: activeGenres.map((genre) {
                  final isSelected = _selectedGenre == genre;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedGenre = genre;
                      });
                      loadMedia();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.deepPurpleAccent : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(genre, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Main media grid list
          Expanded(
            child: _loading
                ? const Center(child: SpinKitRing(color: Colors.deepPurpleAccent, size: 50))
                : _activeTab == "Movies" 
                  ? _buildMoviesGrid() 
                  : _buildShowsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoviesGrid() {
    if (_movies.isEmpty) {
      return const Center(child: Text("No movies registered in this collection yet.", style: TextStyle(color: Colors.white38)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _movies.length,
      itemBuilder: (context, index) {
        final m = _movies[index];
        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MediaDetailsScreen(tmdbId: m.tmdbId, mediaType: "movie")));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: m.poster,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.white10),
                    errorWidget: (c, u, e) => const Icon(Icons.image),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(m.title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis), maxLines: 1),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShowsGrid() {
    if (_shows.isEmpty) {
      return const Center(child: Text("No TV Shows registered in this collection yet.", style: TextStyle(color: Colors.white38)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _shows.length,
      itemBuilder: (context, index) {
        final s = _shows[index];
        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MediaDetailsScreen(tmdbId: s.tmdbId, mediaType: "tv")));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: s.poster,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.white10),
                    errorWidget: (c, u, e) => const Icon(Icons.image),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(s.title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis), maxLines: 1),
            ],
          ),
        );
      },
    );
  }
}

// ================= LIVE TV SECTION SUB-SCREEN =================

class LiveTvBrowsingScreen extends StatefulWidget {
  const LiveTvBrowsingScreen({Key? key}) : super(key: key);

  @override
  _LiveTvBrowsingScreenState createState() => _LiveTvBrowsingScreenState();
}

class _LiveTvBrowsingScreenState extends State<LiveTvBrowsingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = ["Entertainment", "News", "Sports", "Music", "Kids"];
  Map<String, List<LiveChannel>> _channelsMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    loadChannels();
  }

  Future<void> loadChannels() async {
    setState(() {
      _loading = true;
    });

    final allChannels = await ApiService.fetchChannels();
    
    // Distribute channels by category
    Map<String, List<LiveChannel>> tempMap = {};
    for (var cat in _categories) {
      tempMap[cat] = allChannels.where((c) => c.category.toLowerCase() == cat.toLowerCase()).toList();
    }

    setState(() {
      _channelsMap = tempMap;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0b0a12),
      appBar: AppBar(
        title: const Text("Live TV Streaming", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff12101c),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _categories.map((cat) => Tab(text: cat.toUpperCase())).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: SpinKitRing(color: Colors.deepPurpleAccent, size: 50))
          : TabBarView(
              controller: _tabController,
              children: _categories.map((cat) {
                final channels = _channelsMap[cat] ?? [];
                return _buildChannelsList(channels);
              }).toList(),
            ),
    );
  }

  Widget _buildChannelsList(List<LiveChannel> channels) {
    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off_outlined, color: Colors.white24, size: 60),
            const SizedBox(height: 12),
            const Text("No active channel streams added in this category.", style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final ch = channels[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: ch.logo,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(color: Colors.white10),
                errorWidget: (c, u, e) => const CircleAvatar(child: Icon(Icons.radio)),
              ),
            ),
            title: Text(ch.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text("${ch.language} • ${ch.country} • Quality: ${ch.quality}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: CircleAvatar(
              backgroundColor: Colors.purpleAccent.withOpacity(0.1),
              child: const Icon(Icons.play_arrow, color: Colors.purpleAccent),
            ),
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
          ),
        );
      },
    );
  }
}
