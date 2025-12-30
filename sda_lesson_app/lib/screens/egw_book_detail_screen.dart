import 'package:flutter/material.dart';
import 'egw_reader_screen.dart';

class EGWBookDetailScreen extends StatelessWidget {
  final Map<String, dynamic> book;

  const EGWBookDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    // Simulating chapters for now
    final List<String> chapters = List.generate(
      25,
      (index) => "Chapter ${index + 1}: The Divine Purpose",
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // A floating/pinned app bar that reacts to scrolling
          SliverAppBar(
            expandedHeight: 200.0,
            pinned: true,
            backgroundColor: book['color'],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                book['title'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                color: book['color'],
                child: Center(
                  child: Text(
                    book['code'],
                    style: TextStyle(
                      fontSize: 80,
                      color: Colors.white.withOpacity(0.3),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The list of chapters
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: book['color'].withOpacity(0.1),
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(color: book['color'], fontSize: 12),
                  ),
                ),
                title: Text(chapters[index]),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EGWReaderScreen(
                        chapterTitle:
                            chapters[index], // e.g., "Chapter 1: The Divine Purpose"
                        bookCode: book['code'], // e.g., "SC"
                      ),
                    ),
                  );
                },
              );
            }, childCount: chapters.length),
          ),
        ],
      ),
    );
  }
}
