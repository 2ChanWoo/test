
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dio 인스턴스를 제공하는 Provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();

  // 기본 URL 설정
  dio.options.baseUrl = 'https://jsonplaceholder.typicode.com';

  // 필요하다면 여기에 인터셉터 등을 추가할 수 있습니다.
  // 예: dio.interceptors.add(LogInterceptor(responseBody: true));

  return dio;
});
