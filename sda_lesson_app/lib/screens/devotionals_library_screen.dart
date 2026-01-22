import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/devotional_provider.dart';

// -----------------------------------------------------------------------------
// SCREEN 1: LIBRARY (Grid of Books with Covers)
// -----------------------------------------------------------------------------
class DevotionalsLibraryScreen extends StatelessWidget {
  const DevotionalsLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFBFBFD);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Devotionals Library", 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 books per row
          childAspectRatio: 0.7, // Taller aspect ratio for book covers
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        // ✅ Uses the list from your provider
        itemCount: availableDevotionals.length,
        itemBuilder: (context, index) {
          final book = availableDevotionals[index];
          return _buildBookCard(context, book);
        },
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, DevotionalBookInfo book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MonthSelectionScreen(book: book)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2), 
              blurRadius: 6, 
              offset: const Offset(0, 4)
            ),
          ],
        ),
        // ClipRRect ensures the image respects the rounded corners
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. The Cover Image
              Image.asset(
                book.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image is missing - Show a colored placeholder
                  return Container(
                    color: const Color(0xFF5D4037), 
                    child: const Center(
                      child: Icon(Icons.menu_book, size: 40, color: Colors.white),
                    ),
                  );
                },
              ),
              // Optional: You could add a gradient here if text readability is an issue
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SCREEN 2: MONTH SELECTION
// -----------------------------------------------------------------------------
class MonthSelectionScreen extends StatelessWidget {
  final DevotionalBookInfo book;
  
  final List<String> months = const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  const MonthSelectionScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(book.title, style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: months.length,
        separatorBuilder: (c, i) => const Divider(),
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(months[index], style: TextStyle(fontSize: 18, color: textColor)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DevotionalReaderScreen(
                    bookId: book.id,
                    bookTitle: book.title,
                    monthIndex: index + 1, // 1 for Jan
                    monthName: months[index],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SCREEN 3: READER (PageView with Real Data)
// -----------------------------------------------------------------------------
class DevotionalReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookTitle;
  final int monthIndex;
  final String monthName;

  const DevotionalReaderScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.monthIndex,
    required this.monthName,
  });

  @override
  ConsumerState<DevotionalReaderScreen> createState() => _DevotionalReaderScreenState();
}

class _DevotionalReaderScreenState extends ConsumerState<DevotionalReaderScreen> {
  late PageController _pageController;
  int _currentDay = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(devotionalContentProvider(widget.bookId));
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("${widget.monthName} $_currentDay", style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: textColor))),
        data: (allReadings) {
          // --- DEBUGGING LOGIC START ---
          if (allReadings.isEmpty) {
             return Center(child: Text("JSON File loaded but is empty.", style: TextStyle(color: textColor)));
          }

          // Filter for the selected month
          final monthReadings = allReadings.where((r) => r.month == widget.monthIndex).toList();
          
          // If filtering fails, show DIAGNOSTIC INFO
          if (monthReadings.isEmpty) {
            final firstReading = allReadings.first;
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 50),
                    SizedBox(height: 10),
                    Text(
                      "No readings found for ${widget.monthName} (Index ${widget.monthIndex})",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "DIAGNOSTIC:",
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Total Readings in File: ${allReadings.length}\n"
                      "Sample Month from File: ${firstReading.month} (Type: ${firstReading.month.runtimeType})\n"
                      "Looking for Month: ${widget.monthIndex}",
                      style: TextStyle(color: textColor, fontFamily: 'Courier'),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
            );
          }
          // --- DEBUGGING LOGIC END ---

          // Sort and Display
          monthReadings.sort((a, b) => a.day.compareTo(b.day));

          return PageView.builder(
            controller: _pageController,
            itemCount: monthReadings.length,
            onPageChanged: (index) {
              setState(() {
                _currentDay = monthReadings[index].day;
              });
            },
            itemBuilder: (context, index) {
              final reading = monthReadings[index];
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    Text(
                      reading.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.tealAccent : const Color(0xFF7D2D3B),
                        fontFamily: 'Serif',
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    if (reading.verse.isNotEmpty) 
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(left: BorderSide(color: Colors.teal, width: 4)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              reading.verse,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "- ${reading.verseRef}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 25),
                    
                    Text(
                      reading.content,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.8,
                        fontFamily: 'Serif',
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}