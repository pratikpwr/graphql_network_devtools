import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_network_devtools/graphql_network_devtools.dart';
import 'package:graphql_network_devtools_extension/src/network_controller.dart';
import 'package:graphql_network_devtools_extension/src/profile_source.dart';

import 'fake_profile_source.dart';

void main() {
  late FakeProfileSource source;
  late NetworkController controller;

  setUp(() {
    source = FakeProfileSource();
    controller = NetworkController(source);
  });

  tearDown(() => controller.dispose());

  test('captures GraphQL requests and ignores other traffic', () async {
    source
      ..put('1', graphQLRequest('1', query: 'query GetUser { user { id } }'))
      ..put(
        '2',
        HttpTransaction(
          id: transactionKey(isolateId, '2'),
          method: 'GET',
          uri: Uri.parse('https://cdn.example.com/logo.png'),
          startTime: DateTime(2026),
          endTime: DateTime(2026),
          statusCode: 200,
        ),
      )
      ..put(
        '3',
        HttpTransaction(
          id: transactionKey(isolateId, '3'),
          method: 'POST',
          uri: Uri.parse('https://api.example.com/rest/users'),
          startTime: DateTime(2026),
          endTime: DateTime(2026),
          statusCode: 201,
          requestHeaders: const {'content-type': 'application/json'},
          requestBody: '{"name":"x"}',
        ),
      );

    await controller.refresh();

    expect(source.enabledIsolates, [isolateId]);
    expect(controller.operations.map((o) => o.displayName), ['GetUser']);
    // The image is skipped without a body fetch. The REST call is read once.
    expect(source.fetchedRequests, ['1', '3']);

    source.put('3', source.lastRestCopy('3'));
    await controller.refresh();
    expect(source.fetchedRequests, ['1', '3']);
  });

  test('updates a pending operation when its response arrives', () async {
    source.put('1', graphQLRequest('1', query: '{ a }', complete: false));
    await controller.refresh();
    expect(controller.operations.single.status, GraphQLOperationStatus.pending);

    source.put('1', graphQLRequest('1', query: '{ a }'));
    await controller.refresh();
    expect(controller.operations.single.status, GraphQLOperationStatus.success);
  });

  test('keeps the selection when the operation updates', () async {
    source.put('1', graphQLRequest('1', query: '{ a }', complete: false));
    await controller.refresh();
    controller.select(controller.operations.single);

    source.put('1', graphQLRequest('1', query: '{ a }'));
    await controller.refresh();
    expect(controller.selected?.status, GraphQLOperationStatus.success);
  });

  test('lists the newest operation first', () async {
    source
      ..put('1', graphQLRequest('1', query: 'query Old { a }', startSecond: 1))
      ..put('2', graphQLRequest('2', query: 'query New { a }', startSecond: 2));
    await controller.refresh();
    expect(controller.operations.map((o) => o.displayName), ['New', 'Old']);
  });

  group('filters', () {
    setUp(() async {
      source
        ..put(
          '1',
          graphQLRequest(
            '1',
            query: 'query GetUser { user { id } }',
            variables: {'userId': 'abc'},
            startSecond: 1,
          ),
        )
        ..put(
          '2',
          graphQLRequest(
            '2',
            query: 'mutation SaveUser { save }',
            response: {
              'errors': [
                {'message': 'denied'},
              ],
            },
            startSecond: 2,
          ),
        )
        ..put(
          '3',
          graphQLRequest(
            '3',
            query: 'subscription OnUser { user }',
            startSecond: 3,
          ),
        );
      await controller.refresh();
    });

    test('filter by text in the name, query or variables', () {
      controller.setSearchText('save');
      expect(controller.operations.map((o) => o.displayName), ['SaveUser']);

      controller.setSearchText('abc');
      expect(controller.operations.map((o) => o.displayName), ['GetUser']);
    });

    test('filter by type and by errors', () {
      controller.toggleType(GraphQLOperationType.query);
      controller.toggleType(GraphQLOperationType.subscription);
      expect(controller.operations.map((o) => o.displayName), [
        'OnUser',
        'GetUser',
      ]);

      controller
        ..clearFilters()
        ..setErrorsOnly(true);
      expect(controller.operations.map((o) => o.displayName), ['SaveUser']);
      expect(controller.errorCount, 1);
      expect(controller.countOf(GraphQLOperationType.mutation), 1);
    });

    test('moveSelection walks the visible list', () {
      controller.moveSelection(1);
      expect(controller.selected?.displayName, 'OnUser');
      controller.moveSelection(1);
      expect(controller.selected?.displayName, 'SaveUser');
      controller.moveSelection(-5);
      expect(controller.selected?.displayName, 'OnUser');
    });
  });

  test('ignores new requests while recording is paused', () async {
    source.put('1', graphQLRequest('1', query: '{ a }', complete: false));
    await controller.refresh();

    controller.setRecording(false);
    source
      ..put('1', graphQLRequest('1', query: '{ a }'))
      ..put('2', graphQLRequest('2', query: '{ b }'));
    await controller.refresh();

    expect(controller.operations, hasLength(1));
    expect(controller.operations.single.status, GraphQLOperationStatus.success);

    controller.setRecording(true);
    source.put('3', graphQLRequest('3', query: '{ c }'));
    await controller.refresh();
    expect(controller.operations, hasLength(2));
  });

  test('clear removes all operations and the selection', () async {
    source.put('1', graphQLRequest('1', query: '{ a }'));
    await controller.refresh();
    controller.select(controller.operations.single);

    await controller.clear();
    expect(controller.operations, isEmpty);
    expect(controller.selected, isNull);
  });

  test('splits batched requests into operations', () async {
    final batch = graphQLRequest('1', query: '');
    source.put(
      '1',
      HttpTransaction(
        id: batch.id,
        method: 'POST',
        uri: batch.uri,
        startTime: batch.startTime,
        endTime: batch.endTime,
        statusCode: 200,
        requestHeaders: batch.requestHeaders,
        requestBody: '[{"query":"query A { a }"},{"query":"query B { b }"}]',
        responseBody: '[{"data":{"a":1}},{"data":{"b":2}}]',
      ),
    );
    await controller.refresh();
    expect(controller.operations.map((o) => o.displayName), ['A', 'B']);
  });
}

extension on FakeProfileSource {
  /// Returns the stored request again, to simulate a later update event.
  HttpTransaction lastRestCopy(String requestId) => HttpTransaction(
    id: transactionKey(isolateId, requestId),
    method: 'POST',
    uri: Uri.parse('https://api.example.com/rest/users'),
    startTime: DateTime(2026),
    endTime: DateTime(2026),
    statusCode: 201,
    requestHeaders: const {'content-type': 'application/json'},
    requestBody: '{"name":"x"}',
  );
}
