import 'package:flutter_test/flutter_test.dart';
import 'package:quick_scanner_plus/quick_scanner_plus.dart';

void main() {
 // const MethodChannel channel = MethodChannel('quick_scanner_plus');

  TestWidgetsFlutterBinding.ensureInitialized();
/*
  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });*/

  test('getPlatformVersion', () async {
    expect(await QuickScannerPlus.platformVersion, '42');
  });
}
