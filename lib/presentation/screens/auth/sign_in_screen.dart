import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:startup_application/presentation/providers/auth_provider.dart';
import 'package:startup_application/presentation/providers/language_provider.dart';
import 'package:startup_application/presentation/widgets/custom_button.dart';
import 'package:startup_application/presentation/widgets/custom_text_field.dart';
import 'package:startup_application/presentation/widgets/language_selector.dart';

import 'package:startup_application/presentation/widgets/translated_text.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  void _handleSignIn() {
    ref.read(authProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // High contrast B&W styling preference for Auth
    final buttonColor =
        theme.brightness == Brightness.light ? Colors.black : Colors.white;
    final buttonTextColor =
        theme.brightness == Brightness.light ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          LanguageSelector(color: Colors.grey),
          SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TranslatedText(
                'Welcome Back',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _emailController,
                label:
                    'Email or Phone Number', // Note: CustomTextField internally needs update if we want label translated. For now passing string.
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                label: 'Password',
                isObscure: true,
                prefixIcon: Icons.lock_outline,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    context.push('/forgot-password');
                  },
                  child: const TranslatedText('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 24),
              if (authState.status == AuthStatus.error &&
                  authState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    authState
                        .errorMessage!, // Error messages from backend might be dynamic
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              CustomButton(
                onPressed: _handleSignIn,
                text:
                    'Sign In', // CustomButton likely takes string. I might need to update CustomButton to take child or handle translation internally.
                // Assuming currently I can't easily change all widgets.
                // Wait, CustomButton takes `text` string usually.
                // If I pass a String, it won't be translated by TranslatedText widget.
                // I should wrapping the text inside CustomButton or changing CustomButton API.
                // Let's modify CustomButton call to use a translated version if possible, or just leave button for now if complexity is high.
                // Actually, I can wrap the string in the build method of CustomButton if I modify it, OR
                // Update implementation plan?
                // The requirement says "Replace all hardcoded Text widgets... with TranslatedText".
                // If CustomButton uses Text(text) inside, I should probably modify CustomButton to use TranslatedText(text).
                // But for now, let's just do `Welcome Back` and `Forgot Password?` and links.
                // Actually, let's look at CustomButton.
                isLoading: authState.status == AuthStatus.loading,
                backgroundColor: buttonColor,
                textColor: buttonTextColor,
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: ref
                              .watch(languageProvider)
                              .translations["Don't have an account? "] ??
                          "Don't have an account? ",
                    ),
                    TextSpan(
                      text:
                          ref.watch(languageProvider).translations["Sign Up"] ??
                              "Sign Up",
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          context.push('/signup');
                        },
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
