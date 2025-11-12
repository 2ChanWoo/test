import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_test/auth_repository.dart';
import 'package:riverpod_test/post_repository.dart';
import 'package:riverpod_test/dio_provider.dart'; // Import the new dio_provider

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerLazySingleton<Dio>(() => createAndConfigureDio());
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository());
  getIt.registerLazySingleton<PostRepository>(() => PostRepository(getIt<Dio>()));
}
