// filmsclub_flutter_app/lib/screens/news_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/media.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({Key? key}) : super(key: key);

  @override
  _NewsScreenState createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  String _selectedCategory = "All";
  List<EditorialPost> _posts = [];
  bool _loading = true;

  final List<String> _categories = [
    "All",
    "Cricket News",
    "Match Updates",
    "OTT Releases",
    "Movie Reviews",
    "Trending Topics"
  ];

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  Future<void> loadPosts() async {
    setState(() {
      _loading = true;
    });

    final catParam = _selectedCategory == "All" ? null : _selectedCategory;
    final data = await ApiService.fetchEditorialPosts(category: catParam);

    setState(() {
      _posts = data;
      _loading = false;
    });
  }

  void _openArticleReader(EditorialPost post) {
    // Track reading article
    final appState = Provider.of<AppState>(context, listen: false);
    ApiService.trackUserAction(appState.userId, "read_article", post.id, post.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff0b0a12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final dateFormatted = DateFormat('dd MMMM yyyy').format(post.publishedOn);
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Banner Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      post.banner,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorWidget: (c, e, o) => Container(color: Colors.white05, height: 200),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Tag Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.deepPurpleAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text(post.category, style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  // Title
                  Text(post.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.3)),
                  const SizedBox(height: 12),
                  // Author & Date details
                  Row(
                    children: [
                      const CircleAvatar(radius: 12, backgroundColor: Colors.deepPurple, child: Icon(Icons.person, size: 12, color: Colors.white)),
                      const SizedBox(width: 8),
                      Text("By ${post.author}", style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(dateFormatted, style: const TextStyle(color: Colors.white30, fontSize: 13)),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  // Content details HTML parser mockup (renders rich scrollable clean text)
                  Text(
                    post.content.replaceAll("<br>", "\n").replaceAll("<p>", "").replaceAll("</p>", "\n\n"),
                    style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.7),
                  ),
                  const SizedBox(height: 30),
                  // Tags render
                  if (post.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: post.tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(6)),
                        child: Text("#$t", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      )).toList(),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0b0a12),
      appBar: AppBar(
        title: const Text("Editorial News", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff12101c),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter scroll row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: const Color(0xff12101c),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                      });
                      loadPosts();
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
                        cat,
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

          // News Directory list
          Expanded(
            child: _loading
                ? const Center(child: SpinKitRing(color: Colors.deepPurpleAccent, size: 50))
                : _posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.newspaper_outlined, color: Colors.white24, size: 80),
                            const SizedBox(height: 15),
                            const Text("No news updates published in this category.", style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadPosts,
                        color: Colors.deepPurpleAccent,
                        backgroundColor: const Color(0xff12101c),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            final dateStr = DateFormat('dd MMM, yyyy').format(post.publishedOn);

                            return InkWell(
                              onTap: () => _openArticleReader(post),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Article Banner Image
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: Image.network(
                                        post.banner,
                                        width: double.infinity,
                                        height: 160,
                                        fit: BoxFit.cover,
                                        errorWidget: (c, e, o) => Container(color: Colors.white05, height: 160),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.deepPurpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                child: Text(post.category, style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                              Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            post.title,
                                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.3),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(Icons.edit_note, color: Colors.white30, size: 18),
                                              const SizedBox(width: 4),
                                              Text("By ${post.author}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                              const Spacer(),
                                              const Text("READ ARTICLE", style: TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.deepPurpleAccent),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
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
