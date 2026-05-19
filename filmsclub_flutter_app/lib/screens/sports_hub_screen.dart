// filmsclub_flutter_app/lib/screens/sports_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../models/media.dart';
import '../services/api_service.dart';
import 'video_player_screen.dart';

class SportsHubScreen extends StatefulWidget {
  const SportsHubScreen({Key? key}) : super(key: key);

  @override
  _SportsHubScreenState createState() => _SportsHubScreenState();
}

class _SportsHubScreenState extends State<SportsHubScreen> {
  String _selectedSport = "All";
  List<SportsFixture> _fixtures = [];
  bool _loading = true;

  final List<String> _sportsCategories = ["All", "Cricket", "Football", "WWE", "Kabaddi", "Tennis"];

  @override
  void initState() {
    super.initState();
    loadFixtures();
  }

  Future<void> loadFixtures() async {
    setState(() {
      _loading = true;
    });

    final sportParam = _selectedSport == "All" ? null : _selectedSport;
    final data = await ApiService.fetchSportsFixtures(sportType: sportParam);

    setState(() {
      _fixtures = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0b0a12),
      appBar: AppBar(
        title: const Text("Sports Hub", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff12101c),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sports Category horizontally scrolled selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: const Color(0xff12101c),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _sportsCategories.map((sport) {
                  final isSelected = _selectedSport == sport;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSport = sport;
                      });
                      loadFixtures();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.deepPurpleAccent : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? Colors.deepPurple : Colors.white.withOpacity(0.06)),
                      ),
                      child: Text(
                        sport,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Fixtures list
          Expanded(
            child: _loading
                ? const Center(child: SpinKitRing(color: Colors.deepPurpleAccent, size: 50))
                : _fixtures.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sports_soccer_outlined, color: Colors.white24, size: 80),
                            const SizedBox(height: 15),
                            const Text("No active matches scheduled right now.", style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadFixtures,
                        color: Colors.deepPurpleAccent,
                        backgroundColor: const Color(0xff12101c),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _fixtures.length,
                          itemBuilder: (context, index) {
                            final fix = _fixtures[index];
                            final isLive = fix.status.toLowerCase() == "live";
                            final isFinished = fix.status.toLowerCase() == "finished";
                            final timeFormatted = DateFormat('dd MMM, hh:mm a').format(fix.startTime.toLocal());

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isLive ? Colors.deepPurpleAccent.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    // Header: Category, Status Tag
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.sports_cricket, color: Colors.purpleAccent, size: 16),
                                            const SizedBox(width: 6),
                                            Text(fix.sportType, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                        if (isLive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                            child: const Row(
                                              children: [
                                                CircleAvatar(radius: 4, backgroundColor: Colors.red),
                                                SizedBox(width: 6),
                                                Text("LIVE", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          )
                                        else if (isFinished)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                            child: const Text("ENDED", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.deepPurpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                            child: Text(timeFormatted, style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),

                                    // Team matchups & Logos
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        // Team A
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Image.network(fix.teamALogo, width: 50, height: 50, errorBuilder: (c, e, o) => const CircleAvatar(child: Icon(Icons.shield))),
                                              const SizedBox(height: 8),
                                              Text(fix.teamA, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center, maxLines: 1),
                                            ],
                                          ),
                                        ),
                                        // VS Middle info
                                        Column(
                                          children: [
                                            const Text("VS", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 20)),
                                            if (isFinished) const SizedBox(height: 6),
                                            if (isFinished) const Text("FT", style: TextStyle(color: Colors.white24, fontSize: 12)),
                                          ],
                                        ),
                                        // Team B
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Image.network(fix.teamBLogo, width: 50, height: 50, errorBuilder: (c, e, o) => const CircleAvatar(child: Icon(Icons.shield))),
                                              const SizedBox(height: 8),
                                              Text(fix.teamB, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center, maxLines: 1),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),

                                    // Scorecard widget display
                                    if (fix.score != null && fix.score!.isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(8)),
                                        child: Text(
                                          fix.score!,
                                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    
                                    // Streaming triggers
                                    if (isLive && fix.streamUrl != null) ...[
                                      const SizedBox(height: 15),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.deepPurpleAccent,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => VideoPlayerScreen(
                                                  videoUrl: fix.streamUrl!,
                                                  title: fix.title,
                                                  mediaType: "live_tv",
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.live_tv, color: Colors.white),
                                          label: const Text("WATCH STREAM LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                    ],

                                    if (isFinished && fix.highlightsUrl != null) ...[
                                      const SizedBox(height: 15),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white.withOpacity(0.05),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => VideoPlayerScreen(
                                                  videoUrl: fix.highlightsUrl!,
                                                  title: "${fix.title} - Highlights",
                                                  mediaType: "movie", // Treat highlights as standalone movie progress tracking
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.play_circle_outline, color: Colors.white),
                                          label: const Text("WATCH MATCH HIGHLIGHTS", style: TextStyle(color: Colors.white70)),
                                        ),
                                      )
                                    ],

                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
