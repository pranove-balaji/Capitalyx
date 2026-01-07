import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:http/http.dart' as http;

class GlossaryService {
  // Provided JSON map of startup terms (Simulated)
  static final Map<String, String> _glossary = {
    'seed funding': 'seed funding',
    'bootstrap': 'bootstrap',
    'equity': 'equity',
    'angel investor': 'angel investor',
    'venture capital': 'venture capital',
    'burn rate': 'burn rate',
    'churn rate': 'churn rate',
    'startup': 'startup',
    'valuation': 'valuation',
    // Add more as needed
  };

  /// Protects glossary terms by wrapping them in <span translate="no"> tags.
  /// Case-insensitive matching.
  String protectTerms(String text) {
    String protectedText = text;

    // Sort keys by length (descending) to avoid partial matches replacing inside longer matches
    final sortedKeys = _glossary.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final term in sortedKeys) {
      final pattern =
          RegExp(r'\b' + RegExp.escape(term) + r'\b', caseSensitive: false);
      protectedText = protectedText.replaceAllMapped(pattern, (match) {
        return '<span translate="no">${match.group(0)}</span>';
      });
    }
    return protectedText;
  }

  /// Translates text using Google Translate API while preserving glossary terms.
  Future<String> translate(String text, String targetLang) async {
    if (targetLang == 'en') return text;

    final apiKey = dotenv.env['GOOGLE_TRANSLATE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print('Warning: GOOGLE_TRANSLATE_API_KEY not found.');
      return "$text [MISSING KEY]"; // Fallback with visual indicator
    }

    final protectedText = protectTerms(text);

    final url = Uri.parse(
        'https://translation.googleapis.com/language/translate/v2?key=$apiKey');

    try {
      final response = await http.post(
        url,
        body: {
          'q': protectedText,
          'target': targetLang,
          'format': 'html', // Important for span tags
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final translatedHtml =
            jsonResponse['data']['translations'][0]['translatedText'];

        // Strip the span tags for display, or keep them if styling requires.
        // For standard Text widgets, we likely want to remove the tags but keep the content.
        // RegEx to remove <span translate="no"> and </span> but keep content.
        return _stripProtectionTags(translatedHtml);
      } else {
        print('Translation Error: ${response.statusCode} - ${response.body}');
        return "$text [Err: ${response.statusCode}]";
      }
    } catch (e) {
      print('Translation Exception: $e');
      return "$text [Exc]";
    }
  }

  String _stripProtectionTags(String html) {
    // Replace <span translate="no">Content</span> with Content
    // Also handle possible encoded entities if API returns them, usually it returns standard HTML.
    // Simple regex for the specific tag we added:
    String result = html;

    // Match opening tag with any attributes, though we only use translate="no"
    final openTag =
        RegExp(r'<span[^>]*translate="no"[^>]*>', caseSensitive: false);
    final closeTag = RegExp(r'</span>', caseSensitive: false);

    result = result.replaceAll(openTag, '').replaceAll(closeTag, '');

    // Decode HTML entities if necessary (basic ones)
    result = result
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    return result;
  }
}
