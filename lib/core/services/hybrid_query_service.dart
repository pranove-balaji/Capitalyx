import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:startup_application/core/services/glossary_service.dart';

class HybridQueryService {
  final GlossaryService _glossaryService;

  // Singleton pattern
  static final HybridQueryService _instance =
      HybridQueryService._internal(GlossaryService());
  factory HybridQueryService() => _instance;
  HybridQueryService._internal(this._glossaryService);

  // --- Configuration ---
  String get _pineconeKey => dotenv.env['PINECONE_API_KEY'] ?? "";

  // Vertex AI Config
  static const _projectId = 'capitalyx';
  static const _region = 'us-central1';
  static const _serviceAccountFile = 'assets/capitalyx-6c6ccbc46033.json';

  // --- State ---
  String? _pineconeHost; // Cached host URL
  AutoRefreshingAuthClient? _authClient; // Cached Authenticated Client

  // --- Public API ---
  Future<Map<String, dynamic>> processQuery(
      String userQuery, String languageCode) async {
    try {
      // 0. Ensure Auth
      await _authenticate();

      // 1. Translation (Input)
      String englishQuery = userQuery;
      if (languageCode != 'en') {
        englishQuery = await _glossaryService.translate(userQuery, 'en');
      }

      // 2. Intent Classification
      final intentData = _classifyIntent(englishQuery);
      final intent = intentData['intent'] as String;
      final entities = intentData['entities'] as Map<String, List<String>>;

      // 3. Retrieval
      List<Map<String, dynamic>> graphData = [];
      String vectorContext = "";
      List<Map<String, dynamic>> vectorSources = [];
      double vectorConfidence = 0.0;

      final questionType = _classifyQuestionType(englishQuery);

      if (questionType == 'amount') {
        graphData = await _fetchFundingGraph(entities);
      } else if (['eligibility', 'listing'].contains(questionType)) {
        graphData = await _fetchGeneralGraph(englishQuery, entities);
      } else {
        // Vector default
        final vectorResult = await _fetchVectorContext(englishQuery);
        vectorContext = vectorResult['context'];
        vectorSources = vectorResult['sources'];
        vectorConfidence = vectorResult['confidence'];
      }

      // If primary method yielded low results, try secondary
      if (graphData.isEmpty && vectorContext.isEmpty) {
        final vectorResult = await _fetchVectorContext(englishQuery);
        vectorContext = vectorResult['context'];
      }

      // 4. Generation
      final answerData = await _generateAnswer(
        query: englishQuery,
        vectorContext: vectorContext,
        graphData: graphData,
        vectorConfidence: vectorConfidence,
      );

      String finalAnswer = answerData['answer'].toString();

      // 5. Translation (Output)
      String translatedResponse = finalAnswer;
      if (languageCode != 'en') {
        try {
          // Check if valid JSON
          final jsonData = jsonDecode(finalAnswer);
          if (jsonData is Map<String, dynamic>) {
            translatedResponse = await _translateJson(jsonData, languageCode);
          } else {
            translatedResponse =
                await _glossaryService.translate(finalAnswer, languageCode);
          }
        } catch (_) {
          translatedResponse =
              await _glossaryService.translate(finalAnswer, languageCode);
        }
      }

      return {
        'original_query': userQuery,
        'translated_query': englishQuery,
        'ai_response': finalAnswer,
        'translated_response': translatedResponse,
        'metadata': {
          'intent': intent,
          'entities': entities,
          'sources': vectorSources
        }
      };
    } catch (e) {
      print("HybridRAG Error: $e");
      return {
        'error': e.toString(),
        'ai_response': "I encountered an error processing your request.",
        'translated_response': "I encountered an error processing your request."
      };
    }
  }

  Future<void> _authenticate() async {
    if (_authClient != null) return;
    try {
      final jsonString = await rootBundle.loadString(_serviceAccountFile);
      final credentials = ServiceAccountCredentials.fromJson(jsonString);
      _authClient = await clientViaServiceAccount(
          credentials, ['https://www.googleapis.com/auth/cloud-platform']);
    } catch (e) {
      print("Authentication Failed: $e");
      throw Exception("Failed to authenticate with Service Account: $e");
    }
  }

  // --- 1. Intent Classification ---
  Map<String, dynamic> _classifyIntent(String query) {
    final lower = query.toLowerCase();

    final entities = {
      'stage': <String>[],
      'sector': <String>[],
      'location': <String>[]
    };

    ['pre-seed', 'seed', 'series a', 'growth'].forEach((s) {
      if (lower.contains(s)) entities['stage']!.add(s);
    });

    ['fintech', 'healthtech', 'edtech', 'agritech', 'saas'].forEach((s) {
      if (lower.contains(s))
        entities['sector']!.add(s.replaceFirst(s[0], s[0].toUpperCase()));
    });

    ['bangalore', 'delhi', 'mumbai'].forEach((s) {
      if (lower.contains(s))
        entities['location']!.add(s.replaceFirst(s[0], s[0].toUpperCase()));
    });

    String intent = 'simple_info';
    if (lower.contains('list') ||
        lower.contains('find') ||
        lower.contains('which')) intent = 'graph_query';

    return {'intent': intent, 'entities': entities};
  }

