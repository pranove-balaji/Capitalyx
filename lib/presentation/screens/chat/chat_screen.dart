import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:startup_application/presentation/providers/auth_provider.dart';
import 'package:startup_application/presentation/providers/theme_provider.dart';
import 'package:startup_application/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup_application/presentation/widgets/glow_background.dart';
import 'package:startup_application/presentation/widgets/language_selector.dart';
import 'package:startup_application/presentation/widgets/translated_text.dart';
import 'package:startup_application/injection_container.dart' as di;
import 'package:startup_application/domain/repositories/query_repository.dart';
import 'package:startup_application/presentation/providers/language_provider.dart';
import 'package:startup_application/core/services/glossary_service.dart';
import 'package:startup_application/core/services/voice_service.dart';
import 'package:startup_application/presentation/widgets/chat_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  final GlossaryService _glossaryService = GlossaryService();

  // Voice Service
  final VoiceService _voiceService = VoiceService();
  bool _isRecording = false;
  bool _isProcessing = false;

  // Chat History
  List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onFocusChange);
    // Check permissions early
    _voiceService.hasPermission();

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await di.sl<QueryRepository>().fetchAIInteractions();
    if (mounted) {
      setState(() {
        _messages = history.reversed.expand((item) {
          // Flatten: [User Query, AI Response]
          return [
            {'text': item['user_query'], 'isUser': true},
            {'text': item['ai_response'], 'isUser': false}
          ];
        }).toList();
        _messages = _messages.reversed.toList();
      });
      // Scroll to bottom after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _inputFocusNode.removeListener(_onFocusChange);
    _inputFocusNode.dispose();
    _textController.dispose();
    _voiceService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
  }

  Future<void> _handleVoiceInteraction() async {
    if (_isRecording) {
      // STOP RECORDING
      setState(() => _isRecording = false);
      final path = await _voiceService.stopRecording();

      if (path != null) {
        await _processQuery(path, isVoice: true);
      }
    } else {
      // START RECORDING
      if (await _voiceService.hasPermission()) {
        await _voiceService.startRecording();
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _processQuery(String input, {bool isVoice = false}) async {
    final currentLangState = ref.read(languageProvider);
    final currentLang = currentLangState.code;

    String queryText = input;

    if (isVoice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Processing voice command...')),
      );
      final transcript = await _voiceService.transcribe(input, currentLang);
      if (transcript == null || transcript.isEmpty) {
        _playLocalizedFeedback(
            "Sorry, I couldn't hear that. Please try again.", currentLang);
        return;
      }
      queryText = transcript;
    }

    if (queryText.trim().isEmpty) return;

    // 1. Update UI immediately (User Message)
    setState(() {
      _messages.add({'text': queryText, 'isUser': true});
      _isProcessing = true;
    });
    _scrollToBottom();
    _textController.clear();
    _inputFocusNode.unfocus();

    try {
      final result = await di
          .sl<QueryRepository>()
          .saveProcessedQuery(queryText, currentLang);

      // 3. Update UI (AI Response)
      if (result.isNotEmpty) {
        setState(() {
          _messages.add({'text': result['ai_response'], 'isUser': false});
        });
        _scrollToBottom();
      }

      if (isVoice) {
        // _playLocalizedFeedback(result['translated_response'], currentLang); // Optional TTS
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        _messages.add({'text': "Error processing request.", 'isUser': false});
      });
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Helper to translate and speak feedback
  void _playLocalizedFeedback(String message, String langCode) async {
    try {
      final translated = await _glossaryService.translate(message, langCode);
      _voiceService.speak(translated, langCode);
    } catch (e) {
      print("TTS Feedback Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    final secondaryColor =
        AppTheme.getSecondaryColorForSector(profile?.startupSector ?? '');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF1E1E1E).withOpacity(0.8)
            : Colors.white.withOpacity(0.8),
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: theme.colorScheme.onSurface),
        title: Text(
          'Capitalyx AI',
          style: TextStyle(
              color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600),
        ),
        actions: [
          LanguageSelector(color: theme.colorScheme.onSurface),
          IconButton(
            icon: Icon(Icons.more_vert_rounded,
                color: theme.colorScheme.onSurface),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      onEndDrawerChanged: (isOpened) {
        setState(() {});
      },
      drawerScrimColor: Colors.transparent,
      endDrawer: _buildRightSidebar(context, ref, secondaryColor),
      body: GlowBackground(
        secondColor: secondaryColor,
        isDark: isDark,
        child: Column(
          children: [
            SizedBox(
                height: kToolbarHeight + MediaQuery.of(context).padding.top),

            // Chat List
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 48, color: secondaryColor.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          TranslatedText("Start a conversation!",
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return ChatBubble(
                          message: msg,
                          isUser: msg['isUser'],
                          secondaryColor: secondaryColor,
                          isDark: isDark,
                        );
                      },
                    ),
            ),

            if (_isProcessing) const LinearProgressIndicator(minHeight: 2),

            // Input Area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        )),
                    child: Row(
                      children: [
                        // Mic Button
                        IconButton(
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic_none,
                              color: _isRecording
                                  ? Colors.red
                                  : theme.colorScheme.onSurface),
                          onPressed: _handleVoiceInteraction,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _inputFocusNode,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface),
                            onSubmitted: (value) => _processQuery(value),
                            decoration: InputDecoration(
                              hintText: _isRecording
                                  ? 'Listening...'
                                  : 'Ask anything...',
                              hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5)),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 14),
                            ),
                          ),
                        ),
                        // Send Button
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_upward,
                                    color: Colors.white),
                            onPressed: _isProcessing
                                ? null
                                : () => _processQuery(_textController.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSidebar(
      BuildContext context, WidgetRef ref, Color secondaryColor) {
    final themeState = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final isDark = themeState.isDark;

    return Drawer(
      backgroundColor: isDark
          ? const Color(0xFF1E1E1E).withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.9),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Icon(Icons.settings, color: theme.colorScheme.onSurface),
                  const SizedBox(width: 12),
                  TranslatedText(
                    'Options',
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey),
            SwitchListTile(
              title: TranslatedText('Dark Mode',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              value: isDark,
              activeColor: secondaryColor,
              onChanged: (bool value) {
                ref.read(themeProvider.notifier).toggleTheme();
              },
              secondary: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: theme.colorScheme.onSurface,
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const TranslatedText('Clear Conversation',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                await di.sl<QueryRepository>().clearHistory();
                setState(() {
                  _messages.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conversation cleared')),
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const TranslatedText('Logout',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).signOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
