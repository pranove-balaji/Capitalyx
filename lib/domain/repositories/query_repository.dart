abstract class QueryRepository {
  /// Processes the input query: checks language, translates if needed (preserving glossary terms),
  /// and saves to Supabase 'user_queries' table.
  Future<void> saveProcessedQuery(String input, String currentLanguageCode);
}
