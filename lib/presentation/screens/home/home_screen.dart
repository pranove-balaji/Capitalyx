import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  bool _isInputMode = false;
  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _inputFocusNode.removeListener(_onFocusChange);
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isInputMode = _inputFocusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    // Dynamic color based on sector
    final Color secondaryColor =
        AppTheme.getSecondaryColorForSector(profile?.startupSector ?? '');

    // Theme data
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
          onPressed: () {
            // Keeping the original drawer on left if needed or just replace?
            // User requested "Clicking the top-right 'Three Dots' must open a sidebar"
            // So we use endDrawer for the sidebar the user requested.
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(
          profile?.startupName ?? 'New Chat',
          style: TextStyle(
              color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Three dots button for the Sidebar requested
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
        // Detect endDrawer state
        setState(() {
          _isDrawerOpen = isOpened;
        });
      },
      drawerScrimColor: Colors.transparent, // Disable default scrim to use ours
      drawer: _buildSidebar(context, ref,
          secondaryColor), // Keep existing left drawer if desired or remove? I'll keep it as "Menu"
      endDrawer: _buildRightSidebar(
          context, ref, secondaryColor), // New requested sidebar
      body: GlowBackground(
        secondColor: secondaryColor,
        isDark: isDark,
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                    height:
                        kToolbarHeight + MediaQuery.of(context).padding.top),

                // Central Content (Logo + Text)
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isInputMode ? 0.0 : 1.0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                secondaryColor,
                                secondaryColor.withValues(alpha: 0.5)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: secondaryColor.withValues(alpha: 0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.star_outline_rounded,
                              color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 24),
                        TranslatedText(
                          "Hello, ${authState.user?.userMetadata?['full_name'] ?? profile?.startupName ?? 'User'}",
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TranslatedText(
                          "How can I assist you right now?",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Feature Widgets (Single Row) - Hide when input focused
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isInputMode ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: _isInputMode,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _FeatureCard(
                              title: 'Funding\nReadiness',
                              icon: Icons.monetization_on_outlined,
                              color: secondaryColor,
                              isDark: isDark,
                              onTap: () => context.push('/funding-readiness'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeatureCard(
                              title: 'Pitch Deck\nAnalyzer',
                              icon: Icons.analytics_outlined,
                              color: secondaryColor,
                              isDark: isDark,
                              onTap: () => context.push('/pitch-deck-analyzer'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeatureCard(
                              title: 'Investor\nMatching',
                              icon: Icons.people_outline,
                              color: secondaryColor,
                              isDark: isDark,
                              onTap: () => context.push('/investor-matching'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Input Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
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
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                focusNode: _inputFocusNode,
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface),
                                onSubmitted: (value) async {
                                  if (value.trim().isNotEmpty) {
                                    final currentLang =
                                        ref.read(languageProvider);
                                    await di
                                        .sl<QueryRepository>()
                                        .saveProcessedQuery(
                                            value.trim(), currentLang);
                                    _textController.clear();
                                    _inputFocusNode.unfocus();
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'Ask anything here...',
                                  hintStyle: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5)),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: secondaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_upward,
                                    color: Colors.white),
                                onPressed: () async {
                                  final value = _textController.text;
                                  if (value.trim().isNotEmpty) {
                                    final currentLang =
                                        ref.read(languageProvider);
                                    await di
                                        .sl<QueryRepository>()
                                        .saveProcessedQuery(
                                            value.trim(), currentLang);
                                    _textController.clear();
                                    _inputFocusNode.unfocus();
                                  }
                                },
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

            // Blur Overlay (Backdrop for both Drawers)
            if (_isDrawerOpen)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Right Sidebar (End Drawer)
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
            // Switch Theme
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
            // Language Settings (Using the selector logic or just link)
            ListTile(
              leading: Icon(Icons.language, color: theme.colorScheme.onSurface),
              title: TranslatedText('Language Settings',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              trailing: const LanguageSelector(
                  color: Colors.grey), // Embed selector directly or open dialog
              onTap: () {
                // The LanguageSelector widget handles the click itself mostly, but if we want a full page:
                // context.push('/settings/language');
                // For now, putting the selector as trailing
              },
            ),
            // Logout
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const TranslatedText('Logout',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                // Close drawer before sign out to avoid errors
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

  // Keeping original left sidebar but updating it slightly if necessary or just leaving as 'Menu'
  // Since the user asked for sidebar on "Three Dots" (Right), I moved the requested items there.
  // This one can be "Navigation"
  Widget _buildSidebar(
      BuildContext context, WidgetRef ref, Color secondaryColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  Icon(Icons.menu, color: theme.colorScheme.onSurface),
                  const SizedBox(width: 12),
                  TranslatedText(
                    'Menu',
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
            ListTile(
              leading: Icon(Icons.history, color: theme.colorScheme.onSurface),
              title: TranslatedText('History',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {},
            ),
            // ... other items
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 130, // Taller for glass look
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment:
                      CrossAxisAlignment.start, // Align left like Apple cards
                  children: [
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle),
                        child: Icon(icon,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 24)),
                    TranslatedText(
                      title,
                      style: GoogleFonts.inter(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
