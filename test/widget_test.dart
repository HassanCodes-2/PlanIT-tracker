import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit/app.dart';

void main() {
  testWidgets('app renders the Today shell with bottom navigation',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PlanItApp()));
    await tester.pump();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}