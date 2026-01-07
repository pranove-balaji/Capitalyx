import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:startup_application/core/services/glossary_service.dart';
import 'package:startup_application/presentation/providers/language_provider.dart';

// Simple cache to avoid repeated API calls for the same session
final Map<String, Map<String, String>> _translationCache = {};

class TranslatedText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  ConsumerState<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends ConsumerState<TranslatedText> {
  final GlossaryService _glossaryService =
      GlossaryService(); // Could be injected

  @override
  void didUpdateWidget(TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cache invalidation logic if needed, but for now we just rely on the future rebuilding
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(languageProvider);

    if (currentLang == 'en') {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    return FutureBuilder<String>(
      future: _translate(widget.text, currentLang),
      builder: (context, snapshot) {
        final displayText = snapshot.data ?? widget.text;

        // While loading, we show the original text (or a shimmer/placeholder if preferred)
        // Using original text avoids layout shift usually better.

        return Text(
          displayText,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );
      },
    );
  }

  Future<String> _translate(String text, String lang) async {
    if (_translationCache.containsKey(lang) &&
        _translationCache[lang]!.containsKey(text)) {
      return _translationCache[lang]![text]!;
    }

    final result = await _glossaryService.translate(text, lang);

    if (!_translationCache.containsKey(lang)) {
      _translationCache[lang] = {};
    }
    _translationCache[lang]![text] = result;

    return result;
  }
}
