/// Represents a parsed GraphQL operation extracted from an HTTP request.
class GraphQLOperation {
  final String id;
  final String? operationName;
  final String query;
  final Map<String, dynamic>? variables;
  final GraphQLOperationType type;
  final int? statusCode;
  final Duration? duration;
  final DateTime timestamp;
  final String uri;
  final Map<String, dynamic>? responseData;
  final List<Map<String, dynamic>>? errors;
  final String? rawRequestBody;
  final String? rawResponseBody;
  final Map<String, String>? requestHeaders;
  final Map<String, String>? responseHeaders;

  GraphQLOperation({
    required this.id,
    this.operationName,
    required this.query,
    this.variables,
    required this.type,
    this.statusCode,
    this.duration,
    required this.timestamp,
    required this.uri,
    this.responseData,
    this.errors,
    this.rawRequestBody,
    this.rawResponseBody,
    this.requestHeaders,
    this.responseHeaders,
  });

  /// Display name for the operation (operation name or first line of query)
  String get displayName {
    if (operationName != null && operationName!.isNotEmpty) {
      return operationName!;
    }
    // Extract operation name from query if not provided
    final match = RegExp(r'(query|mutation|subscription)\s+(\w+)').firstMatch(query);
    if (match != null) {
      return match.group(2) ?? 'Anonymous';
    }
    return 'Anonymous ${type.name}';
  }

  /// Whether the operation completed successfully
  bool get isSuccess => statusCode != null && statusCode! >= 200 && statusCode! < 300 && (errors == null || errors!.isEmpty);

  /// Whether the operation has errors
  bool get hasErrors => errors != null && errors!.isNotEmpty;

  /// Status display string
  String get statusDisplay {
    if (statusCode == null) return 'Pending';
    if (hasErrors) return '$statusCode (errors)';
    return statusCode.toString();
  }

  /// Duration display string
  String get durationDisplay {
    if (duration == null) return '-';
    if (duration!.inMilliseconds < 1000) {
      return '${duration!.inMilliseconds} ms';
    }
    return '${(duration!.inMilliseconds / 1000).toStringAsFixed(2)} s';
  }

  @override
  String toString() => 'GraphQLOperation($displayName, $type, $statusDisplay)';
}

/// The type of GraphQL operation
enum GraphQLOperationType {
  query,
  mutation,
  subscription,
  unknown;

  /// Parse operation type from query string
  static GraphQLOperationType fromQuery(String query) {
    final trimmed = query.trimLeft().toLowerCase();
    if (trimmed.startsWith('mutation')) return GraphQLOperationType.mutation;
    if (trimmed.startsWith('subscription')) return GraphQLOperationType.subscription;
    if (trimmed.startsWith('query') || trimmed.startsWith('{')) return GraphQLOperationType.query;
    return GraphQLOperationType.unknown;
  }
}

