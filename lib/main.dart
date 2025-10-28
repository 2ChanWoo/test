import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main2.g.dart';

// Provider C: 상태가 변경되면 A의 함수를 트리거합니다.
@riverpod
class CNotifier extends _$CNotifier {
  @override
  int build() => 0;

  void updateState(int newState) {
    state = newState;
  }
}

// Provider B: 이 Provider의 상태가 변경되면 A의 상태도 변경됩니다.
@riverpod
class BNotifier extends _$BNotifier {
  @override
  int build() => 0;

  void updateState(int newState) {
    state = newState;
  }
}

// Provider A: B에 의존하고 C를 리슨합니다.
@riverpod
class ANotifier extends _$ANotifier {
  @override
  int build() {
    ref.onDispose(() {
      print("ANorifier disposed");
    });

    // 1. BProvider의 상태를 'watch'합니다.
    // bNotifierProvider의 상태가 바뀌면 이 build 메서드가 다시 실행되어
    // A의 상태가 자동으로 업데이트됩니다.
    final bState = ref.watch(bNotifierProvider);
    state = state*bState;

    // 2. CProvider의 상태 변경을 'listen'합니다.
    // C의 상태가 바뀔 때마다 specialFunction을 실행합니다.
    // listen은 UI를 재빌드하지 않고 부수 효과(side-effect)를 처리할 때 유용합니다.
    ref.listen(cNotifierProvider, (previous, next) {
      print('CProvider changed from $previous to $next. Executing special function.');
      specialFunction();
    });

    // B의 상태에 기반하여 A의 상태를 결정합니다. (예: B 상태 * 2)
    return 0;
  }

  // CProvider가 변경될 때 호출될 특정 함수
  void specialFunction() {
    print("--- AProvider's specialFunction has been executed! ---");
    state++;
    // 이곳에 API 호출, 데이터베이스 접근 등 원하는 로직을 구현할 수 있습니다.
  }
}

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Riverpod Dependencies Example')),
        body: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 각 Provider의 현재 상태를 watch합니다.
    final aState = ref.watch(aNotifierProvider);
    final bState = ref.watch(bNotifierProvider);
    final cState = ref.watch(cNotifierProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('AProvider State (B * 2): $aState', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Text('BProvider State: $bState', style: Theme.of(context).textTheme.headlineMedium),
          ElevatedButton(
            onPressed: () {
              // B의 상태를 업데이트합니다. A도 자동으로 업데이트됩니다.
              ref.read(bNotifierProvider.notifier).updateState(bState + 1);
            },
            child: const Text('Update B State'),
          ),
          const SizedBox(height: 40),
          Text('CProvider State: $cState', style: Theme.of(context).textTheme.headlineMedium),
          ElevatedButton(
            onPressed: () {
              // C의 상태를 업데이트합니다. 콘솔에서 A의 함수가 실행되는 것을 확인하세요.
              ref.read(cNotifierProvider.notifier).updateState(cState + 1);
            },
            child: const Text('Update C State (Triggers As function)'),
          ),
        ],
      ),
    );
  }
}