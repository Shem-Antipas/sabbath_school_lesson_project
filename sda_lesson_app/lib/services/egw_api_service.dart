import 'dart:convert';
import 'package:http/http.dart' as http;

class EGWApiService {
  // Replace these once you get the email from the White Estate
  static const String _clientId = String.fromEnvironment(
    'EGW_CLIENT_ID',
    defaultValue: '',
  );
  static const String _clientSecret = String.fromEnvironment(
    'EGW_CLIENT_SECRET',
    defaultValue: '',
  );
  static const String _baseUrl = "https://org-api.egwwritings.org/api/v1";

  // Set this to true to use real API, false to use Mock data
  bool get _isConfigured => _clientId.isNotEmpty && _clientSecret.isNotEmpty;

  /// Main method to fetch chapter text
  Future<String> fetchChapterContent(String bookCode, String chapterNum) async {
    if (!_isConfigured) {
      return _getMockContent(bookCode, chapterNum);
    }

    try {
      // 1. Get OAuth Token (Logic simplified for this example)
      final token = await _getAccessToken();

      // 2. Fetch Content
      final response = await http.get(
        Uri.parse('$_baseUrl/content/book/$bookCode/chapter/$chapterNum'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // The API usually returns HTML or Plain Text in a 'content' field
        return data['content'] ?? "No content found for this chapter.";
      } else {
        return "Error ${response.statusCode}: Failed to load from EGW servers.";
      }
    } catch (e) {
      return "Connection Error: Please check your internet or try again later.";
    }
  }

  /// Handles OAuth2 Token Generation
  Future<String> _getAccessToken() async {
    // In a real production app, you would cache this token so you
    // don't request a new one every single time a user opens a page.
    final response = await http.post(
      Uri.parse('https://org-api.egwwritings.org/oauth/token'),
      body: {
        'grant_type': 'client_credentials',
        'client_id': _clientId,
        'client_secret': _clientSecret,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body)['access_token'];
    }
    throw Exception("Failed to authenticate with EGW API");
  }

  /// MOCK DATA - Used while waiting for API keys
  Future<String> _getMockContent(String bookCode, String chapterNum) async {
    await Future.delayed(
      const Duration(milliseconds: 800),
    ); // Simulate network lag

    final Map<String, String> mockLibrary = {
      "SC":
          "Nature and revelation alike testify of God's love. Our Father in heaven is the source of life, of wisdom, and of joy. Look at the wonderful and beautiful things of nature...",
      "DA":
          "‘His name shall be called Immanuel... God with us.’ The light of the knowledge of the glory of God is seen in the face of Jesus Christ...",
      "GC":
          "Before the entrance of sin, Adam enjoyed open communion with his Maker; but since man separated himself from God by transgression, the human race has been cut off from this high privilege.",
    };

    return mockLibrary[bookCode] ??
        "This is the preview text for $bookCode, Chapter $chapterNum. \n\n[Waiting for API Credentials to load full text...]";
  }
}
