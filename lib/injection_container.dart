import 'package:get_it/get_it.dart';

import 'package:startup_application/data/datasources/auth_remote_data_source.dart';
import 'package:startup_application/data/datasources/profile_remote_data_source.dart';
import 'package:startup_application/data/repositories/auth_repository_impl.dart';
import 'package:startup_application/data/repositories/profile_repository_impl.dart';
import 'package:startup_application/domain/repositories/auth_repository.dart';
import 'package:startup_application/domain/repositories/profile_repository.dart';
import 'package:startup_application/domain/repositories/query_repository.dart';
import 'package:startup_application/data/repositories/query_repository_impl.dart';
import 'package:startup_application/core/services/glossary_service.dart';
import 'package:startup_application/core/services/pitch_deck_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ! External
  // Supabase is initialized in main.dart, but we register the client here accessing the instance
  // Or we can just register the client if it's already initialized.
  // Ideally, main calls Supabase.initialize(), then init().
  sl.registerLazySingleton(() => Supabase.instance.client);

  // ! Services
  sl.registerLazySingleton(() => GlossaryService());
  sl.registerLazySingleton(() => PitchDeckService());

  // ! Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl()),
  );

  // ! Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<QueryRepository>(
    () => QueryRepositoryImpl(sl(), sl()),
  );
}
