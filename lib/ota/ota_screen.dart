
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_test/ota/ota_update_provider.dart';

class OtaScreen extends ConsumerWidget {
  const OtaScreen({super.key});

  // TODO: 실제 업데이트할 장치의 ID를 전달해야 합니다.
  final String targetDeviceId = "00:11:22:33:44:55";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otaState = ref.watch(otaUpdateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firmware Update (OTA)'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (otaState.isLoading)
                const CircularProgressIndicator()
              else
                const Icon(Icons.cloud_upload, size: 80, color: Colors.blue),
              const SizedBox(height: 30),
              otaState.when(
                data: (state) => Column(
                  children: [
                    if (state.progress > 0)
                      LinearProgressIndicator(
                        value: state.progress,
                        minHeight: 10,
                      ),
                    const SizedBox(height: 10),
                    Text(
                      state.message,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                loading: () => Text(
                  'Initializing...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                error: (err, stack) => Text(
                  'Error: $err',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                icon: const Icon(Icons.system_update),
                label: const Text('Start Firmware Update'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                // 로딩 중일 때는 버튼 비활성화
                onPressed: otaState.isLoading
                    ? null
                    : () {
                        ref.read(otaUpdateProvider.notifier).startUpdate(targetDeviceId);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
