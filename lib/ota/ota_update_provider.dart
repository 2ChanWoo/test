
import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
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
    // 초기 상태
    return OtaState(message: 'Ready to update');
  }

  // 업데이트 시퀀스 시작
  Future<void> startUpdate(String deviceId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        // 1. 펌웨어 파일 선택
        state = AsyncValue.data(OtaState(message: 'Selecting firmware file...'));
        final firmware = await _pickFirmwareFile();
        if (firmware == null) {
          return OtaState(message: 'Firmware file not selected.');
        }

        // 2. 블루투스 연결
        state = AsyncValue.data(OtaState(message: 'Connecting to device...'));
        final connected = await _btService.connect(deviceId);
        if (!connected) {
          throw Exception('Failed to connect to the device.');
        }

        // 3. 부트모드 진입
        state = AsyncValue.data(OtaState(message: 'Entering boot mode...'));
        await _btService.sendCommand(OtaMode.enterBootMode);

        // 4. 버전 체크
        state = AsyncValue.data(OtaState(message: 'Checking version...'));
        await _btService.sendCommand(OtaMode.versionCheck);

        // 5. 펌웨어 사이즈 전송
        state = AsyncValue.data(OtaState(message: 'Sending firmware size...'));
        final sizeBytes = ByteData(4)..setUint32(0, firmware.lengthInBytes, Endian.little);
        await _btService.sendCommand(OtaMode.sizeSend, data: sizeBytes.buffer.asUint8List());

        // 6. 메모리 초기화
        state = AsyncValue.data(OtaState(message: 'Initializing memory...'));
        await _btService.sendCommand(OtaMode.memoryInit);

        // 7. 데이터 전송 (청크 단위)
        const chunkSize = 16; // n-1, n-2 바이트 제외한 순수 데이터 크기. 실제 MTU에 맞춰 조절
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

        // 8. 전체 펌웨어 체크섬 검사
        state = AsyncValue.data(OtaState(message: 'Verifying checksum...', progress: 1.0));
        final firmwareChecksum = firmware.reduce((sum, byte) => sum + byte) & 0xFF;
        await _btService.sendCommand(OtaMode.checksum, data: [firmwareChecksum]);

        // 9. 뱅크 스왑
        state = AsyncValue.data(OtaState(message: 'Swapping memory bank...', progress: 1.0));
        await _btService.sendCommand(OtaMode.bankSwap);

        // 10. 리셋
        state = AsyncValue.data(OtaState(message: 'Resetting device...', progress: 1.0));
        await _btService.sendCommand(OtaMode.reset);

        // 11. 연결 종료 및 재연결 대기
        await _btService.disconnect();
        state = AsyncValue.data(OtaState(message: 'Update complete! Reconnecting...', progress: 1.0));

        // TODO: 장치가 재부팅된 후 다시 연결하는 로직 구현
        await Future.delayed(const Duration(seconds: 5)); // 재부팅 시간 대기
        await _btService.connect(deviceId);

        return OtaState(message: 'Successfully reconnected!', progress: 1.0);

      } catch (e) {
        // 에러 처리
        print('OTA Error: $e');
        await _btService.disconnect();
        rethrow;
      }
    });
  }

  Future<Uint8List?> _pickFirmwareFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['bin']);
    if (result != null && result.files.single.bytes != null) {
      return result.files.single.bytes;
    }
    return null;
  }
}
