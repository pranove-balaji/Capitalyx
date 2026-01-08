import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:startup_application/presentation/providers/auth_provider.dart';

import 'package:startup_application/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup_application/presentation/widgets/glow_background.dart';
// import 'package:startup_application/presentation/widgets/translated_text.dart';
import 'package:startup_application/presentation/widgets/language_selector.dart';
import 'package:startup_application/core/services/glossary_service.dart';
import 'package:startup_application/presentation/providers/language_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    final secondaryColor =
        AppTheme.getSecondaryColorForSector(profile?.startupSector ?? '');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            profile?.startupName ?? 'Capitalyx',
            style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: theme.colorScheme.onSurface),
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
          LanguageSelector(color: theme.colorScheme.onSurface),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/chat');
        },
        backgroundColor: secondaryColor,
        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        label: const Text(
          "Ask AI",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: GlowBackground(
        secondColor: secondaryColor,
        isDark: isDark,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Greeting
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: GlossaryService()
                          .translate('Hello', ref.watch(languageProvider).code),
                      builder: (context, snapshot) {
                        return Text(
                          "${snapshot.data ?? 'Hello'},",
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        );
                      },
                    ),
                    Text(
                      authState.user?.userMetadata?['full_name'] ?? 'User',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: GlossaryService().translate(
                          'Explore your startup tools.',
                          ref.watch(languageProvider).code),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Explore your startup tools.',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Feature Cards
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 1,
                    childAspectRatio: 2.2, // Rectangular cards
                    mainAxisSpacing: 16,
                    children: [
                      _FeatureButton(
                        title: 'Funding Readiness',
                        icon: Icons.monetization_on_outlined,
                        color: secondaryColor,
                        isDark: isDark,
                        onTap: () => context.push('/funding-readiness'),
                        description: "Check if you're ready for investors.",
                      ),
                      _FeatureButton(
                        title: 'Pitch Deck Analyzer',
                        icon: Icons.analytics_outlined,
                        color: secondaryColor,
                        isDark: isDark,
                        onTap: () => context.push('/pitch-deck-analyzer'),
                        description: "Get AI feedback on your deck.",
                      ),
                      _FeatureButton(
                        title: 'Investor Matching',
                        icon: Icons.people_outline,
                        color: secondaryColor,
                        isDark: isDark,
                        onTap: () => context.push('/investor-matching'),
                        description: "Find the right VCs for you.",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _FeatureButton({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(isDark ? 0.1 : 0.4),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FutureBuilder<String>(
                            future: GlossaryService().translate(
                                title,
                                ProviderScope.containerOf(context)
                                    .read(languageProvider)
                                    .code),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? title,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          FutureBuilder<String>(
                              future: GlossaryService().translate(
                                  description,
                                  ProviderScope.containerOf(context)
                                      .read(languageProvider)
                                      .code),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? description,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                );
                              }),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 16,
                        color: isDark ? Colors.white30 : Colors.black26),
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
