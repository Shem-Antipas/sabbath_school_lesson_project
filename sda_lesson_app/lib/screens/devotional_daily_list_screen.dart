import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/devotional_provider.dart';
import 'devotional_reader_screen.dart';
import '../utils/local_devotional_search.dart'; 

class DevotionalDailyListScreen extends ConsumerWidget {
  final String bookId;
  final String bookTitle;
  final String coverImagePath; // ✅ Required variable
  final int monthIndex;
  final String monthName;

  const DevotionalDailyListScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.coverImagePath, // ✅ Required in constructor
    required this.monthIndex,
    required this.monthName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(devotionalContentProvider(bookId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("$monthName - $bookTitle"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: bgColor,
        foregroundColor: textColor,
        actions: [
          asyncData.when(
            data: (allReadings) => IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: LocalDevotionalSearchDelegate(
                    allReadings: allReadings,
                    bookId: bookId,
                    bookTitle: bookTitle,
                    coverImagePath: coverImagePath, // ✅ NOW VALID (See Step 2 below)
                  ),
                );
              },
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (allReadings) {
          // 1. Filter for the selected month
          final monthReadings = allReadings
              .where((r) => r.month == monthIndex)
              .toList();

          // 2. Sort strictly by Day
          monthReadings.sort((a, b) => a.day.compareTo(b.day));

          if (monthReadings.isEmpty) {
            return Center(
              child: Text(
                "No readings found for $monthName",
                style: TextStyle(color: textColor),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: monthReadings.length,
            separatorBuilder: (c, i) => const Divider(),
            itemBuilder: (context, index) {
              final reading = monthReadings[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor: isDark
                      ? Colors.tealAccent.withOpacity(0.2)
                      : Colors.teal.withOpacity(0.1),
                  foregroundColor: isDark ? Colors.tealAccent : Colors.teal,
                  radius: 20,
                  child: Text(
                    "${reading.day}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  reading.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  reading.verse.isNotEmpty ? reading.verse : "Daily Reading",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey : Colors.black54,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DevotionalReaderScreen(
                        bookId: bookId,
                        bookTitle: bookTitle,
                        coverImagePath: coverImagePath, // ✅ Passed correctly
                        monthIndex: monthIndex,
                        monthName: monthName,
                        initialDay: reading.day,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}