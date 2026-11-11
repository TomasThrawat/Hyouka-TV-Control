import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hyouka_tv_control/main.dart';

void mockPlatform({
  required bool isTelevision,
  bool paired = false,
  List<dynamic> devices = const [],
  List<String>? sentText,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(native, (call) async {
    switch (call.method) {
      case 'isTelevision':
        return isTelevision;
      case 'getPreferences':
        return {'language': 'en', 'theme': 'pureBlack'};
      case 'checkStatus':
        return {
          'running': true,
          'permissionGranted': true,
          'serviceConnected': true,
          'model': 'Test TV',
        };
      case 'readDashboard':
        return {
          'brightness': 50,
          'mediaVolume': 40,
          'systemVolume': 40,
          'alarmVolume': 40,
          'timeoutMs': 600000,
          'device': 'Test TV',
        };
      case 'ensureRemoteKeyboardServer':
        return {'running': true, 'pin': '123456'};
      case 'remoteKeyboardStatus':
        return {
          'running': true,
          'pin': '123456',
          'keyboardEnabled': true,
          'keyboardSelected': true,
        };
      case 'phoneRemoteStatus':
        return {
          'paired': paired,
          'tvId': paired ? 'test-tv-id' : '',
          'name': 'Living Room TV',
          'host': '192.168.1.50',
          'port': 8765,
        };
      case 'discoverRemoteTvs':
        return devices;
      case 'updateRemoteTvAddress':
      case 'sendRemoteComposition':
      case 'finishRemoteComposition':
        if (call.method == 'sendRemoteComposition' && sentText != null) {
          sentText.add(call.arguments['text'] as String);
        }
        return true;
      case 'showKeyboardPicker':
        return true;
      default:
        return null;
    }
  });
}

void main() {
  testWidgets('shows TV controls and the one-time phone pairing code', (tester) async {
    mockPlatform(isTelevision: true);
    await tester.pumpWidget(const HyoukaTvControlApp());
    await tester.pumpAndSettle();

    expect(find.text('Hyouka TV Control'), findsWidgets);
    expect(find.text('Phone keyboard'), findsOneWidget);
    await tester.tap(find.text('Phone keyboard'));
    await tester.pumpAndSettle();
    expect(find.text('123456'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone remote opens its keyboard icon and streams text', (tester) async {
    final sentText = <String>[];
    mockPlatform(isTelevision: false, paired: true, sentText: sentText);

    await tester.pumpWidget(const HyoukaTvControlApp());
    await tester.pumpAndSettle();

    expect(find.text('Hyouka Remote'), findsOneWidget);
    expect(find.text('Keyboard'), findsOneWidget);
    await tester.tap(find.text('Keyboard'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'مرحبا');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(sentText, contains('مرحبا'));
    expect(tester.takeException(), isNull);
  });
}
