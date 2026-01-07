import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:startup_application/core/theme/app_theme.dart';
import 'package:startup_application/core/utils/app_constants.dart';
import 'package:startup_application/injection_container.dart' as di;
import 'package:startup_application/presentation/providers/theme_provider.dart';
import 'package:startup_application/presentation/router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env");

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  await di.init();

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Startup App',
      theme: AppTheme.getTheme(
        isDark: themeState.isDark,
        secondaryColor: themeState.secondaryColor,
      ),
      routerConfig: router,
    );
  }
}
