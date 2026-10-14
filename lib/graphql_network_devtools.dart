/// GraphQL Network DevTools.
///
/// This package adds a **GraphQL** tab to Flutter DevTools. Add it to
/// `dev_dependencies`, run your app in debug mode, and open DevTools. You
/// do not need to change your app code.
///
/// The library also exposes the pure Dart parser that the DevTools tab
/// uses. You can use it to read GraphQL operations from any HTTP log:
///
/// ```dart
/// final operations = parseGraphQLOperations(
///   HttpTransaction(
///     id: '1',
///     method: 'POST',
///     uri: Uri.parse('https://api.example.com/graphql'),
///     startTime: DateTime.now(),
///     requestHeaders: {'content-type': 'application/json'},
///     requestBody: '{"query": "query GetUser { user { id } }"}',
///   ),
/// );
/// print(operations.single.displayName); // GetUser
/// ```
library;

export 'src/curl.dart' show toCurlCommand;
export 'src/graphql_document.dart'
    show
        GraphQLOperationSignature,
        findOperation,
        formatGraphQL,
        listOperations;
export 'src/graphql_lexer.dart'
    show GraphQLToken, GraphQLTokenKind, tokenizeGraphQL;
export 'src/graphql_operation.dart'
    show
        GraphQLError,
        GraphQLOperation,
        GraphQLOperationStatus,
        GraphQLOperationType;
export 'src/graphql_request_parser.dart'
    show mightBeGraphQL, parseGraphQLOperations;
export 'src/http_transaction.dart' show HttpTransaction;
