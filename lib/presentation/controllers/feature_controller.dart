import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:startup_application/presentation/providers/auth_provider.dart';
import 'package:startup_application/core/services/pitch_deck_service.dart';

final featureControllerProvider = Provider((ref) => FeatureController(ref));

class FeatureController {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  FeatureController(this._ref);

  double? parseFundingAmount(dynamic input) {
    if (input == null) return null;

    final raw = input.toString().toLowerCase().replaceAll(',', '').trim();

    // If it's already a pure number
    final direct = double.tryParse(raw);
    if (direct != null) return direct;

    final regex = RegExp(r'([\d.]+)\s*(crore|cr|lakh|lakhs)');
    final match = regex.firstMatch(raw);

    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);
    final unit = match.group(2);

    if (value == null) return null;

    switch (unit) {
      case 'crore':
      case 'cr':
        return value * 10000000; // 1 crore = 10 million
      case 'lakh':
      case 'lakhs':
        return value * 100000; // 1 lakh = 100k
      default:
        return null;
    }
  }

  Future<void> submitInvestorMatching(Map<String, dynamic> data) async {
    final user = _ref.read(authProvider).user;
    if (user == null) throw Exception('User not logged in');

    // Mapped to 'startup_profiles' based on schema
    // Note: Assuming 'id' is linked to auth.users.id
    // If inserts fail due to PK constraint, we might need to handle 'id': user.id differently
    // depending on if it's an insert or update. Upsert handles valid PKs.
    final numericFunding = parseFundingAmount(data['funding_amount']);

    final payload = {
      'id': user.id,
      'startup_name': data['startup_name'],
      'sector': data['sector'],
      'sub_sector': data['sub_sector'],
      'startup_stage':
          data['age_stage']?.toString().toLowerCase().replaceAll(' ', '-'),
      'location': data['location'],
      'funding_amount_sought': numericFunding,
      'funding_amount_text': data['funding_amount'], // optional but recommended
      'business_model': data['business_model'],
      'description': data['description'],
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase.from('startup_profiles').upsert(payload);
  }

  Future<void> submitFundingReadiness(Map<String, dynamic> data) async {
    final user = _ref.read(authProvider).user;
    if (user == null) throw Exception('User not logged in');

    // Mapped to 'funding_readiness' schema
    await _supabase.from('funding_readiness').upsert({
      'user_id': user.id,
      'founders_count': int.tryParse(data['founders_count'].toString()) ?? 1,
      'founder_experience': data['founder_experience'] ?? '',
      'product_stage': data['product_stage'] ?? 'Idea',
      'traction_users': int.tryParse(data['users'].toString()) ?? 0,
      'traction_revenue': double.tryParse(data['revenue'].toString()) ?? 0.0,
      'pilot_projects': data['has_pilots'] == true, // boolean
      'target_customer': data['target_customer'] ?? '',
      'market_size': data['market_size'] ?? '',
      'revenue_model': data['revenue_model'] ?? '',
      'growth_rate': data['growth_rate'] ?? 'Low',
      'key_partnerships': data['partnerships_bool'] ?? false,
      'previous_funding': data['previous_funding'] ?? '',
      // 'created_at': DateTime.now().toIso8601String(), // Let DB handle default
    });
  }

  Future<String> uploadPitchDeck({
    required File file,
    required String fileExtension,
    required String targetStage,
    required String investorType,
  }) async {
    final user = _ref.read(authProvider).user;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // 1️⃣ Validate Extension
    if (fileExtension.toLowerCase() != 'pdf') {
      throw Exception(
          'Only PDF files are supported. Please convert your ${fileExtension.toUpperCase()} to PDF.');
    }

    // 2️⃣ Extract Text
    final pitchDeckService = _ref.read(pitchDeckServiceProvider);
    final text = await pitchDeckService.extractTextFromPdf(file);

    if (text.isEmpty) {
      throw Exception(
          'Could not extract text from PDF. Is it a scanned image?');
    }

    // 2️⃣ Analyze Deck
    final analysisResult = await pitchDeckService.analyzeDeck(
      text,
      targetStage,
      investorType,
    );

    // 3️⃣ Build file path (stored in DB)
    final filePath =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    // 4️⃣ Upload to PRIVATE bucket
    await _supabase.storage.from('pitchdecks').upload(
          filePath,
          file,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        );

    // 5️⃣ Normalize values
    final normalizedStage = targetStage.toLowerCase().replaceAll(' ', '-');
    final normalizedInvestorType = investorType.toLowerCase();

    // 6️⃣ Parse Results for DB
    String streghts = '';
    String risks = '';
    String suggestions = '';

    // Simple parsing based on known headers
    // Format:
    // Pitch Deck Feedback: ...
    // Key Risks: ...
    // Suggestions: ...

    final riskIndex = analysisResult.indexOf('Key Risks:');
    final suggestIndex = analysisResult.indexOf('Suggestions:');

    if (riskIndex != -1) {
      streghts = analysisResult
          .substring(0, riskIndex)
          .replaceAll('Pitch Deck Feedback:', '')
          .trim();

      if (suggestIndex != -1 && suggestIndex > riskIndex) {
        risks = analysisResult
            .substring(riskIndex, suggestIndex)
            .replaceAll('Key Risks:', '')
            .trim();
        suggestions = analysisResult
            .substring(suggestIndex)
            .replaceAll('Suggestions:', '')
            .trim();
      } else {
        risks = analysisResult
            .substring(riskIndex)
            .replaceAll('Key Risks:', '')
            .trim();
      }
    } else {
      // Fallback
      streghts = analysisResult;
    }

    await _supabase.from('pitchdeck_analysis').insert({
      'user_id': user.id,
      'pitchdeck_url': filePath,
      'target_funding_stage': normalizedStage,
      'target_investor_type': normalizedInvestorType,
      // Mapping to schema columns
      'ai_summary':
          '', // Script doesn't generate summary, keeping empty as requested
      'ai_strengths': streghts, // Mapping "Pitch Deck Feedback" here
      'ai_risks': risks,
      'ai_suggestions': suggestions,
      'created_at': DateTime.now().toIso8601String(),
    });

    return analysisResult;
  }
}

// Provider for DI
final pitchDeckServiceProvider = Provider<PitchDeckService>((ref) {
  // We can use GetIt or just create it here if it has no dependencies
  return PitchDeckService();
});
