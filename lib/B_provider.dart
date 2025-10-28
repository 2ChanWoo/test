import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'B_provider.g.dart';

@riverpod
class BProvider extends _$BProvider {
  @override
  int build() {
    print("BProvider build()");
    ref.onDispose(() {
      print("BProvider disposed");
    });
    return 0;
  }

  void increment() {
    state++;
  }
}
