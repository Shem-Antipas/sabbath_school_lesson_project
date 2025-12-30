import 'package:flutter/material.dart';
import '../services/egw_api_service.dart'; // Ensure path is correct

class EGWReaderScreen extends StatefulWidget {
  final String chapterTitle;
  final String bookCode;

  const EGWReaderScreen({
    super.key,
    required this.chapterTitle,
    required this.bookCode,
  });

  @override
  State<EGWReaderScreen> createState() => _EGWReaderScreenState();
}

class _EGWReaderScreenState extends State<EGWReaderScreen> {
  double _fontSize = 18.0;
  late Future<String> _chapterFuture;
  final EGWApiService _apiService = EGWApiService();

  @override
  void initState() {
    super.initState();
    // Start fetching as soon as the screen opens
    String chapterNum = widget.chapterTitle.replaceAll(RegExp(r'[^0-9]'), '');
    _chapterFuture = _apiService.fetchChapterContent(
      widget.bookCode,
      chapterNum,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookCode),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () =>
                setState(() => _fontSize = (_fontSize == 18) ? 24 : 18),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _chapterFuture,
        builder: (context, snapshot) {
          // STATE 1: LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Fetching inspired words...",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // STATE 2: ERROR
          if (snapshot.hasError ||
              (snapshot.hasData && snapshot.data!.contains("Error"))) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Oops! ${snapshot.data ?? 'Something went wrong.'}",
                ),
              ),
            );
          }

          // STATE 3: SUCCESS (Show Text)
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chapterTitle,
                  style: TextStyle(
                    fontSize: _fontSize + 4,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                SelectableText(
                  snapshot.data!,
                  style: TextStyle(fontSize: _fontSize, height: 1.6),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
