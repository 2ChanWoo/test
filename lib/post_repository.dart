import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_test/dio_provider.dart';
import 'package:riverpod_test/post.dart';

// PostRepository를 제공하는 Provider
final postRepositoryProvider = Provider<PostRepository>((ref) {
  // dioProvider를 사용하여 Dio 인스턴스를 가져옵니다.
  final dio = ref.watch(dioProvider);
  return PostRepository(dio);
});

class PostRepository {
  PostRepository(this._dio);
  final Dio _dio;

  // 게시물 목록을 가져오는 메소드
  Future<List<Post>> fetchPosts() async {
    try {
      final response = await _dio.get('/posts');
      // 응답 데이터를 List<dynamic>으로 캐스팅한 후, 각 항목을 Post.fromJson으로 변환
      final List<dynamic> data = response.data;
      return data.map((postJson) => Post.fromJson(postJson as Map<String, dynamic>)).toList();
    } on DioError catch (e) {
      // DioError가 발생하면 ApiException으로 변환하여 다시 던집니다.
      // 인터셉터에서 이미 변환했으므로 e.error는 ApiException 타입일 것입니다.
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException.fromDioError(e);
    }
  }
}
