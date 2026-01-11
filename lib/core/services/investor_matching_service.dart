import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class InvestorMatchingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Fetch User Startup Profile
  Future<Map<String, dynamic>?> fetchUserStartupProfile(String userId) async {
    try {
      final response = await _supabase
          .from('startup_profile')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching startup profile: $e');
      return null;
    }
  }

  // 2. Load and Filter CSV Dataset
  Future<List<List<dynamic>>> loadAndFilterCSV(
      String sector, String ageStage) async {
    try {
      final rawData =
          await rootBundle.loadString('assets/perfect_startup_funding.csv');
      List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(rawData);

      final header =
          csvTable.first.map((e) => e.toString().toLowerCase()).toList();
      final sectorIdx = header.indexOf(
          'vertical'); // or 'industry' - checking CSV structure needed usually, assuming 'vertical' based on typical datasets or 'Industry'
      final stageIdx =
          header.indexOf('investment stage'); // Update based on actual CSV

      // Fallback if columns not found, just return top rows
      if (sectorIdx == -1 || stageIdx == -1) {
        print("Warning: CSV headers not found. Returning first 25 rows.");
        return csvTable.take(25).toList();
      }

      final filtered = csvTable.where((row) {
        if (row == csvTable.first) return false; // Skip header in filter
        final rowSector = row[sectorIdx].toString().toLowerCase();
        final rowStage = row[stageIdx].toString().toLowerCase();

        // Simple case-insensitive containment check
        final sectorMatch = rowSector.contains(sector.toLowerCase());
        final stageMatch = rowStage.contains(ageStage.toLowerCase());

        return sectorMatch && stageMatch;
      }).toList();

      print(
          "InvestorMatchingService: Found ${filtered.length} matches in CSV.");
      return filtered.take(25).toList(); // Limit to 25 for prompt context
    } catch (e) {
      print('Error loading/filtering CSV: $e');
      throw Exception('Failed to load investor data: $e'); // Propagate error
    }
  }

  // 3. Generate Investor Matches using OpenRouter (GPT-4o-mini)
  Future<String?> generateInvestorMatches(Map<String, dynamic> startupProfile,
      List<List<dynamic>> fundingData) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      print('Error: OPENROUTER_API_KEY not found');
      throw Exception('OpenRouter API Key is missing in .env');
    }

    if (fundingData.isEmpty) {
      print("Warning: No matching funding data found to send to AI.");
      // Optional: We could still ask AI generic questions, but better to warn.
    }

    final prompt = _constructPrompt(startupProfile, fundingData);

    try {
      print("InvestorMatchingService: Sending request to OpenRouter...");
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://startup-application.com', // Optional
          'X-Title': 'Startup App', // Optional
        },
        body: jsonEncode({
          'model': 'openai/gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      );

      print("OpenRouter Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        print('OpenRouter API Error: ${response.body}');
        throw Exception(
            'AI Service Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error calling AI service: $e');
      throw e; // Propagate original exception
    }
  }

  // Helper: Construct Prompt
  String _constructPrompt(
      Map<String, dynamic> profile, List<List<dynamic>> rows) {
    // Format rows into a string
    final dataString = rows.map((row) => row.join(', ')).join('\n');

    return '''
Act as an expert startup-investor matching system.

MY STARTUP PROFILE:
- Name: ${profile['startup_name']}
- Sector: ${profile['sector']}
- Sub-sector: ${profile['sub_sector']}
- Stage: ${profile['age_stage']}
- Location: ${profile['location']}
- Funding Goal: ${profile['funding_amount']}
- Description: ${profile['description']}

PAST FUNDING DATA (Filtered):
$dataString

TASK:
Analyze the past funding data to find investors who have invested in similar startups (same sector, stage, or close match).
Identify the TOP 3 most relevant investors for me.

STRICT OUTPUT FORMAT (JSON ONLY):
[
  {
    "investor_name": "Name",
    "match_percentage": "95%",
    "reason": "Why they are a good match..."
  },
  ...
]
Do not include any markdown formatting or extra text. Just the JSON array.
''';
  }

  // 4. Save Matches to Supabase
  Future<void> saveInvestorMatches(String userId, List<dynamic> matches) async {
    try {
      final List<Map<String, dynamic>> records = matches.map((match) {
        return {
          'user_id': userId,
          'investor_name': match['investor_name'] ?? 'Unknown',
          'match_percentage': match['match_percentage'] ?? '0%',
          'reason': match['reason'] ?? 'No reason provided',
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await _supabase.from('investor_matches').insert(records);
    } catch (e) {
      print('Error saving matches: $e');
      throw Exception('Failed to save matches: $e');
    }
  }

  // 5. Fetch Investor Matches History
  Future<List<Map<String, dynamic>>> fetchInvestorMatches(String userId) async {
    try {
      final response = await _supabase
          .from('investor_matches')
          .select('investor_name, match_percentage, reason, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching matches history: $e');
      return [];
    }
  }
}
