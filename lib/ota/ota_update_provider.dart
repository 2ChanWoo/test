
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
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

// 서버 응답을 위한 모델
class FirmwareInfo {
  final String latestVersion;
  final String minAppVersion;
  final String firmwareUrl;
  final String checksum; // SHA-256

  FirmwareInfo.fromJson(Map<String, dynamic> json)
      : latestVersion = json['latest_version'],
        minAppVersion = json['min_app_version'],
        firmwareUrl = json['firmware_url'],
        checksum = json['checksum'];
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
        final firmwareInfo = await _checkServerForUpdate();
        final firmware = await _downloadFirmware(firmwareInfo);

        await _connectToDevice(deviceId);
        await _enterBootMode();
        await _checkVersion(); // 실제로는 여기서 펌웨어 버전 비교 로직이 들어갈 수 있습니다.
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
        // disconnect는 각 단계의 에러 핸들링에서 처리하거나 여기서 일괄 처리
        if (_btService.isConnected) await _btService.disconnect();
        // UI에 에러 메시지를 명확히 전달하기 위해 OtaState를 반환할 수도 있습니다.
        // 예: return OtaState(message: e.toString());
        rethrow;
      }
    });
  }

  // 각 단계를 처리하는 내부 (private) 메소드들

  Future<FirmwareInfo> _checkServerForUpdate() async {
    state = AsyncValue.data(OtaState(message: 'Checking for updates...'));

    // TODO: 실제 서버의 버전 체크 URL로 변경해야 합니다.
    final url = Uri.parse('https://your-server.com/api/firmware/latest');
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to check for updates. Status: ${response.statusCode}');
    }

    final firmwareInfo = FirmwareInfo.fromJson(json.decode(response.body));

    // 앱 최소 버전 체크
    final packageInfo = await PackageInfo.fromPlatform();
    final currentAppVersion = packageInfo.version;
    if (_isVersionLessThan(currentAppVersion, firmwareInfo.minAppVersion)) {
      throw Exception('Please update the app to version ${firmwareInfo.minAppVersion} or higher to proceed.');
    }

    // TODO: 현재 장치의 펌웨어 버전과 서버의 최신 버전을 비교하여 이미 최신 버전이면 중단하는 로직 추가
    // if (current_firmware_version >= firmwareInfo.latestVersion) {
    //   throw Exception('Firmware is already up to date.');
    // }

    return firmwareInfo;
  }

  Future<Uint8List> _downloadFirmware(FirmwareInfo info) async {
    state = AsyncValue.data(OtaState(message: 'Downloading firmware v${info.latestVersion}...'));

    final response = await http.get(Uri.parse(info.firmwareUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download firmware file.');
    }

    final bytes = response.bodyBytes;

    // 체크섬 검증
    final digest = sha256.convert(bytes);
    if (digest.toString() != info.checksum) {
      throw Exception('Firmware integrity check failed. File may be corrupted.');
    }

    state = AsyncValue.data(OtaState(message: 'Download complete!'));
    return bytes;
  }

  // 버전 문자열 비교 함수 (예: "1.2.0" < "1.2.1")
  bool _isVersionLessThan(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    final length = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < length; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 < p2) return true;
      if (p1 > p2) return false;
    }
    return false;
  }

  // --- 아래는 기존의 블루투스 통신 관련 메소드들 (변경 없음) ---

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

// BluetoothService 클래스에 isConnected와 같은 상태 getter를 추가하면 좋습니다.
extension BluetoothServiceState on BluetoothService {
  bool get isConnected => _connectedDevice != null;
}
