import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_test/api_exception.dart';
import 'package:riverpod_test/auth_repository.dart';
import 'package:riverpod_test/service_locator.dart'; // Import getIt

Dio createAndConfigureDio() {
  final dio = Dio();

  // 기본 옵션 설정
  dio.options = BaseOptions(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 3),
    contentType: 'application/json',
  );

  // 인터셉터 추가
  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        // AuthRepository에서 액세스 토큰을 가져옵니다.
        // getIt을 사용하여 AuthRepository 인스턴스를 가져옵니다.
        final accessToken = await getIt<AuthRepository>().accessToken;
        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        print('REQUEST[${options.method}] => PATH: ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        print('ERROR[${e.response?.statusCode}] => PATH: ${e.requestOptions.path}');
        
        // 401 에러 (토큰 만료) 처리
        if (e.response?.statusCode == 401) {
          try {
            print('Token expired. Refreshing token...');
            // 1. 토큰 재발급 요청
            // getIt을 사용하여 AuthRepository 인스턴스를 가져옵니다.
            final authRepo = getIt<AuthRepository>();
            final newAccessToken = await authRepo.refresh();
            // 2. 재발급 받은 토큰으로 원래 요청 재시도
            final options = e.requestOptions;
            options.headers['Authorization'] = 'Bearer $newAccessToken';
            
            // Dio의 다른 인스턴스를 사용하여 재요청 (인터셉터 무한 루프 방지)
            final response = await Dio(dio.options).fetch(options);
            return handler.resolve(response);

          } on DioException catch (refreshError) {
            // 토큰 재발급 실패 시, 로그인 페이지로 보내는 등의 처리를 합니다.
            print('Failed to refresh token: $refreshError');
            return handler.reject(refreshError);
          }
        }
        
        // 다른 종류의 에러들은 커스텀 예외로 변환하여 전파합니다.
        return handler.next(DioException(
          requestOptions: e.requestOptions,
          error: ApiException.fromDioError(e),
        ));
      },
    ),
  );

  // 디버그 모드에서만 LogInterceptor를 추가합니다.
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  return dio;
}
