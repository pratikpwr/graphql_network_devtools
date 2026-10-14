import 'dart:convert';

import 'graphql_document.dart';
import 'graphql_operation.dart';
import 'http_transaction.dart';

/// Whether [transaction] can carry a GraphQL operation.
///
/// This is a fast check that uses only the method, the URI and the
/// request headers. It does not need the body. Use it to skip requests,
/// for example images, before you load their bodies. A `true` result does
/// not prove that the request is GraphQL. Use [parseGraphQLOperations] for
/// that.
bool mightBeGraphQL(HttpTransaction transaction) {
  final method = transaction.method.toUpperCase();
  if (method == 'GET') {
    final parameters = transaction.uri.queryParameters;
    return parameters.containsKey('query') ||
        parameters.containsKey('extensions');
  }
  if (method != 'POST') return false;

  final contentType = transaction.requestContentType;
  if (contentType == null) return true;
  return contentType.contains('json') ||
      contentType.contains('graphql') ||
      contentType.contains('multipart/form-data') ||
      contentType.contains('text/plain');
}

/// Reads the GraphQL operations that [transaction] carries.
///
/// The parser supports these request formats:
///
/// * A JSON `POST` body with a `query` field.
/// * A JSON `POST` body that is a list of operations (a batch).
/// * A `POST` body with the `application/graphql` content type.
/// * A `GET` request with `query`, `variables` and `operationName` query
///   parameters.
/// * Automatic persisted queries, where `extensions.persistedQuery` holds a
///   hash and the `query` field is not sent.
/// * File uploads that follow the GraphQL multipart request specification.
///
/// A `POST` request that failed before its body was recorded is returned as
/// one operation of unknown type, if its URL path contains `graphql` or
/// `gql`.
///
/// It returns an empty list if the transaction is not a GraphQL request.
List<GraphQLOperation> parseGraphQLOperations(HttpTransaction transaction) {
  if (_isFailedWithoutBody(transaction)) {
    // The request failed before the VM recorded its body, for example
    // because the host lookup failed. Keep it, so that the failure shows.
    return [
      GraphQLOperation(
        id: transaction.id,
        transaction: transaction,
        type: GraphQLOperationType.unknown,
      ),
    ];
  }

  final payloads = _requestPayloads(transaction);
  if (payloads == null) return const [];

  final valid = <Map<String, Object?>>[
    for (final payload in payloads)
      if (_isGraphQLPayload(payload)) payload,
  ];
  if (valid.isEmpty) return const [];

  final isBatch = payloads.length > 1;
  final decodedResponse = _tryDecodeJson(transaction.responseBody);

  return [
    for (var i = 0; i < valid.length; i++)
      _buildOperation(
        transaction: transaction,
        payload: valid[i],
        index: i,
        batchSize: isBatch ? valid.length : 1,
        response: _responseFor(decodedResponse, i, isBatch),
      ),
  ];
}

GraphQLOperation _buildOperation({
  required HttpTransaction transaction,
  required Map<String, Object?> payload,
  required int index,
  required int batchSize,
  required Object? response,
}) {
  final document = payload['query'] is String
      ? payload['query'] as String
      : null;
  final operationName = payload['operationName'] is String
      ? payload['operationName'] as String
      : null;
  final extensions = payload['extensions'] is Map
      ? (payload['extensions'] as Map).cast<String, Object?>()
      : null;
  final persistedQuery = extensions?['persistedQuery'];
  final hash = persistedQuery is Map ? persistedQuery['sha256Hash'] : null;

  final signature = document != null && document.isNotEmpty
      ? findOperation(document, operationName: operationName)
      : const GraphQLOperationSignature(GraphQLOperationType.unknown, null);

  var variables = payload['variables'];
  if (variables is String) variables = _tryDecodeJson(variables) ?? variables;

  final errors = response is Map && response['errors'] is List
      ? [
          for (final error in response['errors'] as List)
            GraphQLError.fromJson(error),
        ]
      : const <GraphQLError>[];

  return GraphQLOperation(
    id: batchSize > 1 ? '${transaction.id}#$index' : transaction.id,
    transaction: transaction,
    type: signature.type,
    batchIndex: index,
    batchSize: batchSize,
    name: operationName ?? signature.name,
    operationName: operationName,
    document: document,
    persistedQueryHash: hash is String ? hash : null,
    variables: variables,
    extensions: extensions,
    response: response,
    errors: errors,
  );
}

bool _isFailedWithoutBody(HttpTransaction transaction) {
  if (transaction.error == null) return false;
  if (transaction.method.toUpperCase() != 'POST') return false;
  final body = transaction.requestBody;
  if (body != null && body.isNotEmpty) return false;
  final path = transaction.uri.path.toLowerCase();
  return path.contains('graphql') || path.contains('gql');
}

bool _isGraphQLPayload(Map<String, Object?> payload) {
  final query = payload['query'];
  if (query is String && query.trim().isNotEmpty) return true;
  final extensions = payload['extensions'];
  return extensions is Map && extensions['persistedQuery'] is Map;
}

List<Map<String, Object?>>? _requestPayloads(HttpTransaction transaction) {
  final parameters = transaction.uri.queryParameters;
  if (transaction.method.toUpperCase() == 'GET') {
    if (!parameters.containsKey('query') &&
        !parameters.containsKey('extensions')) {
      return null;
    }
    return [
      {
        if (parameters['query'] != null) 'query': parameters['query'],
        if (parameters['operationName'] != null)
          'operationName': parameters['operationName'],
        if (parameters['variables'] != null)
          'variables':
              _tryDecodeJson(parameters['variables']) ??
              parameters['variables'],
        if (parameters['extensions'] != null)
          'extensions': _tryDecodeJson(parameters['extensions']),
      },
    ];
  }

  final body = transaction.requestBody;
  if (body == null || body.trim().isEmpty) return null;
  final contentType = transaction.requestContentType ?? '';

  if (contentType.contains('application/graphql')) {
    return [
      {'query': body},
    ];
  }

  final json = contentType.contains('multipart/form-data')
      ? _tryDecodeJson(_multipartField(body, 'operations'))
      : _tryDecodeJson(body);

  if (json is Map) return [json.cast<String, Object?>()];
  if (json is List) {
    return [
      for (final item in json)
        if (item is Map) item.cast<String, Object?>(),
    ];
  }
  return null;
}

Object? _responseFor(Object? decoded, int index, bool isBatch) {
  if (!isBatch) return decoded;
  if (decoded is List) return index < decoded.length ? decoded[index] : null;
  // A server that rejects a whole batch often sends one error object.
  return decoded;
}

/// Returns the value of the form field [name] in a multipart [body].
String? _multipartField(String body, String name) {
  final match = RegExp(
    'name="${RegExp.escape(name)}"[^\\r\\n]*\\r?\\n(?:[^\\r\\n]+\\r?\\n)*\\r?\\n',
  ).firstMatch(body);
  if (match == null) return null;
  final rest = body.substring(match.end);
  final end = rest.indexOf(RegExp(r'\r?\n--'));
  return end == -1 ? rest : rest.substring(0, end);
}

Object? _tryDecodeJson(String? text) {
  if (text == null || text.isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
