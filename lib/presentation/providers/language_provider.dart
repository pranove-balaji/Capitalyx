import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startup_application/core/constants/app_strings.dart';
import 'package:startup_application/core/services/glossary_service.dart';

class LanguageState {
  final String code;
  final Map<String, String> translations;
  final bool isLoading;

  const LanguageState({
    required this.code,
    this.translations = const {},
    this.isLoading = false,
  });

  LanguageState copyWith({
    String? code,
    Map<String, String>? translations,
    bool? isLoading,
  }) {
    return LanguageState(
      code: code ?? this.code,
      translations: translations ?? this.translations,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageState &&
        other.code == code &&
        mapEquals(other.translations, translations) &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode =>
      code.hashCode ^ translations.hashCode ^ isLoading.hashCode;
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, LanguageState>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<LanguageState> {
  LanguageNotifier() : super(const LanguageState(code: 'en')) {
    _init();
  }

  final GlossaryService _glossaryService = GlossaryService();

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('selected_language') ?? 'en';

    if (savedCode != 'en') {
      final savedMapString = prefs.getString('translations_$savedCode');
      Map<String, String> loadedMap = {};
      if (savedMapString != null) {
        try {
          loadedMap = Map<String, String>.from(jsonDecode(savedMapString));
        } catch (e) {
          debugPrint('Error loading translations: $e');
        }
      }

      state = LanguageState(code: savedCode, translations: loadedMap);

      if (loadedMap.isEmpty) {
        _translateAll(savedCode);
      }
    } else {
      state = const LanguageState(code: 'en');
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (state.code == languageCode) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', languageCode);

    if (languageCode == 'en') {
      state = const LanguageState(code: 'en');
      return;
    }

    // Check if we have cached translations in storage
    final savedMapString = prefs.getString('translations_$languageCode');
    if (savedMapString != null) {
      try {
        final loadedMap = Map<String, String>.from(jsonDecode(savedMapString));
        // Check for invalid cached inputs (from previous missing key errors)
        final bool hasErrors = loadedMap.values.any((v) =>
            v.contains('[MISSING KEY]') ||
            v.contains('[Err]') ||
            v.contains('[Exc]'));

        if (hasErrors) {
          debugPrint(
              'Found corrupted cache for $languageCode, refreshing translations...');
          await prefs.remove('translations_$languageCode');
          state = LanguageState(code: languageCode, isLoading: true);
          await _translateAll(languageCode);
        } else {
          state = LanguageState(code: languageCode, translations: loadedMap);
        }
      } catch (e) {
        state = LanguageState(code: languageCode, isLoading: true);
        await _translateAll(languageCode);
      }
    } else {
      state = LanguageState(code: languageCode, isLoading: true);
      await _translateAll(languageCode);
    }
  }

  Future<void> _translateAll(String langCode) async {
    // If already loading, maybe debounce? But for now it's fine.
    state = state.copyWith(isLoading: true);

    // We translate all known strings
    final results =
        await _glossaryService.translateBatch(AppStrings.all, langCode);

    state = state.copyWith(
      isLoading: false,
      translations: results,
    );

    // Save
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translations_$langCode', jsonEncode(results));
  }
}
