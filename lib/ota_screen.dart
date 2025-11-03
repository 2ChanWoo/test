import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dfu_service.dart';

class OtaScreen extends StatefulWidget {
  // 실제 앱에서는 BluetoothDevice 객체나 주소를 받아와야 합니다.
  final String deviceAddress;

  const OtaScreen({Key? key, required this.deviceAddress}) : super(key: key);

  @override
  _OtaScreenState createState() => _OtaScreenState();
}

class _OtaScreenState extends State<OtaScreen> {
  final DfuService _dfuService = DfuService();
  StreamSubscription? _dfuStateSubscription;

  String _status = "";
  int _progress = 0;
  String? _filePath;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _dfuStateSubscription = _dfuService.dfuStateStream.listen((event) {
      final String eventName = event['eventName'] ?? 'unknown';
      final dynamic data = event['data'];

      setState(() {
        switch (eventName) {
          case 'dfu_process_starting':
            _status = "업데이트 시작 중...";
            _progress = 0;
            break;
          case 'progress_changed':
            _status = "업로드 중...";
            _progress = data['percent'] ?? 0;
            break;
          case 'dfu_completed':
            _status = "업데이트 완료";
            _progress = 100;
            break;
          case 'dfu_aborted':
            _status = "업데이트 중단됨";
            _progress = 0;
            break;
          case 'on_error':
            _status = "에러: ${data['message']}";
            _progress = 0;
            break;
          default:
            _status = "알 수 없는 상태";
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _dfuStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'], // DFU 펌웨어는 보통 zip 파일입니다.
    );

    if (result != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    } else {
      // 사용자가 파일 선택을 취소함
    }
  }

  void _startUpdate() {
    if (_filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('펌웨어 파일을 먼저 선택해주세요.')),
      );
      return;
    }
    _dfuService.startDfu(widget.deviceAddress, _filePath!);
  }

  void _abortUpdate() {
    _dfuService.abortDfu(widget.deviceAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firmware Update (OTA)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Device: ${widget.deviceAddress}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('펌웨어 파일 선택'),
              onPressed: _pickFile,
            ),
            if (_fileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '선택된 파일: $_fileName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 40),
            Text(
              _status,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 10,
            ),
            const SizedBox(height: 5),
            Text(
              '$_progress%',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              child: const Text('업데이트 시작'),
              onPressed: _filePath != null ? _startUpdate : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              child: const Text('업데이트 중단'),
              onPressed: _abortUpdate,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
