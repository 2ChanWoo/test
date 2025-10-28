import 'package:flutter_riverpod/flutter_riverpod.dart';

// 실제 앱에서는 flutter_secure_storage 등을 사용하여 토큰을 관리합니다.
// 여기서는 설명을 위해 간단한 Fake Repository를 사용합니다.
final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthRepository {
  String? _accessToken = 'my-secret-access-token'; // 초기 더미 토큰
  final String _refreshToken = 'my-secret-refresh-token';

  Future<String?> get accessToken => Future.value(_accessToken);
  Future<String?> get refreshToken => Future.value(_refreshToken);

  // 토큰 재발급 시뮬레이션
  Future<String> refreshToken() async {
    print('AuthRepository: Refreshing token...');
    await Future.delayed(const Duration(seconds: 1)); // 네트워크 요청 흉내
    _accessToken = 'new-refreshed-access-token-${DateTime.now().millisecondsSinceEpoch}';
    print('AuthRepository: New token acquired: $_accessToken');
    return _accessToken!;
  }

  // 401 에러를 시뮬레이션하기 위해 토큰을 일부러 만료시킵니다.
  void expireToken() {
    _accessToken = 'expired-token';
  }
}
