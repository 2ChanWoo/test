import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository();
}

class AuthRepository {
  String? _accessToken = 'my-secret-access-token'; // 초기 더미 토큰
  String? _refreshToken = 'my-secret-refresh-token';

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<String> refresh() async {
    print('AuthRepository: Refreshing token...');
    await Future.delayed(const Duration(seconds: 1)); // 네트워크 요청 흉내
    _accessToken = 'new-refreshed-access-token-${DateTime.now().millisecondsSinceEpoch}';
    print('AuthRepository: New token acquired: $_accessToken');
    return _accessToken!;
  }

  void expireToken() {
    _accessToken = 'expired-token';
  }
}
