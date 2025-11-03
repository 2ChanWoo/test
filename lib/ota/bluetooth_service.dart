
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:riverpod_test/ota/ota_protocol.dart';

// TODO: 실제 장치의 서비스 및 특성 UUID로 변경해야 합니다.
final Guid SERVICE_UUID = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
final Guid WRITE_CHARACTERISTIC_UUID = Guid("0000ffe1-0000-1000-8000-00805f9b34fb");
final Guid NOTIFY_CHARACTERISTIC_UUID = Guid("0000ffe2-0000-1000-8000-00805f9b34fb");

class BluetoothService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _notificationSubscription;

  // 응답을 받기 위한 Completer
  Completer<DeviceResponse>? _responseCompleter;

  // TODO: 실제 장치 검색 및 연결 로직 구현
  Future<bool> connect(String deviceId) async {
    // 이 부분은 실제 장치 검색 및 연결 로직으로 대체되어야 합니다.
    // 예시로, 이미 연결된 장치가 있다고 가정합니다.
    // _connectedDevice = ...;
    // await _discoverServices();
    print("Connecting to $deviceId...");
    // 재연결 로직을 위해 연결 상태를 관리해야 합니다.
    return true;
  }

  Future<void> disconnect() async {
    await _notificationSubscription?.cancel();
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    print("Disconnected.");
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;
    final services = await _connectedDevice!.discoverServices();
    final service = services.firstWhere((s) => s.uuid == SERVICE_UUID);

    _writeCharacteristic = service.characteristics
        .firstWhere((c) => c.uuid == WRITE_CHARACTERISTIC_UUID);

    _notifyCharacteristic = service.characteristics
        .firstWhere((c) => c.uuid == NOTIFY_CHARACTERISTIC_UUID);

    await _notifyCharacteristic!.setNotifyValue(true);
    _notificationSubscription = _notifyCharacteristic!.value.listen((value) {
      if (_responseCompleter != null && !(_responseCompleter?.isCompleted ?? true)) {
        try {
          final response = DeviceResponse.fromBytes(Uint8List.fromList(value));
          _responseCompleter!.complete(response);
        } catch (e) {
          _responseCompleter!.completeError(e);
        }
      }
    });
  }

  /// 커맨드를 보내고 응답을 기다리는 핵심 메소드
  Future<DeviceResponse> sendCommand(OtaMode mode, {List<int> data = const []}) async {
    if (_writeCharacteristic == null) {
      // 실제 구현에서는 서비스를 먼저 찾아야 함
      await _discoverServices();
    }

    final packet = PacketBuilder.create(mode, data: data);
    _responseCompleter = Completer<DeviceResponse>();

    try {
      // 패킷 전송
      await _writeCharacteristic!.write(packet, withoutResponse: false);
      print('Sent: $mode, data_len: ${data.length}');

      // 타임아웃과 함께 응답 기다리기
      final response = await _responseCompleter!.future.timeout(const Duration(seconds: 5));
      print('Received: $response');

      if (response.status != OtaStatus.good) {
        throw Exception('Received FAIL status from device for mode $mode');
      }
      return response;
    } on TimeoutException {
      print('Error: Response timeout for mode $mode');
      throw Exception('Response timeout for mode $mode');
    } catch (e) {
      print('Error sending command $mode: $e');
      rethrow;
    }
  }
}
