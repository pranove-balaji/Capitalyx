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

  /// Translates a list of strings using Google Translate API while preserving glossary terms.
  Future<Map<String, String>> translateBatch(
      List<String> texts, String targetLang) async {
    if (targetLang == 'en') {
      return {for (var t in texts) t: t};
    }

    String? apiKey = dotenv.env['GOOGLE_CLOUD_API_KEY'];
    apiKey ??= dotenv.env['google_cloud_api_key'];

    if (apiKey == null || apiKey.isEmpty) {
      print('Warning: GOOGLE_CLOUD_API_KEY not found in .env');
      return {for (var t in texts) t: "$t [MISSING KEY]"};
    }

    // Protect terms in all texts
    final protectedTexts = texts.map((t) => protectTerms(t)).toList();

    final url = Uri.parse(
        'https://translation.googleapis.com/language/translate/v2?key=$apiKey');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'q': protectedTexts,
          'target': targetLang,
          'format': 'html',
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final translations = jsonResponse['data']['translations'] as List;

        final Map<String, String> resultMap = {};
        for (int i = 0; i < texts.length; i++) {
          final translatedHtml = translations[i]['translatedText'];
          resultMap[texts[i]] = _stripProtectionTags(translatedHtml);
        }
        return resultMap;
      } else {
        print(
            'Batch Translation Error: ${response.statusCode} - ${response.body}');
        return {for (var t in texts) t: "$t [Err]"};
      }
    } catch (e) {
      print('Batch Translation Exception: $e');
      return {for (var t in texts) t: "$t [Exc]"};
    }
  }

  /// Translates text using Google Translate API while preserving glossary terms.
  Future<String> translate(String text, String targetLang) async {
    final map = await translateBatch([text], targetLang);
    return map[text] ?? text;
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
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'");

    return result;
  }

  Future<String> translateJson(String jsonString, String targetLang) async {
    try {
      if (targetLang == 'en') return jsonString;

      final jsonMap = json.decode(jsonString);
      if (jsonMap is! Map<String, dynamic>)
        return await translate(jsonString, targetLang);

      final newJson = Map<String, dynamic>.from(jsonMap);

      // Translate Title
      if (newJson['title'] != null) {
        newJson['title'] = await translate(newJson['title'], targetLang);
      }
      // Translate Summary
      if (newJson['summary'] != null) {
        newJson['summary'] = await translate(newJson['summary'], targetLang);
      }
      // Translate Sections
      if (newJson['sections'] != null && newJson['sections'] is List) {
        final sections = newJson['sections'] as List;
        final newSections = [];
        for (var s in sections) {
          if (s is Map) {
            final secMap = Map<String, dynamic>.from(s);
            if (secMap['heading'] != null) {
              secMap['heading'] =
                  await translate(secMap['heading'], targetLang);
            }
            if (secMap['points'] != null && secMap['points'] is List) {
              final pts = secMap['points'] as List;
              final newPts = [];
              for (var p in pts) {
                newPts.add(await translate(p.toString(), targetLang));
              }
              secMap['points'] = newPts;
            }
            newSections.add(secMap);
          } else {
            newSections.add(s);
          }
        }
        newJson['sections'] = newSections;
      }
      return jsonEncode(newJson);
    } catch (e) {
      // Fallback
      return await translate(jsonString, targetLang);
    }
  }
}
