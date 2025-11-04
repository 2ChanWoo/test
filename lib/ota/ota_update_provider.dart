import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod_test/ota/bluetooth_service.dart';
import 'package:riverpod_test/ota/ota_protocol.dart';

part 'ota_update_provider.g.dart';

// OTA 업데이트 상태를 나타내는 모델
class OtaState {
  final String message;
  final double progress; // 0.0 ~ 1.0

  OtaState({this.message = '', this.progress = 0.0});

  OtaState copyWith({String? message, double? progress}) {
    return OtaState(
      message: message ?? this.message,
      progress: progress ?? this.progress,
    );
  }
}

@riverpod
class OtaUpdate extends _$OtaUpdate {
  final _btService = BluetoothService();

  @override
  FutureOr<OtaState> build() {
    return OtaState(message: 'Ready to update');
  }

  // 업데이트 시퀀스 시작 (오케스트레이션 역할)
  Future<void> startUpdate(String deviceId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        final firmware = await _loadFirmwareFromAssets();

        await _connectToDevice(deviceId);
        await _enterBootMode();
        await _checkVersion();
        await _sendFirmwareSize(firmware);
        await _initializeMemory();
        await _writeFirmwareData(firmware);
        await _verifyChecksum(firmware);
        await _swapBank();
        await _resetDevice();
        await _reconnect(deviceId);

        return OtaState(message: 'Successfully reconnected!', progress: 1.0);

      } catch (e) {
        print('OTA Error: $e');

        // 안정적인 실패 후를 위해 연결 해제? 또는 연결 유지 후 재시도 버튼으로?
        // if (_btService.isConnected) await _btService.disconnect();
        rethrow;
      }
    });
  }

  // 각 단계를 처리하는 내부 (private) 메소드들

  Future<Uint8List> _loadFirmwareFromAssets() async {
    state = AsyncValue.data(OtaState(message: 'Loading firmware from assets...'));
    // TODO: 'update.bin'을 실제 펌웨어 파일 이름으로 변경해야 합니다.
    const firmwarePath = 'assets/firmware/update.bin';
    try {
      final byteData = await rootBundle.load(firmwarePath);
      state = AsyncValue.data(OtaState(message: 'Firmware loaded!'));
      return byteData.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to load firmware file from assets.');
    }
  }

  // --- 아래는 블루투스 통신 관련 메소드들 (변경 없음) ---

  Future<void> _connectToDevice(String deviceId) async {
    state = AsyncValue.data(OtaState(message: 'Connecting to device...'));
    final connected = await _btService.connect(deviceId);
    if (!connected) throw Exception('Failed to connect to the device.');
  }

  Future<void> _enterBootMode() async {
    state = AsyncValue.data(OtaState(message: 'Entering boot mode...'));
    await _btService.sendCommand(OtaMode.enterBootMode);
  }

  Future<void> _checkVersion() async {
    state = AsyncValue.data(OtaState(message: 'Checking version...'));
    await _btService.sendCommand(OtaMode.versionCheck);
  }

  Future<void> _sendFirmwareSize(Uint8List firmware) async {
    state = AsyncValue.data(OtaState(message: 'Sending firmware size...'));
    final sizeBytes = ByteData(4)..setUint32(0, firmware.lengthInBytes, Endian.little);
    await _btService.sendCommand(OtaMode.sizeSend, data: sizeBytes.buffer.asUint8List());
  }

  Future<void> _initializeMemory() async {
    state = AsyncValue.data(OtaState(message: 'Initializing memory...'));
    await _btService.sendCommand(OtaMode.memoryInit);
  }

  Future<void> _writeFirmwareData(Uint8List firmware) async {
    const chunkSize = 16; // 실제 MTU에 맞춰 조절
    final totalChunks = (firmware.length / chunkSize).ceil();

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize > firmware.length) ? firmware.length : (start + chunkSize);
      final chunk = firmware.sublist(start, end);

      final progress = (i + 1) / totalChunks;
      state = AsyncValue.data(OtaState(
        message: 'Writing firmware... (${(progress * 100).toStringAsFixed(1)}%)',
        progress: progress,
      ));

      await _btService.sendCommand(OtaMode.write, data: chunk);
    }
  }

  Future<void> _verifyChecksum(Uint8List firmware) async {
    state = AsyncValue.data(OtaState(message: 'Verifying checksum...', progress: 1.0));
    final firmwareChecksum = firmware.reduce((sum, byte) => sum + byte) & 0xFF;
    await _btService.sendCommand(OtaMode.checksum, data: [firmwareChecksum]);
  }

  Future<void> _swapBank() async {
    state = AsyncValue.data(OtaState(message: 'Swapping memory bank...', progress: 1.0));
    await _btService.sendCommand(OtaMode.bankSwap);
  }

  Future<void> _resetDevice() async {
    state = AsyncValue.data(OtaState(message: 'Resetting device...', progress: 1.0));
    await _btService.sendCommand(OtaMode.reset);
    await _btService.disconnect();
  }

  Future<void> _reconnect(String deviceId) async {
    state = AsyncValue.data(OtaState(message: 'Update complete! Reconnecting...', progress: 1.0));
    await Future.delayed(const Duration(seconds: 5)); // 재부팅 시간 대기
    await _btService.connect(deviceId);
  }
}