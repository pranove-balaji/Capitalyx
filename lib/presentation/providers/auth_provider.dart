import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:startup_application/domain/entities/user_profile.dart';
import 'package:startup_application/domain/repositories/auth_repository.dart';
import 'package:startup_application/domain/repositories/profile_repository.dart';
import 'package:startup_application/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:startup_application/presentation/providers/theme_provider.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
  error,
  passwordRecovery
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final UserProfile? profile;
  final String? errorMessage;

  AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.profile,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    UserProfile? profile,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final Ref _ref;

  AuthNotifier(this._authRepository, this._profileRepository, this._ref)
      : super(AuthState()) {
    _init();
  }

  void _init() {
    _authRepository.authStateChanges.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn) {
        final user = event.session?.user;
        if (user != null) {
          await _loadProfile(user.id);
        }
      } else if (event.event == AuthChangeEvent.signedOut) {
        state = AuthState(status: AuthStatus.unauthenticated);
        _ref.read(themeProvider.notifier).resetColor();
      } else if (event.event == AuthChangeEvent.passwordRecovery) {
        state = state.copyWith(status: AuthStatus.passwordRecovery);
      }
    });

    // Initial check
    final user = _authRepository.currentUser;
    if (user != null) {
      _loadProfile(user.id);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _loadProfile(String userId) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final profile = await _profileRepository.getProfile(userId);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: _authRepository.currentUser,
        profile: profile, // may be null
      );

      if (profile != null) {
        _ref.read(themeProvider.notifier).updateSector(profile.startupSector);
      }
    } catch (e) {
      // Catch ANY error to prevent infinite loading and fallback to authenticated without profile
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: _authRepository.currentUser,
        profile: null,
      );
    }
  }

  Future<void> signUp(String name, String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.signUp(
          name: name, email: email, password: password);
      // Explicitly exit loading state.
      // If verification is needed, the user should be guided by the UI (e.g., checking email).
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.signIn(email: email, password: password);
      // Listener handles state update typically, but we should ensure we don't hang if it's delayed.
      // We will check currentUser manually if state is still loading after a short delay,
      // or we can just rely on the listener but ensure _loadProfile doesn't hang.
      // For now, let's allow the listener to do its job, but if the user IS logged in, we trigger load.
      final user = _authRepository.currentUser;
      if (user != null) {
        await _loadProfile(user.id);
      } else {
        // If we awaited signIn but have no user, something is wrong or session hasn't established.
        // Usually signIn throws if it fails.
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
  }

  Future<void> createProfile({
    required String startupName,
    required String startupSector,
    required String founderDetails,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) return;

    state = state.copyWith(status: AuthStatus.loading);
    try {
      final newProfile = UserProfile(
        id: user.id,
        email: user.email ?? '',
        startupName: startupName,
        startupSector: startupSector,
        founderDetails: founderDetails,
        isOnboarded: true,
      );

      await _profileRepository.createProfile(newProfile);

      // Update local state and theme
      state = state.copyWith(
        profile: newProfile,
        status: AuthStatus.authenticated,
      );
      _ref.read(themeProvider.notifier).updateSector(startupSector);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> resendVerificationEmail(String email) async {
    try {
      await _authRepository.resendVerificationEmail(email);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    try {
      // Using the host defined for deep linking
      const redirectTo = 'com.example.startup_application://reset-callback/';
      await _authRepository.resetPasswordForEmail(email, redirectTo);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> updateUserPassword(String newPassword) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.updateUserPassword(newPassword);
      state = state.copyWith(
          status: AuthStatus.authenticated); // Back to authenticated
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    sl<AuthRepository>(),
    sl<ProfileRepository>(),
    ref,
  );
});
