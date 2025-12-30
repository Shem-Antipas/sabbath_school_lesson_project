import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart'
    as html_parser; // REQUIRED: flutter pub add html

class BibleApiService {
  // 1. CREDENTIALS
  // Using the key and endpoint from your dashboard screenshot
  static const String _apiKey = "qRHgoKRLaEQbk1UQRt6oj";
  static const String _baseUrl = "https://rest.api.bible";

  // Using ASV (Public Domain) to ensure no 403 Forbidden errors
  static const String _bibleId = "06125adad2d5898a-01";

  Map<String, String> get _headers => {
    'api-key': _apiKey,
    'Accept': 'application/json',
  };

  // --- 2. FETCH ALL BOOKS ---
  Future<List<Map<String, dynamic>>> fetchBooks() async {
    final url = '$_baseUrl/v1/bibles/$_bibleId/books';

    try {
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        print("❌ API Error: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to load Bible books');
      }
    } catch (e) {
      print("❌ Connection Error: $e");
      rethrow;
    }
  }

  // --- 3. FETCH CHAPTERS ---
  Future<List<Map<String, dynamic>>> fetchChapters(String bookId) async {
    final url = '$_baseUrl/v1/bibles/$_bibleId/books/$bookId/chapters';

    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['data']);
    } else {
      throw Exception('Failed to load chapters');
    }
  }

  // --- 4. FETCH CONTENT (THE FIX FOR EMPTY TEXT) ---
  Future<List<Map<String, String>>> fetchChapterVerses(String chapterId) async {
    // Request HTML content from the API
    final url =
        '$_baseUrl/v1/bibles/$_bibleId/chapters/$chapterId?content-type=html';

    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      String rawHtml = data['data']['content'];

      // PARSING LOGIC:
      // The API returns: <span data-number="1">1</span> THE TEXT IS HERE
      // We must grab the text node that follows the span.
      var document = html_parser.parse(rawHtml);
      List<Map<String, String>> verses = [];

      var verseSpans = document.querySelectorAll('span[data-number]');

      for (var span in verseSpans) {
        String number = span.attributes['data-number'] ?? "0";
        String text = "";

        // PARENT NODE NAVIGATION
        // 1. Get the parent (usually a <p> or <div class="p">)
        var parent = span.parentNode;

        if (parent != null) {
          // 2. Find where this span is inside the parent
          int index = parent.nodes.indexOf(span);

          // 3. Look at the immediate next node
          if (index + 1 < parent.nodes.length) {
            var nextNode = parent.nodes[index + 1];

            // If the next node is just text, use it
            if (nextNode.nodeType == 3) {
              // 3 = Text Node
              text = nextNode.text ?? "";
            }
            // If the next node is another element (like a highlight), grab its text
            else {
              text = nextNode.text ?? "";
            }
          }
        }

        // Clean up text
        text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

        // Only add if we successfully found text
        if (text.isNotEmpty) {
          verses.add({"number": number, "text": text});
        }
      }
      return verses;
    } else {
      throw Exception('Failed to load content');
    }
  }

  // --- 5. SEARCH FUNCTION ---
  Future<List<Map<String, dynamic>>> searchBible(
    String query, {
    String? bookId,
  }) async {
    // Basic search endpoint
    String url = '$_baseUrl/v1/bibles/$_bibleId/search?query=$query&limit=20';

    // If a specific book is requested (and isn't 'ALL'), filter by it
    if (bookId != null && bookId != 'ALL') {
      // API.Bible uses the 'range' parameter for specific books
      url += "&range=$bookId";
    }

    print("🔎 Searching: $url");

    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Safety check: ensure 'verses' exists
      if (data['data'] != null && data['data']['verses'] != null) {
        return List<Map<String, dynamic>>.from(data['data']['verses']);
      }
      return [];
    } else {
      print("❌ Search Failed: ${response.body}");
      throw Exception('Search failed');
    }
  }
}