  String _classifyQuestionType(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('how much') ||
        lower.contains('amount') ||
        lower.contains('funding')) return 'amount';
    if (lower.contains('qualify') || lower.contains('eligible'))
      return 'eligibility';
    if (lower.contains('list') || lower.contains('show')) return 'listing';
    return 'unknown';
  }

  // --- 2. Neo4j Integration ---
  Future<List<Map<String, dynamic>>> _fetchGeneralGraph(
      String query, Map<String, List<String>> entities) async {
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchFundingGraph(
      Map<String, List<String>> entities) async {
    return [];
  }

  // --- 3. Pinecone Integration ---
  Future<Map<String, dynamic>> _fetchVectorContext(String query) async {
    if (_pineconeKey.isEmpty)
      return {'context': '', 'sources': [], 'confidence': 0.0};

    try {
      if (_pineconeHost == null) {
        await _resolvePineconeHost();
      }

      if (_pineconeHost == null)
        return {'context': '', 'sources': [], 'confidence': 0.0};

      final vector = await _getVertexEmbedding(query);
      if (vector.isEmpty)
        return {'context': '', 'sources': [], 'confidence': 0.0};

      final url = Uri.parse('https://$_pineconeHost/query');
      final response = await http.post(
        url,
        headers: {
          'Api-Key': _pineconeKey,
          'Content-Type': 'application/json',
        },
        body:
            jsonEncode({'vector': vector, 'topK': 5, 'includeMetadata': true}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final matches = data['matches'] as List;

        StringBuffer context = StringBuffer();
        List<Map<String, dynamic>> sources = [];
        double totalScore = 0;

        for (var m in matches) {
          if (m['score'] > 0.45) {
            context.writeln(m['metadata']['text'] ?? '');
            sources.add({
              'text': m['metadata']['text'],
              'score': m['score'],
              'source': m['metadata']['source'] ?? 'Unknown'
            });
            totalScore += m['score'];
          }
        }

        return {
          'context': context.toString(),
          'sources': sources,
          'confidence': matches.isNotEmpty ? totalScore / matches.length : 0.0
        };
      }
    } catch (e) {
      print("Pinecone Error: $e");
    }
    return {'context': '', 'sources': [], 'confidence': 0.0};
  }

  Future<List<double>> _getVertexEmbedding(String text) async {
    try {
      final endpoint =
          'https://$_region-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_region/publishers/google/models/text-embedding-004:predict';

      final response = await _authClient!.post(Uri.parse(endpoint),
          body: jsonEncode({
            "instances": [
              {"content": text}
            ]
          }));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final values = data['predictions'][0]['embeddings']['values'] as List;
        return values.cast<double>();
      } else {
        print("Vertex Embedding Error: ${response.body}");
      }
    } catch (e) {
      print("Vertex Embedding Exception: $e");
    }
    return [];
  }

  Future<void> _resolvePineconeHost() async {
    try {
      final url = Uri.parse('https://api.pinecone.io/indexes');
      final response = await http.get(url, headers: {'Api-Key': _pineconeKey});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('indexes')) {
          final list = data['indexes'] as List;
          final target = list.firstWhere(
              (i) => i['name'] == dotenv.env['INDEX_NAME'],
              orElse: () => null);
          if (target != null) {
            _pineconeHost = target['host'];
          }
        }
      }
    } catch (e) {
      print("Failed to resolve Pinecone host: $e");
    }
  }

  // --- 4. Generation ---
  Future<Map<String, dynamic>> _generateAnswer({
    required String query,
    required String vectorContext,
    required List<Map<String, dynamic>> graphData,
    required double vectorConfidence,
  }) async {
    // Model ID Fallback List
    const models = [
      'gemini-2.5-pro', // Priority 1 (User Requested)
      'gemini-1.5-pro-001', // Priority 2
      'gemini-1.5-pro', // Priority 3
      'gemini-1.5-flash-001', // Priority 4
      'gemini-1.0-pro-001' // Priority 5
    ];

    final prompt = '''
You are a factual AI assistant.
Rules:
- Use ONLY the provided facts
- Do NOT guess
- Output STRICT JSON only

JSON FORMAT:
{
  "title": "",
  "summary": "",
  "sections": [
    {
      "heading": "",
      "points": []
    }
  ],
  "confidence": 0.0
}

CONTEXT:
$vectorContext

GRAPH FACTS:
$graphData

QUESTION:
$query
''';

    for (final model in models) {
      final endpoint =
          'https://$_region-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_region/publishers/google/models/$model:generateContent';

      try {
        print("Trying Generation with model: $model...");
        final response = await _authClient!.post(Uri.parse(endpoint),
            body: jsonEncode({
              "contents": [
                {
                  "role": "user",
                  "parts": [
                    {"text": prompt}
                  ]
                }
              ],
              "generationConfig": {
                "temperature": 0.1,
                "maxOutputTokens": 2048,
                "responseMimeType": "application/json"
              }
            }));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final text = candidates[0]['content']['parts'][0]['text'];
            print("✅ Success with $model");
            return {'answer': text ?? '{}', 'confidence': vectorConfidence};
          }
        }

        print("⚠️ Failed with $model: ${response.statusCode}");
      } catch (e) {
        print("⚠️ Exception with $model: $e");
      }
    }

    return {
      'answer': '{"error": "All models (including gemini-2.5-pro) failed."}',
      'confidence': 0.0
    };
  }

  Future<String> _translateJson(
      Map<String, dynamic> json, String targetLang) async {
    final newJson = Map<String, dynamic>.from(json);

    // Translate Title
    if (newJson['title'] != null) {
      newJson['title'] =
          await _glossaryService.translate(newJson['title'], targetLang);
    }
    // Translate Summary
    if (newJson['summary'] != null) {
      newJson['summary'] =
          await _glossaryService.translate(newJson['summary'], targetLang);
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
                await _glossaryService.translate(secMap['heading'], targetLang);
          }
          if (secMap['points'] != null && secMap['points'] is List) {
            final pts = secMap['points'] as List;
            final newPts = [];
            for (var p in pts) {
              newPts.add(
                  await _glossaryService.translate(p.toString(), targetLang));
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
  }
}
