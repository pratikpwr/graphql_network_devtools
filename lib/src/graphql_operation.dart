import 'dart:convert';

import 'http_transaction.dart';

/// The type of a GraphQL operation.
enum GraphQLOperationType {
  /// A `query` operation, including the `{ ... }` shorthand.
  query,

  /// A `mutation` operation.
  mutation,

  /// A `subscription` operation.
  subscription,

  /// The type is not known, for example for a persisted query.
  unknown;

  /// A display label, for example `Query`.
  String get label => switch (this) {
    query => 'Query',
    mutation => 'Mutation',
    subscription => 'Subscription',
    unknown => 'Unknown',
  };
}

/// The result state of a GraphQL operation.
enum GraphQLOperationStatus {
  /// The response is not complete yet.
  pending,

  /// The server sent a response without GraphQL errors and with a 2xx or
  /// 3xx status code.
  success,

  /// The response contains one or more GraphQL errors.
  graphQLError,

  /// The server sent a 4xx or 5xx status code without GraphQL errors.
  httpError,

  /// The request failed before a response arrived, for example because of
  /// a network error.
  failed,
}

/// One error from the `errors` list of a GraphQL response.
class GraphQLError {
  /// Creates a GraphQL error.
  const GraphQLError({
    required this.message,
    this.path,
    this.locations,
    this.extensions,
    this.raw,
  });

  /// Reads an error from one entry of a response `errors` list.
  ///
  /// Entries that are not JSON objects become an error with the entry text
  /// as the message.
  factory GraphQLError.fromJson(Object? json) {
    if (json is! Map) return GraphQLError(message: '$json', raw: json);
    final path = json['path'];
    final locations = json['locations'];
    final extensions = json['extensions'];
    return GraphQLError(
      message: '${json['message'] ?? 'Unknown error'}',
      path: path is List ? List<Object?>.unmodifiable(path) : null,
      locations: locations is List
          ? [
              for (final location in locations)
                if (location is Map)
                  (
                    line: (location['line'] as num?)?.toInt() ?? 0,
                    column: (location['column'] as num?)?.toInt() ?? 0,
                  ),
            ]
          : null,
      extensions: extensions is Map ? extensions.cast<String, Object?>() : null,
      raw: json,
    );
  }

  /// The error message.
  final String message;

  /// The response path of the field that failed, for example
  /// `['user', 'friends', 0, 'name']`.
  final List<Object?>? path;

  /// The locations in the document that caused the error.
  final List<({int line, int column})>? locations;

  /// The `extensions` map of the error, for example an error code.
  final Map<String, Object?>? extensions;

  /// The original JSON value of the error.
  final Object? raw;

  /// The [path] as text, for example `user.friends[0].name`.
  String? get pathDisplay {
    final segments = path;
    if (segments == null || segments.isEmpty) return null;
    final buffer = StringBuffer();
    for (final segment in segments) {
      if (segment is int) {
        buffer.write('[$segment]');
      } else {
        if (buffer.isNotEmpty) buffer.write('.');
        buffer.write(segment);
      }
    }
    return buffer.toString();
  }

  /// The `extensions.code` value, if the server sent one.
  String? get code => extensions?['code']?.toString();
}

/// A GraphQL operation that was sent over HTTP.
///
/// One [HttpTransaction] holds one operation, or many operations if the
/// client sends a batch. Use [parseGraphQLOperations] to create operations.
class GraphQLOperation {
  /// Creates a GraphQL operation.
  const GraphQLOperation({
    required this.id,
    required this.transaction,
    required this.type,
    this.batchIndex = 0,
    this.batchSize = 1,
    this.name,
    this.operationName,
    this.document,
    this.persistedQueryHash,
    this.variables,
    this.extensions,
    this.response,
    this.errors = const [],
  });

  /// A unique ID. For a batch, the ID includes the index in the batch.
  final String id;

  /// The HTTP transaction that carried this operation.
  final HttpTransaction transaction;

  /// The operation type.
  final GraphQLOperationType type;

  /// The index of this operation in its batch. It is 0 if there is no batch.
  final int batchIndex;

  /// The number of operations in the batch. It is 1 if there is no batch.
  final int batchSize;

  /// The operation name from the document, or from [operationName].
  final String? name;

  /// The `operationName` field that the client sent, if any.
  final String? operationName;

  /// The GraphQL document text, or `null` for a persisted query that the
  /// client sent as a hash only.
  final String? document;

  /// The SHA-256 hash of an automatic persisted query, if any.
  final String? persistedQueryHash;

  /// The variables that the client sent, usually a JSON object.
  final Object? variables;

  /// The `extensions` field of the request, if any.
  final Map<String, Object?>? extensions;

  /// The decoded JSON response for this operation, if it is valid JSON.
  final Object? response;

  /// The GraphQL errors in the response.
  final List<GraphQLError> errors;

  /// Whether the client sent this operation in a batch.
  bool get isBatched => batchSize > 1;

  /// Whether the client sent a persisted query hash instead of a document.
  bool get isPersistedQuery => persistedQueryHash != null;

  /// The `data` field of the response, if any.
  Object? get data {
    final value = response;
    return value is Map ? value['data'] : null;
  }

  /// The `extensions` field of the response, if any.
  Object? get responseExtensions {
    final value = response;
    return value is Map ? value['extensions'] : null;
  }

  /// Whether the response contains GraphQL errors.
  bool get hasErrors => errors.isNotEmpty;

  /// The name to show for this operation.
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    final hash = persistedQueryHash;
    if (hash != null) {
      return 'Persisted ${hash.length > 8 ? hash.substring(0, 8) : hash}';
    }
    if (document == null) return 'Unknown operation';
    return 'Anonymous ${type == GraphQLOperationType.unknown ? 'operation' : type.name}';
  }

  /// The HTTP request URI.
  Uri get uri => transaction.uri;

  /// The HTTP method.
  String get method => transaction.method;

  /// The time when the request started.
  DateTime get startTime => transaction.startTime;

  /// The HTTP status code, or `null` if no response arrived yet.
  int? get statusCode => transaction.statusCode;

  /// The time from the request start to the response end.
  Duration? get duration {
    final end = transaction.endTime;
    return end?.difference(transaction.startTime);
  }

  /// The result state of this operation.
  GraphQLOperationStatus get status {
    if (transaction.error != null) return GraphQLOperationStatus.failed;
    if (!transaction.isComplete || transaction.statusCode == null) {
      return GraphQLOperationStatus.pending;
    }
    if (hasErrors) return GraphQLOperationStatus.graphQLError;
    if (transaction.statusCode! >= 400) return GraphQLOperationStatus.httpError;
    return GraphQLOperationStatus.success;
  }

  /// The size of the response body in bytes, or `null` if there is no body.
  int? get responseSize {
    final body = transaction.responseBody;
    return body == null ? null : utf8.encode(body).length;
  }

  /// The GraphQL request of this operation as a JSON object.
  ///
  /// The object has the standard `query`, `operationName`, `variables`
  /// and `extensions` fields. Fields without a value are left out.
  Map<String, Object?> toRequestJson() => {
    if (operationName != null) 'operationName': operationName,
    if (document != null) 'query': document,
    if (variables != null) 'variables': variables,
    if (extensions != null) 'extensions': extensions,
  };

  @override
  String toString() =>
      'GraphQLOperation($displayName, ${type.name}, ${status.name})';
}
