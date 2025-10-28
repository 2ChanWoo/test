import 'package:dio/dio.dart';

// Dio 에러를 앱에서 사용하기 편한 형태로 변환하는 클래스
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  factory ApiException.fromDioError(DioError dioError) {
    switch (dioError.type) {
      case DioErrorType.cancel:
        return ApiException("Request to API server was cancelled");
      case DioErrorType.connectionTimeout:
        return ApiException("Connection timeout with API server");
      case DioErrorType.receiveTimeout:
        return ApiException("Receive timeout in connection with API server");
      case DioErrorType.sendTimeout:
        return ApiException("Send timeout in connection with API server");
      case DioErrorType.badResponse:
        return ApiException.fromResponse(dioError.response);
      case DioErrorType.unknown:
        if (dioError.message?.contains("SocketException") ?? false) {
          return ApiException("No Internet connection");
        }
        return ApiException("Unexpected error occurred");
      default:
        return ApiException("Something went wrong");
    }
  }

  factory ApiException.fromResponse(Response? response) {
    final statusCode = response?.statusCode;
    final message = response?.data?['message'] ?? 'Unknown error';
    switch (statusCode) {
      case 400:
        return ApiException('Bad request', statusCode: statusCode);
      case 401:
        return ApiException('Unauthorized', statusCode: statusCode);
      case 403:
        return ApiException('Forbidden', statusCode: statusCode);
      case 404:
        return ApiException('Not found', statusCode: statusCode);
      case 500:
        return ApiException('Internal server error', statusCode: statusCode);
      default:
        return ApiException(message, statusCode: statusCode);
    }
  }

  @override
  String toString() => 'ApiException(message: $message, statusCode: $statusCode)';
}
