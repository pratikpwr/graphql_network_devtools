import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_network_devtools_extension/src/network_controller.dart';
import 'package:graphql_network_devtools_extension/src/support/zoom.dart';
import 'package:graphql_network_devtools_extension/src/ui/network_screen.dart';

import 'fake_profile_source.dart';

void main() {
  late FakeProfileSource source;
  late NetworkController controller;
  late ZoomController zoom;
  late ValueNotifier<AppConnection> connection;
  final clipboard = <String>[];

  setUp(() {
    source = FakeProfileSource();
    controller = NetworkController(source);
    zoom = ZoomController();
    connection = ValueNotifier(AppConnection.connected);
    clipboard.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    controller.dispose();
    zoom.dispose();
    connection.dispose();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkScreen(
            controller: controller,
            zoom: zoom,
            connection: connection,
          ),
        ),
      ),
    );
  }

  Future<void> addOperations() async {
    source
      ..put(
        '1',
        graphQLRequest(
          '1',
          query:
              r'query GetCountry($code: ID!) { country(code: $code) { name } }',
          variables: {'code': 'IN'},
          response: {
            'data': {
              'country': {'name': 'India'},
            },
          },
          startSecond: 1,
        ),
      )
      ..put(
        '2',
        graphQLRequest(
          '2',
          query: 'mutation CreatePost { createPost { id } }',
          response: {
            'data': null,
            'errors': [
              {
                'message': 'Not allowed',
                'path': ['createPost'],
              },
            ],
          },
          startSecond: 2,
        ),
      );
    await controller.refresh();
  }

  testWidgets('shows a waiting message when no operation is captured', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Waiting for GraphQL requests'), findsOneWidget);
  });

  testWidgets('shows a message for web apps', (tester) async {
    connection.value = AppConnection.webApp;
    await pumpScreen(tester);
    expect(find.text('Web apps are not supported'), findsOneWidget);
  });

  testWidgets('lists operations and shows the details of a selection', (
    tester,
  ) async {
    await addOperations();
    await pumpScreen(tester);

    expect(find.text('GetCountry'), findsOneWidget);
    expect(find.text('CreatePost'), findsOneWidget);
    expect(find.text('Select an operation'), findsOneWidget);

    await tester.tap(find.text('GetCountry'));
    await tester.pumpAndSettle();

    // The query is formatted, with one field on each line.
    expect(
      find.textContaining(
        'country(code: \$code) {\n    name',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Variables'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('"code": "IN"', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shows GraphQL errors in the response tab', (tester) async {
    await addOperations();
    await pumpScreen(tester);

    await tester.tap(find.text('CreatePost'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('Response')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 GraphQL error'), findsOneWidget);
    expect(
      find.textContaining('Not allowed', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('copy buttons put the text on the clipboard', (tester) async {
    await addOperations();
    await pumpScreen(tester);
    await tester.tap(find.text('GetCountry'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'cURL'));
    await tester.pump();
    expect(
      clipboard.last,
      startsWith("curl 'https://api.example.com/graphql'"),
    );
    expect(find.widgetWithText(OutlinedButton, 'Copied'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Response'));
    await tester.pump();
    expect(clipboard.last, contains('"name": "India"'));

    await tester.tap(find.byTooltip('Copy query'));
    await tester.pump();
    expect(clipboard.last, startsWith(r'query GetCountry($code: ID!) {'));

    // Let the "Copied" timers end.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Ctrl+C copies the selected text', (tester) async {
    await addOperations();
    await pumpScreen(tester);
    await tester.tap(find.text('GetCountry'));
    await tester.pumpAndSettle();

    final query = find.textContaining('query GetCountry', findRichText: true);
    final start = tester.getTopLeft(query) + const Offset(2, 8);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(start + const Offset(60, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(clipboard, isNotEmpty);
    expect('query GetCountry', startsWith(clipboard.last));
  });

  testWidgets('filters by text and type', (tester) async {
    await addOperations();
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, 'country');
    await tester.pumpAndSettle();
    expect(find.text('GetCountry'), findsOneWidget);
    expect(find.text('CreatePost'), findsNothing);
    expect(find.text('1 of 2'), findsOneWidget);

    await tester.tap(find.text('Reset filters').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Mutation'));
    await tester.pumpAndSettle();
    expect(find.text('GetCountry'), findsNothing);
    expect(find.text('CreatePost'), findsOneWidget);
  });

  testWidgets('zoom buttons and shortcuts change the zoom', (tester) async {
    await pumpScreen(tester);
    expect(find.text('100%'), findsOneWidget);

    final title = find.text('GraphQL Network');
    final normalHeight = tester.getSize(title).height;

    await tester.tap(find.byTooltip('Zoom in (Ctrl/Cmd + +)'));
    await tester.pump();
    expect(find.text('110%'), findsOneWidget);
    // The whole UI scales, so the text is drawn larger on screen.
    final zoomedRect = tester.getRect(title);
    expect(zoomedRect.height, closeTo(normalHeight * 1.1, 0.5));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.text('120%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('arrow keys move the selection', (tester) async {
    await addOperations();
    await pumpScreen(tester);

    await tester.tap(find.text('CreatePost'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.selected?.displayName, 'GetCountry');
  });
}
