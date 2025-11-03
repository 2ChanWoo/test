import 'package:flutter/material.dart';
import 'ota_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DFU OTA Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // TODO: 실제 블루투스 장치 검색 후 스캔된 디바이스의 주소를 전달해야 합니다.
      // 여기서는 예시로 하드코딩된 주소를 사용합니다.
      home: const OtaScreen(deviceAddress: "00:11:22:33:44:55"),
    );
  }
}
