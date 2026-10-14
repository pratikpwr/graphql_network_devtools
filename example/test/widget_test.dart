import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_network_devtools_example/main.dart';
import 'package:graphql_network_devtools_example/scenarios.dart';

void main() {
  testWidgets('shows one card for each scenario', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('How to use this demo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(scenarios.last.title), 200);
    expect(find.text(scenarios.last.title), findsOneWidget);
    expect(find.text('Run all'), findsOneWidget);
  });
}
