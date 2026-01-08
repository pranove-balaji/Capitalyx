import 'package:startup_application/core/services/glossary_service.dart';
import 'package:startup_application/core/services/hybrid_query_service.dart';
import 'package:startup_application/domain/repositories/query_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QueryRepositoryImpl implements QueryRepository {
  final SupabaseClient _supabaseClient;
  final GlossaryService _glossaryService;

  QueryRepositoryImpl(this._supabaseClient, this._glossaryService);

  @override
  Future<Map<String, dynamic>> saveProcessedQuery(
      String input, String currentLanguageCode) async {
    try {
      if (input.trim().isEmpty) return {};

      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Step 1: Use Hybrid RAG Service to process query
      final ragResult =
          await HybridQueryService().processQuery(input, currentLanguageCode);

      // Step 2: Supabase Insert
      await _supabaseClient.from('user_queries').insert({
        'user_id': userId,
        'original_query': ragResult['original_query'],
        'translated_query': ragResult['translated_query'],
        'language_code': currentLanguageCode,
        'ai_response': ragResult['ai_response'],
        'translated_response': ragResult['translated_response']
      });

      return ragResult;
    } catch (e) {
      print('Error saving query: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAIInteractions() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      // Fetch from user_queries now that it stores the response
      final response = await _supabaseClient
          .from('user_queries')
          .select('translated_query, ai_response, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Map keys to UI expectation (user_query, ai_response)
      return (response as List)
          .map((item) => {
                'user_query':
                    item['translated_query'] ?? '[Missing]', // Source English
                'ai_response': item['ai_response'] ?? '{}', // Source English
                'created_at': item['created_at']
              })
          .toList();
    } catch (e) {
      print('Error fetching AI interactions: $e');
      return [];
    }
  }

  @override
  Future<void> clearHistory() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return;

      await _supabaseClient.from('user_queries').delete().eq('user_id', userId);
    } catch (e) {
      print('Error clearing history: $e');
      rethrow;
    }
  }
}
