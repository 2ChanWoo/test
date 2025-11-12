import 'package:dio/dio.dart';
import 'package:riverpod_test/api_exception.dart';
import 'package:riverpod_test/post.dart';

class PostRepository {
  PostRepository(this._dio);
  final Dio _dio;

  Future<List<Post>> fetchPosts() async {
    try {
      final response = await _dio.get('/posts');
      final List<dynamic> data = response.data;
      return data.map((postJson) => Post.fromJson(postJson as Map<String, dynamic>)).toList();
    } on DioError catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException.fromDioError(e);
    }
  }
}
