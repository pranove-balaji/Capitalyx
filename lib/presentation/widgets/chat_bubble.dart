import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup_application/core/services/glossary_service.dart';
import 'package:startup_application/presentation/providers/language_provider.dart';

class ChatBubble extends ConsumerWidget {
  final Map<String, dynamic> message;
  final bool isUser;
  final Color secondaryColor;
  final bool isDark;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(languageProvider).code;
    final glossaryService = GlossaryService();
    final text = message['text'] ?? '';

    // Determine translation future
    Future<String> translationFuture;
    if (isUser) {
      // User text: Simple translation
      translationFuture = glossaryService.translate(text, currentLang);
    } else {
      // AI text: JSON translation
      translationFuture = glossaryService.translateJson(text, currentLang);
    }

    // If English, no need to wait (optimization, though FutureBuilder handles it fine)
    // Actually, if text is already in target lang (e.g. user typed it), translation API handles it (returns same).
    // But for "immediate" local echo which matches currentLang, we can just show it.
    // However, for history (English), we need translation.

    return FutureBuilder<String>(
        future: translationFuture,
        initialData: text, // Show original while loading
        builder: (context, snapshot) {
          final content = snapshot.data ?? text;

          if (isUser) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: secondaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      content,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black12,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smart_toy_outlined,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: _buildAIContent(content, context),
                    ),
                  ),
                ],
              ),
            );
          }
        });
  }

  Widget _buildAIContent(String content, BuildContext context) {
    // Try Parsing JSON
    try {
      final data = jsonDecode(content);
      if (data is Map<String, dynamic>) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['title'] != null && data['title'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  data['title'],
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            if (data['summary'] != null &&
                data['summary'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  data['summary'],
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            if (data['sections'] != null)
              ...(data['sections'] as List).map<Widget>((section) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (section['heading'] != null)
                        Text(
                          section['heading'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (section['points'] != null)
                        ...(section['points'] as List).map<Widget>((point) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                    // Use check icon if it looks like a checklist item
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: secondaryColor),
                                finalWidth(8),
                                Expanded(
                                  child: Text(
                                    point.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                );
              }).toList(),
            if (data['confidence'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Confidence: ${(data['confidence'] * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        );
      }
    } catch (_) {
      // Not JSON, return plain text
    }

    // Default Plain Text Fallback
    return Text(
      content,
      style: TextStyle(
          fontSize: 15, color: isDark ? Colors.white : Colors.black87),
    );
  }

  Widget finalWidth(double width) => SizedBox(width: width);
}
