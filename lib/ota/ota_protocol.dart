
import 'dart:typed_data';
import 'dart:convert';

// App -> Device 헤더 및 푸터
const int APP_TO_DEVICE_HEADER = 0x1A;
const int APP_TO_DEVICE_FOOTER = 0x1B;

// Device -> App 헤더 및 푸터
const int DEVICE_TO_APP_HEADER = 0x2C;
const int DEVICE_TO_APP_FOOTER = 0x2D;

// 수신받는 데이터 길이
const int RECEIVE_BYTE_LEGNTH = 8;

// App -> Device 모드 정의
enum OtaMode {
  enterBootMode(0x01),
  versionCheck(0x02),
  sizeSend(0x03),
  memoryInit(0x04),
  write(0x05),
  checksum(0x06),
  bankSwap(0x07),
  reset(0x08),
  error(0x09);

  const OtaMode(this.value);
  final int value;
}

// Device -> App 응답 상태
enum OtaStatus {
  good,
  fail,
  unknown;

  static OtaStatus fromBytes(List<int> bytes) {
    try {
      final statusString = ascii.decode(bytes);
      if (statusString == 'GOOD') return OtaStatus.good;
      if (statusString == 'FAIL') return OtaStatus.fail;
    } catch (e) {
      return OtaStatus.unknown;
    }
    return OtaStatus.unknown;
  }
}

/// Device -> App 응답을 파싱한 모델
class DeviceResponse {
  final OtaMode echoedMode;
  final OtaStatus status;
  final int checksum;

  DeviceResponse({
    required this.echoedMode,
    required this.status,
    required this.checksum,
  });

  factory DeviceResponse.fromBytes(Uint8List bytes) {
    if (bytes.length != RECEIVE_BYTE_LEGNTH ||
        bytes.first != DEVICE_TO_APP_HEADER ||
        bytes.last != DEVICE_TO_APP_FOOTER) {
      throw const FormatException('Invalid response packet');
    }

    final mode = OtaMode.values.firstWhere(
      (m) => m.value == bytes[1],
      orElse: () => OtaMode.error,
    );
    final status = OtaStatus.fromBytes(bytes.sublist(2, 6));
    final checksum = bytes[6];

    return DeviceResponse(
      echoedMode: mode,
      status: status,
      checksum: checksum,
    );
  }

  @override
  String toString() {
    return 'DeviceResponse(mode: $echoedMode, status: $status, checksum: $checksum)';
  }
}

/// App -> Device 패킷을 생성하는 헬퍼 클래스
class PacketBuilder {
  static Uint8List create(OtaMode mode, {List<int> data = const []}) {
    final payload = <int>[];
    payload.add(APP_TO_DEVICE_HEADER);
    payload.add(mode.value);

    /// 실제 데이터
    payload.addAll(data);
    /// --- ----

    // 체크섬 계산 (헤더부터 데이터 끝까지)
    final checksum = payload.reduce((sum, byte) => sum + byte) & 0xFF;
    payload.add(checksum);
    payload.add(APP_TO_DEVICE_FOOTER);

    return Uint8List.fromList(payload);
  }
}
