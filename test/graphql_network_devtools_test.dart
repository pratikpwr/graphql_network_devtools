import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_network_devtools/src/models/graphql_operation.dart';

void main() {
  group('GraphQLOperationType', () {
    test('fromQuery parses query correctly', () {
      expect(
        GraphQLOperationType.fromQuery('query GetUser { user { id } }'),
        GraphQLOperationType.query,
      );
    });

    test('fromQuery parses mutation correctly', () {
      expect(
        GraphQLOperationType.fromQuery('mutation CreateUser { createUser { id } }'),
        GraphQLOperationType.mutation,
      );
    });

    test('fromQuery parses subscription correctly', () {
      expect(
        GraphQLOperationType.fromQuery('subscription OnUserCreated { userCreated { id } }'),
        GraphQLOperationType.subscription,
      );
    });

    test('fromQuery handles shorthand query', () {
      expect(
        GraphQLOperationType.fromQuery('{ user { id } }'),
        GraphQLOperationType.query,
      );
    });
  });

  group('GraphQLOperation', () {
    test('displayName returns operationName when provided', () {
      final operation = GraphQLOperation(
        id: '1',
        operationName: 'GetUser',
        query: 'query GetUser { user { id } }',
        type: GraphQLOperationType.query,
        timestamp: DateTime.now(),
        uri: 'http://localhost/graphql',
      );

      expect(operation.displayName, 'GetUser');
    });

    test('displayName extracts from query when operationName is null', () {
      final operation = GraphQLOperation(
        id: '1',
        query: 'query FetchData { data { id } }',
        type: GraphQLOperationType.query,
        timestamp: DateTime.now(),
        uri: 'http://localhost/graphql',
      );

      expect(operation.displayName, 'FetchData');
    });

    test('isSuccess returns true for 200 status with no errors', () {
      final operation = GraphQLOperation(
        id: '1',
        query: 'query GetUser { user { id } }',
        type: GraphQLOperationType.query,
        statusCode: 200,
        timestamp: DateTime.now(),
        uri: 'http://localhost/graphql',
      );

      expect(operation.isSuccess, true);
    });

    test('hasErrors returns true when errors present', () {
      final operation = GraphQLOperation(
        id: '1',
        query: 'query GetUser { user { id } }',
        type: GraphQLOperationType.query,
        statusCode: 200,
        errors: [{'message': 'Error'}],
        timestamp: DateTime.now(),
        uri: 'http://localhost/graphql',
      );

      expect(operation.hasErrors, true);
      expect(operation.isSuccess, false);
    });
  });
}
