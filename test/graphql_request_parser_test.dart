import 'dart:convert';

import 'package:graphql_network_devtools/graphql_network_devtools.dart';
import 'package:test/test.dart';

HttpTransaction _post(
  Object? body, {
  Object? response,
  String contentType = 'application/json',
  int? statusCode = 200,
  bool complete = true,
  String? error,
  String url = 'https://api.example.com/graphql',
}) {
  final start = DateTime(2026, 1, 1, 12);
  return HttpTransaction(
    id: '42',
    method: 'POST',
    uri: Uri.parse(url),
    startTime: start,
    endTime: complete ? start.add(const Duration(milliseconds: 120)) : null,
    statusCode: statusCode,
    requestHeaders: {'Content-Type': contentType},
    requestBody: body is String ? body : jsonEncode(body),
    responseBody: response == null
        ? null
        : response is String
        ? response
        : jsonEncode(response),
    error: error,
  );
}

void main() {
  group('mightBeGraphQL', () {
    test('accepts JSON and GraphQL POST requests', () {
      expect(mightBeGraphQL(_post({})), isTrue);
      expect(
        mightBeGraphQL(_post('', contentType: 'application/graphql')),
        isTrue,
      );
    });

    test('rejects other content types and methods', () {
      expect(mightBeGraphQL(_post('', contentType: 'image/png')), isFalse);
      final put = HttpTransaction(
        id: '1',
        method: 'PUT',
        uri: Uri.parse('https://x.dev/graphql'),
        startTime: DateTime(2026),
      );
      expect(mightBeGraphQL(put), isFalse);
    });

    test('accepts GET requests with a query parameter only', () {
      HttpTransaction get(String url) => HttpTransaction(
        id: '1',
        method: 'GET',
        uri: Uri.parse(url),
        startTime: DateTime(2026),
      );
      expect(mightBeGraphQL(get('https://x.dev/graphql?query={a}')), isTrue);
      expect(mightBeGraphQL(get('https://x.dev/graphql')), isFalse);
    });
  });

  group('parseGraphQLOperations', () {
    test('reads a named query with variables and data', () {
      final operations = parseGraphQLOperations(
        _post(
          {
            'query': r'query GetUser($id: ID!) { user(id: $id) { id } }',
            'variables': {'id': '7'},
          },
          response: {
            'data': {
              'user': {'id': '7'},
            },
          },
        ),
      );

      final operation = operations.single;
      expect(operation.displayName, 'GetUser');
      expect(operation.type, GraphQLOperationType.query);
      expect(operation.variables, {'id': '7'});
      expect(operation.data, {
        'user': {'id': '7'},
      });
      expect(operation.status, GraphQLOperationStatus.success);
      expect(operation.duration, const Duration(milliseconds: 120));
    });

    test('ignores JSON requests without a query', () {
      expect(parseGraphQLOperations(_post({'name': 'x'})), isEmpty);
      expect(parseGraphQLOperations(_post('not json')), isEmpty);
    });

    test('uses operationName to pick the operation in the document', () {
      final operation = parseGraphQLOperations(
        _post({
          'query': 'query A { a } mutation B { b }',
          'operationName': 'B',
        }),
      ).single;

      expect(operation.displayName, 'B');
      expect(operation.type, GraphQLOperationType.mutation);
    });

    test('detects the type after leading fragments and comments', () {
      final operation = parseGraphQLOperations(
        _post({
          'query':
              '# comment\nfragment F on User { id }\n'
              'subscription OnUser { user { ...F } }',
        }),
      ).single;

      expect(operation.type, GraphQLOperationType.subscription);
      expect(operation.displayName, 'OnUser');
    });

    test('names anonymous operations by type', () {
      final operation = parseGraphQLOperations(
        _post({'query': '{ me { id } }'}),
      ).single;
      expect(operation.type, GraphQLOperationType.query);
      expect(operation.displayName, 'Anonymous query');
    });

    test('reads GraphQL errors and sets the error status', () {
      final operation = parseGraphQLOperations(
        _post(
          {'query': 'query Q { a }'},
          response: {
            'data': null,
            'errors': [
              {
                'message': 'Boom',
                'path': ['a', 0, 'b'],
                'locations': [
                  {'line': 1, 'column': 11},
                ],
                'extensions': {'code': 'INTERNAL'},
              },
            ],
          },
        ),
      ).single;

      expect(operation.status, GraphQLOperationStatus.graphQLError);
      final error = operation.errors.single;
      expect(error.message, 'Boom');
      expect(error.pathDisplay, 'a[0].b');
      expect(error.code, 'INTERNAL');
      expect(error.locations!.single.line, 1);
    });

    test('splits a batch and matches responses by index', () {
      final operations = parseGraphQLOperations(
        _post(
          [
            {'query': 'query One { a }'},
            {'query': 'query Two { b }'},
          ],
          response: [
            {
              'data': {'a': 1},
            },
            {
              'errors': [
                {'message': 'no b'},
              ],
            },
          ],
        ),
      );

      expect(operations.map((o) => o.displayName), ['One', 'Two']);
      expect(operations.map((o) => o.id), ['42#0', '42#1']);
      expect(operations.first.batchSize, 2);
      expect(operations.first.status, GraphQLOperationStatus.success);
      expect(operations.last.status, GraphQLOperationStatus.graphQLError);
    });

    test('reads automatic persisted queries without a document', () {
      final operation = parseGraphQLOperations(
        _post({
          'operationName': 'Feed',
          'extensions': {
            'persistedQuery': {'version': 1, 'sha256Hash': 'abcdef123456'},
          },
        }),
      ).single;

      expect(operation.isPersistedQuery, isTrue);
      expect(operation.document, isNull);
      expect(operation.displayName, 'Feed');
      expect(operation.type, GraphQLOperationType.unknown);
    });

    test('reads application/graphql bodies', () {
      final operation = parseGraphQLOperations(
        _post('mutation Save { save }', contentType: 'application/graphql'),
      ).single;
      expect(operation.type, GraphQLOperationType.mutation);
      expect(operation.displayName, 'Save');
    });

    test('reads GET requests', () {
      final transaction = HttpTransaction(
        id: '1',
        method: 'GET',
        uri: Uri.https('x.dev', '/graphql', {
          'query':
              r'query Country($code: ID!) { country(code: $code) { name } }',
          'variables': '{"code":"IN"}',
        }),
        startTime: DateTime(2026),
      );

      final operation = parseGraphQLOperations(transaction).single;
      expect(operation.displayName, 'Country');
      expect(operation.variables, {'code': 'IN'});
      expect(operation.status, GraphQLOperationStatus.pending);
    });

    test('reads multipart file uploads', () {
      const body =
          '--b\r\n'
          'Content-Disposition: form-data; name="operations"\r\n'
          '\r\n'
          '{"query":"mutation Upload(\$f: Upload!) { upload(file: \$f) }",'
          '"variables":{"f":null}}\r\n'
          '--b\r\n'
          'Content-Disposition: form-data; name="map"\r\n'
          '\r\n'
          '{"0":["variables.f"]}\r\n'
          '--b--\r\n';

      final operation = parseGraphQLOperations(
        _post(body, contentType: 'multipart/form-data; boundary=b'),
      ).single;
      expect(operation.displayName, 'Upload');
      expect(operation.type, GraphQLOperationType.mutation);
    });

    test('decodes variables that are sent as a JSON string', () {
      final operation = parseGraphQLOperations(
        _post({'query': 'query Q { a }', 'variables': '{"a":1}'}),
      ).single;
      expect(operation.variables, {'a': 1});
    });

    test('reports pending, failed and HTTP error states', () {
      final pending = parseGraphQLOperations(
        _post({'query': '{ a }'}, statusCode: null, complete: false),
      ).single;
      expect(pending.status, GraphQLOperationStatus.pending);
      expect(pending.duration, isNull);

      final failed = parseGraphQLOperations(
        _post({'query': '{ a }'}, statusCode: null, error: 'SocketException'),
      ).single;
      expect(failed.status, GraphQLOperationStatus.failed);

      final httpError = parseGraphQLOperations(
        _post({'query': '{ a }'}, statusCode: 502, response: 'Bad gateway'),
      ).single;
      expect(httpError.status, GraphQLOperationStatus.httpError);
      expect(httpError.response, isNull);
    });

    test('keeps failed requests to GraphQL URLs that have no body', () {
      final failed = HttpTransaction(
        id: '9',
        method: 'POST',
        uri: Uri.parse('https://down.example.com/graphql'),
        startTime: DateTime(2026),
        endTime: DateTime(2026),
        error: 'SocketException: Failed host lookup',
      );
      final operation = parseGraphQLOperations(failed).single;
      expect(operation.status, GraphQLOperationStatus.failed);
      expect(operation.displayName, 'Unknown operation');

      final rest = HttpTransaction(
        id: '10',
        method: 'POST',
        uri: Uri.parse('https://down.example.com/rest'),
        startTime: DateTime(2026),
        error: 'SocketException',
      );
      expect(parseGraphQLOperations(rest), isEmpty);
    });

    test('toRequestJson returns the standard request fields', () {
      final operation = parseGraphQLOperations(
        _post({
          'query': 'query Q { a }',
          'operationName': 'Q',
          'variables': {'x': 1},
        }),
      ).single;
      expect(operation.toRequestJson(), {
        'operationName': 'Q',
        'query': 'query Q { a }',
        'variables': {'x': 1},
      });
    });
  });
}
