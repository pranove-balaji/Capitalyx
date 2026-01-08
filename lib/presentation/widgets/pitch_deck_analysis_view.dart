import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:startup_application/core/services/glossary_service.dart';
import 'package:startup_application/presentation/providers/language_provider.dart';
import 'package:startup_application/presentation/widgets/translated_text.dart';

class PitchDeckAnalysisView extends ConsumerStatefulWidget {
  final String analysisResult;

  const PitchDeckAnalysisView({super.key, required this.analysisResult});

  @override
  ConsumerState<PitchDeckAnalysisView> createState() =>
      _PitchDeckAnalysisViewState();
}

class _PitchDeckAnalysisViewState extends ConsumerState<PitchDeckAnalysisView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, String>> _feedbackItems = [];
  List<String> _risks = [];
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _parseAnalysis();
  }

  @override
  void didUpdateWidget(PitchDeckAnalysisView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analysisResult != widget.analysisResult) {
      _parseAnalysis();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _parseAnalysis() {
    final text = widget.analysisResult;
    _feedbackItems.clear();
    _risks.clear();
    _suggestions.clear();

    // 1. Extract Sections
    final riskIndex = text.indexOf('Key Risks:');
    final suggestIndex = text.indexOf('Suggestions:');

    String feedbackSection = '';
    String riskSection = '';
    String suggestSection = '';

    if (riskIndex != -1) {
      feedbackSection = text
          .substring(0, riskIndex)
          .replaceAll('Pitch Deck Feedback:', '')
          .trim();

      if (suggestIndex != -1 && suggestIndex > riskIndex) {
        riskSection = text
            .substring(riskIndex, suggestIndex)
            .replaceAll('Key Risks:', '')
            .trim();
        suggestSection =
            text.substring(suggestIndex).replaceAll('Suggestions:', '').trim();
      } else {
        riskSection =
            text.substring(riskIndex).replaceAll('Key Risks:', '').trim();
      }
    } else {
      feedbackSection = text;
    }

    // 2. Parse Feedback Items
    final lines = feedbackSection.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      String type = 'info';
      if (line.contains('✔'))
        type = 'success';
      else if (line.contains('⚠'))
        type = 'warning';
      else if (line.contains('❌')) type = 'error';

      String content = line
          .replaceAll('✔', '')
          .replaceAll('⚠', '')
          .replaceAll('❌', '')
          .trim();

      String title = content;
      String body = '';

      if (content.contains(':')) {
        final parts = content.split(':');
        title = parts[0].trim();
        body = parts.sublist(1).join(':').trim();
      }

      if (title.isNotEmpty) {
        _feedbackItems.add({
          'type': type,
          'title': title,
          'body': body,
        });
      }
    }

    // 3. Parse Risks (Bullets)
    _risks = riskSection
        .split('\n')
        .where((l) => l.trim().startsWith('-'))
        .map((l) => l.replaceAll('-', '').trim())
        .toList();

    // 4. Parse Suggestions (Bullets)
    _suggestions = suggestSection
        .split('\n')
        .where((l) => l.trim().startsWith('-'))
        .map((l) => l.replaceAll('-', '').trim())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF6C63FF),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(child: TranslatedText('Overview')),
              Tab(child: TranslatedText('Risks')),
              Tab(child: TranslatedText('Actions')),
            ],
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildRisksTab(),
                _buildSuggestionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final languageCode = ref.watch(languageProvider).code;
    final glossaryService = GlossaryService();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _feedbackItems.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _feedbackItems[index];
        final type = item['type'];

        Color color;
        IconData icon;
        switch (type) {
          case 'success':
            color = Colors.greenAccent;
            icon = Icons.check_circle_outline;
            break;
          case 'warning':
            color = Colors.orangeAccent;
            icon = Icons.warning_amber_rounded;
            break;
          case 'error':
            color = Colors.redAccent;
            icon = Icons.error_outline;
            break;
          default:
            color = Colors.blueAccent;
            icon = Icons.info_outline;
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: glossaryService.translate(
                          item['title']!, languageCode),
                      builder: (context, snapshot) => Text(
                        snapshot.data ?? item['title']!,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                    if (item['body']!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      FutureBuilder<String>(
                        future: glossaryService.translate(
                            item['body']!, languageCode),
                        builder: (context, snapshot) => Text(
                          snapshot.data ?? item['body']!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRisksTab() {
    if (_risks.isEmpty) {
      return Center(
          child: TranslatedText("No significant risks detected.",
              style: TextStyle(color: Colors.grey)));
    }
    final languageCode = ref.watch(languageProvider).code;
    final glossaryService = GlossaryService();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _risks.length,
      itemBuilder: (context, index) {
        return Card(
          color: Colors.red.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.withOpacity(0.3))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<String>(
                    future:
                        glossaryService.translate(_risks[index], languageCode),
                    builder: (context, snapshot) => Text(
                      snapshot.data ?? _risks[index],
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionsTab() {
    if (_suggestions.isEmpty) {
      return Center(
          child: TranslatedText("No specific suggestions provided.",
              style: TextStyle(color: Colors.grey)));
    }
    final languageCode = ref.watch(languageProvider).code;
    final glossaryService = GlossaryService();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        return Card(
          color: const Color(0xFF6C63FF).withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side:
                  BorderSide(color: const Color(0xFF6C63FF).withOpacity(0.3))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb, color: Color(0xFF6C63FF), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<String>(
                    future: glossaryService.translate(
                        _suggestions[index], languageCode),
                    builder: (context, snapshot) => Text(
                      snapshot.data ?? _suggestions[index],
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
