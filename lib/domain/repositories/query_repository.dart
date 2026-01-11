abstract class QueryRepository {
  /// Processes the input query: checks language, translates if needed (preserving glossary terms),
  /// and saves to Supabase 'user_queries' table.
  Future<Map<String, dynamic>> saveProcessedQuery(
      String input, String currentLanguageCode);

  /// Fetches AI interaction history for the current user.
  Future<List<Map<String, dynamic>>> fetchAIInteractions();

  /// Clears the interaction history for the current user.
  Future<void> clearHistory();
}
