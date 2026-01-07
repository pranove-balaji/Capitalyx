import 'package:startup_application/core/services/glossary_service.dart';
import 'package:startup_application/domain/repositories/query_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QueryRepositoryImpl implements QueryRepository {
  final SupabaseClient _supabaseClient;
  final GlossaryService _glossaryService;

  QueryRepositoryImpl(this._supabaseClient, this._glossaryService);

  @override
  Future<void> saveProcessedQuery(
      String input, String currentLanguageCode) async {
    try {
      if (input.trim().isEmpty) return;

      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      String effectiveQuery = input;

      // Step B: Conditional Translation
      if (currentLanguageCode != 'en') {
        // GlossaryService.translate handles protection internally
        effectiveQuery = await _glossaryService.translate(input, 'en');
        // If translation fails/returns error codes, we might still want to save,
        // but typically we'd save the result.
      }

      // Step C: Supabase Insert
      // Assuming table 'user_queries' has 'user_id', 'query_text', 'original_text', 'language_code'
      // Adjusting based on common patterns or user prompt simplicity
      // Prompt says: "Perform the insert into user_queries. The user_id should be automatically pulled..."
      await _supabaseClient.from('user_queries').insert({
        'user_id': userId,
        'original_query': input, // native language
        'translated_query': effectiveQuery, // English for AI
        'language_code': currentLanguageCode,
        // created_at can be omitted (DB default)
      });
    } catch (e) {
      // Cleanly rethrow or log
      print('Error saving query: $e');
      rethrow;
    }
  }
}
