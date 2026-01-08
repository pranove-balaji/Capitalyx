import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:startup_application/presentation/providers/auth_provider.dart';
import 'package:startup_application/presentation/screens/auth/sign_in_screen.dart';
import 'package:startup_application/presentation/screens/auth/sign_up_screen.dart';
import 'package:startup_application/presentation/screens/auth/forgot_password_screen.dart';
import 'package:startup_application/presentation/screens/auth/reset_password_screen.dart';
import 'package:startup_application/presentation/screens/auth/verification_pending_screen.dart';
import 'package:startup_application/presentation/screens/home/home_screen.dart';
import 'package:startup_application/presentation/screens/resources/resource_screen.dart';
import 'package:startup_application/presentation/screens/features/investor_matching_screen.dart';
import 'package:startup_application/presentation/screens/features/funding_readiness_screen.dart';
import 'package:startup_application/presentation/screens/features/pitch_deck_analyzer_screen.dart';
import 'package:startup_application/presentation/screens/chat/chat_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/signin',
    refreshListenable:
        ValueNotifier(authState), // Re-evaluate redirects on auth change
    redirect: (context, state) {
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isLoggingIn = state.uri.toString() == '/signin' ||
          state.uri.toString() == '/signup' ||
          state.uri.toString() == '/forgot-password';
      final isResettingPassword = state.uri.toString() == '/reset-password';

      // Redirect to reset password page if in recovery mode
      if (authState.status == AuthStatus.passwordRecovery &&
          !isResettingPassword) {
        return '/reset-password';
      }

      // Allow access to password reset
      if (isResettingPassword) return null;

      // If not logged in and not on valid auth page, go to signin
      if (!isLoggedIn && !isLoggingIn) return '/signin';

      if (isLoggedIn) {
        final user = authState.user;
        // Check for email verification
        final isVerified = user?.emailConfirmedAt != null;

        if (!isVerified) {
          if (state.uri.toString() != '/verification-pending') {
            return '/verification-pending';
          }
          return null;
        }

        // Redirect to home if logging in or verification pending
        if (isLoggingIn || state.uri.toString() == '/verification-pending') {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verification-pending',
        builder: (context, state) => const VerificationPendingScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/resources',
        builder: (context, state) => const ResourceScreen(),
      ),
      GoRoute(
        path: '/investor-matching',
        builder: (context, state) => const InvestorMatchingScreen(),
      ),
      GoRoute(
        path: '/funding-readiness',
        builder: (context, state) => const FundingReadinessScreen(),
      ),
      GoRoute(
        path: '/pitch-deck-analyzer',
        builder: (context, state) => const PitchDeckAnalyzerScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
      ),
    ],
  );
});
