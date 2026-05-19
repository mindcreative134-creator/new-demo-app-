// filmsclub_flutter_app/lib/screens/video_player_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int? mediaId;
  final String mediaType; // "movie", "tv", "live_tv"
  final String? poster;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.title,
    this.mediaId,
    required this.mediaType,
    this.poster,
  }) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;
  String _errorMessage = "";
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    
    // Auto landcape rotation on entering player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Hide status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    initializePlayer();
    
    // Track play analytics event
    final appState = Provider.of<AppState>(context, listen: false);
    ApiService.trackUserAction(appState.userId, "play_${widget.mediaType}", widget.mediaId?.toString() ?? "live", widget.title);
  }

  Future<void> initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowFullScreen: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: SpinKitRing(color: Colors.deepPurpleAccent, size: 50),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                  const SizedBox(height: 15),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      setState(() {});

      // Setup sync continue watching timers for movies/tv episodes (every 10 seconds)
      if (widget.mediaType != "live_tv" && widget.mediaId != null) {
        _progressTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          syncPlaybackProgress();
        });
      }
    } catch (e) {
      print("Player init error: $e");
      setState(() {
        _hasError = true;
        _errorMessage = "Playback failed. Stream URL may be invalid or offline. Code: $e";
      });
    }
  }

  void syncPlaybackProgress() {
    if (_chewieController != null && _videoPlayerController.value.isInitialized) {
      final appState = Provider.of<AppState>(context, listen: false);
      final currentPos = _videoPlayerController.value.position.inSeconds.toDouble();
      final totalDuration = _videoPlayerController.value.duration.inSeconds.toDouble();
      
      if (currentPos > 5 && totalDuration > 0) {
        appState.saveContinueProgress(
          widget.mediaId!,
          widget.mediaType,
          widget.title,
          widget.poster ?? "",
          currentPos,
          totalDuration,
        );
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    
    // Sync final position before leaving
    if (widget.mediaType != "live_tv" && widget.mediaId != null) {
      syncPlaybackProgress();
    }

    _videoPlayerController.dispose();
    _chewieController?.dispose();
    
    // Reset status bar & orientation back to vertical standard
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 60),
                      const SizedBox(height: 15),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 25),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                          });
                          initializePlayer();
                        },
                        child: const Text("Retry Playback"),
                      ),
                    ],
                  ),
                )
              : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                  ? SafeArea(
                      child: Chewie(
                        controller: _chewieController!,
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SpinKitRing(color: Colors.deepPurpleAccent, size: 60),
                          SizedBox(height: 15),
                          Text(
                            "Establishing secure connection to streaming node...",
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          )
                        ],
                      ),
                    ),
          // Custom Back Button overlay
          Positioned(
            top: 20,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
