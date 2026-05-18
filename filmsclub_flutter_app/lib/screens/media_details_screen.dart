// filmsclub_flutter_app/lib/screens/media_details_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/media.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import 'video_player_screen.dart';

class MediaDetailsScreen extends StatefulWidget {
  final int tmdbId;
  final String mediaType; // "movie" or "tv"

  const MediaDetailsScreen({
    Key? key,
    required this.tmdbId,
    required this.mediaType,
  }) : super(key: key);

  @override
  _MediaDetailsScreenState createState() => _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends State<MediaDetailsScreen> {
  dynamic _mediaDetails;
  List<dynamic> _similarMedia = [];
  bool _loading = true;
  int _selectedSeasonIndex = 0;

  @override
  void initState() {
    super.initState();
    loadDetails();
  }

  Future<void> loadDetails() async {
    setState(() {
      _loading = true;
    });

    final details = await ApiService.fetchMediaDetails(widget.tmdbId);
    final similar = await ApiService.fetchSimilarMedia(widget.tmdbId, widget.mediaType);

    setState(() {
      _mediaDetails = details;
      _similarMedia = similar;
      _loading = false;
    });

    if (details != null) {
      // Track details view
      final appState = Provider.of<AppState>(context, listen: false);
      ApiService.trackUserAction(appState.userId, "view_details", widget.tmdbId.toString(), details.title);
    }
  }

  void _playVideo(String qualityId, String fileName, String title, int? mediaId, String mediaType, String poster) {
    // Construct streaming URL through our telegram forwarder endpoint
    final streamUrl = "${ApiService.baseUrl}/dl/$qualityId/$fileName";
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: streamUrl,
          title: title,
          mediaId: mediaId,
          mediaType: mediaType,
          poster: poster,
        ),
      ),
    );
  }

  void _showQualitySelector(List<QualityDetail> qualities, String title, int? mediaId, String mediaType, String poster) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff12101c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Choose Streaming Resolution",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Multi-audio & subtitle profiles supported",
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: qualities.length,
                  itemBuilder: (context, index) {
                    final q = qualities[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.hd_outlined, color: Colors.deepPurpleAccent),
                        title: Text(q.quality, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(q.size, style: const TextStyle(color: Colors.white54)),
                        trailing: const Icon(Icons.play_arrow, color: Colors.white),
                        onTap: () {
                          Navigator.pop(context);
                          _playVideo(q.id, q.name, title, mediaId, mediaType, poster);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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

    if (_mediaDetails == null) {
      return Scaffold(
        backgroundColor: const Color(0xff0b0a12),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text("Metadata retrieval error. Please try again later.", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final isMovie = widget.mediaType == "movie";
    final Movie? movie = isMovie ? _mediaDetails as Movie : null;
    final TVShow? show = !isMovie ? _mediaDetails as TVShow : null;

    final title = isMovie ? movie!.title : show!.title;
    final poster = isMovie ? movie!.poster : show!.poster;
    final backdrop = isMovie ? movie!.backdrop : show!.backdrop;
    final description = isMovie ? movie!.description : show!.description;
    final rating = isMovie ? movie!.rating : show!.rating;
    final year = isMovie ? movie!.releaseYear : show!.releaseYear;
    final genres = isMovie ? movie!.genres : show!.genres;
    final rip = isMovie ? movie!.rip : show!.rip;

    return Scaffold(
      backgroundColor: const Color(0xff0b0a12),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backdrop Banner Block
            Stack(
              children: [
                ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent, Colors.transparent, Color(0xff0b0a12)],
                      stops: [0.0, 0.4, 0.7, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: CachedNetworkImage(
                    imageUrl: backdrop,
                    width: double.infinity,
                    height: 280,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.black26),
                    errorWidget: (context, url, error) => Image.network(poster, width: double.infinity, height: 280, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      // Mini Poster Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: poster,
                          width: 90,
                          height: 130,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(width: 12),
                                Text(year.toString(), style: const TextStyle(color: Colors.white54, fontSize: 14)),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.deepPurpleAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                  child: Text(rip, style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),

            // Metadata Detail Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Buttons
                  Row(
                    children: [
                      if (isMovie)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurpleAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              if (movie!.telegram.isNotEmpty) {
                                _showQualitySelector(movie.telegram, movie.title, movie.tmdbId, "movie", movie.poster);
                              }
                            },
                            icon: const Icon(Icons.play_arrow, color: Colors.white),
                            label: const Text("Stream Movie", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white.withOpacity(0.04),
                        child: IconButton(
                          icon: Icon(
                            appState.isAddedToWatchlist(widget.tmdbId) ? Icons.bookmark : Icons.bookmark_add_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            appState.toggleWatchlist(widget.tmdbId, widget.mediaType, title, poster);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Genres Scroll
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: genres.map((g) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Text(g, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Overview / Storyline
                  const Text("Storyline", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // TV Show Accordion Seasons List
                  if (!isMovie && show!.seasons.isNotEmpty) ...[
                    const Text("Episodes & Seasons", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    // Season horizontally scroll selector
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(show.seasons.length, (index) {
                          final s = show.seasons[index];
                          final isSelected = _selectedSeasonIndex == index;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedSeasonIndex = index;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.deepPurpleAccent : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "Season ${s.seasonNumber}",
                                style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Episodes list in selected season
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: show.seasons[_selectedSeasonIndex].episodes.length,
                      itemBuilder: (context, epIndex) {
                        final ep = show.seasons[_selectedSeasonIndex].episodes[epIndex];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 80,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                image: DecorationImage(
                                  image: NetworkImage(ep.episodeBackdrop.isNotEmpty ? ep.episodeBackdrop : show.backdrop),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: const Center(
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.play_arrow, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                            title: Text("EP ${ep.episodeNumber}: ${ep.title}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            subtitle: const Text("Tap resolution to stream", style: TextStyle(color: Colors.white54, fontSize: 12)),
                            onTap: () {
                              if (ep.telegram != null && ep.telegram!.isNotEmpty) {
                                _showQualitySelector(ep.telegram!, "${show.title} - S${show.seasons[_selectedSeasonIndex].seasonNumber}E${ep.episodeNumber}", show.tmdbId, "tv", show.poster);
                              }
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Recommendations list
                  if (_similarMedia.isNotEmpty) ...[
                    const Text("More Like This (Discovery)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _similarMedia.length,
                        itemBuilder: (context, index) {
                          final item = _similarMedia[index];
                          final itemTitle = widget.mediaType == 'movie' ? (item as Movie).title : (item as TVShow).title;
                          final itemPoster = widget.mediaType == 'movie' ? (item as Movie).poster : (item as TVShow).poster;
                          final itemId = widget.mediaType == 'movie' ? (item as Movie).tmdbId : (item as TVShow).tmdbId;
                          
                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MediaDetailsScreen(tmdbId: itemId, mediaType: widget.mediaType),
                                ),
                              );
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
                                      imageUrl: itemPoster,
                                      height: 140,
                                      width: 110,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    itemTitle,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, overflow: TextOverflow.ellipsis),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
