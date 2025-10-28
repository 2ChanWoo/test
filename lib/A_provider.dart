import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod_test/B_provider.dart';

part 'A_provider.g.dart';

@riverpod
class AProvider extends _$AProvider {
  late int _bState;
  @override
  int build() {
    print("aprovider build");
    _bState = ref.watch(bProviderProvider);

    ref.onDispose(() {
      print("A provider disposed");
    });

    return 0;
  }

  void increment() {
    state++;
  }

  void addBState() {
    state += _bState;
  }
}