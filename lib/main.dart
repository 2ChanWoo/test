import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_test/post.dart';
import 'package:riverpod_test/post_repository.dart';

// 게시물 목록을 비동기적으로 가져오는 FutureProvider
final postsProvider = FutureProvider<List<Post>>((ref) {
  // postRepositoryProvider를 사용하여 PostRepository 인스턴스를 가져와서 게시물 목록을 fetch합니다.
  return ref.watch(postRepositoryProvider).fetchPosts();
});

void main() {
  runApp(
    // Riverpod를 사용하기 위해 ProviderScope로 앱을 감쌉니다.
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dio Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const PostsScreen(),
    );
  }
}

class PostsScreen extends ConsumerWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // postsProvider를 watch하여 데이터 상태(로딩, 데이터, 에러)를 감지합니다.
    final asyncPosts = ref.watch(postsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
      ),
      // AsyncValue를 사용하여 상태에 따라 다른 위젯을 렌더링합니다.
      body: asyncPosts.when(
        // 데이터가 로딩 중일 때
        loading: () => const Center(child: CircularProgressIndicator()),
        // 에러가 발생했을 때
        error: (err, stack) => Center(child: Text('Error: $err')),
        // 데이터 로딩이 성공했을 때
        data: (posts) {
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return ListTile(
                title: Text(post.title),
                subtitle: Text(post.body),
              );
            },
          );
        },
      ),
    );
  }
}
