import 'package:flutter_test/flutter_test.dart';
import 'package:hyouka_tv_control/main.dart';

void main() {
  testWidgets('launches the TV control app', (tester) async {
    await tester.pumpWidget(const HyoukaTvControlApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Hyouka TV Control'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
