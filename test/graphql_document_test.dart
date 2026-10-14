import 'package:graphql_network_devtools/graphql_network_devtools.dart';
import 'package:test/test.dart';

void main() {
  group('formatGraphQL', () {
    test('formats a minified document', () {
      const input =
          r'query GetUser($id: ID!, $n: Int = 5) { user(id: $id) '
          r'{ id name ...F friends(first: 10, where: {a: 1, b: [1,2]}) '
          r'@include(if: $x) { edges { node { id } } } } } '
          'fragment F on User { email ... on Admin { level } }';

      expect(formatGraphQL(input), r'''
query GetUser($id: ID!, $n: Int = 5) {
  user(id: $id) {
    id
    name
    ...F
    friends(first: 10, where: {a: 1, b: [1, 2]}) @include(if: $x) {
      edges {
        node {
          id
        }
      }
    }
  }
}

fragment F on User {
  email
  ... on Admin {
    level
  }
}''');
    });

    test('keeps aliases, directives and comments', () {
      const input = '{ # top\n me: viewer @cached { id } }';
      expect(formatGraphQL(input), '''
{
  # top
  me: viewer @cached {
    id
  }
}''');
    });

    test('formats an already formatted document the same way', () {
      const input =
          'mutation Save(\$input: SaveInput!) {\n'
          '  save(input: \$input) {\n'
          '    ok\n'
          '  }\n'
          '}';
      expect(formatGraphQL(input), input);
      expect(formatGraphQL(formatGraphQL(input)), input);
    });

    test('returns invalid input without changes', () {
      expect(formatGraphQL('  not % graphql  '), 'not % graphql');
    });

    test('keeps strings that contain braces', () {
      expect(
        formatGraphQL('{ search(text: "a { b }") { id } }'),
        '{\n  search(text: "a { b }") {\n    id\n  }\n}',
      );
    });
  });

  group('tokenizeGraphQL', () {
    test('splits variables, directives, strings and numbers', () {
      final tokens = tokenizeGraphQL(
        r'query Q($a: Float = -1.5e3) @live { f(s: """x""") }',
      );
      expect(
        tokens.map((t) => t.kind).toSet(),
        containsAll([
          GraphQLTokenKind.name,
          GraphQLTokenKind.variable,
          GraphQLTokenKind.number,
          GraphQLTokenKind.directive,
          GraphQLTokenKind.string,
          GraphQLTokenKind.punctuator,
        ]),
      );
      expect(
        tokens.firstWhere((t) => t.kind == GraphQLTokenKind.number).text,
        '-1.5e3',
      );
    });

    test('keeps token offsets', () {
      const source = 'query  Q';
      final tokens = tokenizeGraphQL(source);
      expect(tokens.last.offset, 7);
      expect(source.substring(tokens.last.offset), 'Q');
    });
  });

  group('listOperations', () {
    test('lists every operation and skips fragments', () {
      final operations = listOperations(
        'fragment F on A { a } query One { ...F } mutation { b } { c }',
      );
      expect(operations.map((o) => o.type), [
        GraphQLOperationType.query,
        GraphQLOperationType.mutation,
        GraphQLOperationType.query,
      ]);
      expect(operations.map((o) => o.name), ['One', null, null]);
    });
  });
}
