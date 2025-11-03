import 'package:flutter/services.dart';

class DfuService {
  static const _methodChannel = MethodChannel('com.example.riverpod_test/dfu_method');
  static const _eventChannel = EventChannel('com.example.riverpod_test/dfu_event');

  // DFU 상태 변화를 스트림으로 제공합니다.
  Stream<Map<String, dynamic>> get dfuStateStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      final Map<String, dynamic> eventMap = Map<String, dynamic>.from(event);
      return eventMap;
    });
  }

  // DFU 프로세스를 시작합니다.
  Future<void> startDfu(String address, String filePath) async {
    try {
      await _methodChannel.invokeMethod('startDfu', {
        'address': address,
        'filePath': filePath,
      });
    } on PlatformException catch (e) {
      // 네이티브에서 에러가 발생한 경우 처리
      print("Failed to start DFU: '${e.message}'.");
    }
  }

  // DFU 프로세스를 중단합니다.
  Future<void> abortDfu(String address) async {
    try {
      await _methodChannel.invokeMethod('abortDfu', {'address': address});
    } on PlatformException catch (e) {
      print("Failed to abort DFU: '${e.message}'.");
    }
  }
}
