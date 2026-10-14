import 'dart:convert';

import 'package:http/http.dart' as http;

/// The result of one GraphQL request.
class GraphQLResult {
  const GraphQLResult({
    required this.statusCode,
    required this.body,
    required this.duration,
  });

  final int statusCode;
  final Object? body;
  final Duration duration;

  /// Whether the response has a non-empty `errors` list.
  bool get hasErrors {
    final value = body;
    return value is Map &&
        value['errors'] is List &&
        (value['errors'] as List).isNotEmpty;
  }
}

/// A very small GraphQL client on top of `package:http`.
///
/// Any client works with GraphQL Network DevTools, for example
/// `graphql_flutter`, `ferry`, `dio` or `artemis`. The extension reads the
/// Dart VM HTTP profile, so it does not need a special client.
class GraphQLClient {
  GraphQLClient(this.endpoint, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final Uri endpoint;
  final http.Client _http;

  /// Sends [document] as a JSON `POST` request.
  Future<GraphQLResult> post(
    String document, {
    String? operationName,
    Map<String, Object?>? variables,
    Map<String, String> headers = const {},
  }) {
    return _send(
      () => _http.post(
        endpoint,
        headers: {'content-type': 'application/json', ...headers},
        body: jsonEncode({
          'query': document,
          'operationName': ?operationName,
          'variables': ?variables,
        }),
      ),
    );
  }

  /// Sends [document] as a `GET` request with query parameters.
  Future<GraphQLResult> get(
    String document, {
    Map<String, Object?>? variables,
  }) {
    final uri = endpoint.replace(
      queryParameters: {
        'query': document,
        if (variables != null) 'variables': jsonEncode(variables),
      },
    );
    return _send(() => _http.get(uri));
  }

  /// Sends many operations in one request, as a JSON list.
  Future<GraphQLResult> batch(List<Map<String, Object?>> operations) {
    return _send(
      () => _http.post(
        endpoint,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(operations),
      ),
    );
  }

  Future<GraphQLResult> _send(Future<http.Response> Function() request) async {
    final stopwatch = Stopwatch()..start();
    final response = await request();
    Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      body = response.body;
    }
    return GraphQLResult(
      statusCode: response.statusCode,
      body: body,
      duration: stopwatch.elapsed,
    );
  }
}
