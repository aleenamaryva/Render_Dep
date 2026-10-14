import 'package:flutter_test/flutter_test.dart';

import 'package:softwarep1/app.dart';

void main() {
  testWidgets('LifeTrace app loads splash and welcome screen', (tester) async {
    await tester.pumpWidget(const LifeTraceApp());

    expect(find.text('LifeTrace'), findsWidgets);
  });
}
