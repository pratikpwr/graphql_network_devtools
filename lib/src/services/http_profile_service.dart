import 'dart:convert';

import '../models/graphql_operation.dart';

/// Service to fetch HTTP profile data from the VM service.
///
/// This accesses the same data that the Network inspector uses,
/// filtering for GraphQL requests.
///
/// Note: HTTP timeline logging is enabled by the GraphQL extension using
/// [ServiceExtensionManager], not by this service. This ensures proper
/// handling of isolate lifecycle and state persistence.
class HttpProfileService {
  final dynamic serviceManager;

  HttpProfileService(this.serviceManager);

  /// Fetches all HTTP requests and filters for GraphQL operations.
  Future<List<GraphQLOperation>> getGraphQLOperations() async {
    try {
      final vmService = serviceManager.service;
      if (vmService == null) return [];

      // Get the main isolate ID
      final vm = await vmService.getVM();
      final isolates = vm.isolates ?? [];
      if (isolates.isEmpty) return [];

      // Try each isolate to find HTTP profile data
      final allOperations = <GraphQLOperation>[];

      for (final isolateRef in isolates) {
        try {
          final response = await vmService.callServiceExtension(
            'ext.dart.io.getHttpProfile',
            isolateId: isolateRef.id,
            args: {'updatedSince': 0},
          );

          if (response.json == null) continue;

          final requests = _parseHttpProfileList(response.json!);

          // Filter for GraphQL requests
          final graphqlCandidates = requests.where(_isLikelyGraphQL).toList();

          // Fetch full details for each GraphQL candidate
          for (final candidate in graphqlCandidates) {
            final requestId = candidate['id']?.toString();
            if (requestId == null) continue;

            final fullRequest = await _fetchFullRequestDetails(
              vmService,
              isolateRef.id!,
              requestId,
            );

            if (fullRequest != null) {
              final operation = _parseGraphQLRequest(fullRequest);
              if (operation != null) {
                allOperations.add(operation);
              }
            }
          }
        } catch (e) {
          // Continue with next isolate
        }
      }

      // Sort by timestamp, newest first
      allOperations.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allOperations;
    } catch (e) {
      return [];
    }
  }

  /// Check if a request is likely a GraphQL request.
  /// More flexible than just checking URL.
  bool _isLikelyGraphQL(Map<String, dynamic> request) {
    final uri = request['uri']?.toString().toLowerCase() ?? '';
    final method = request['method']?.toString().toUpperCase() ?? '';

    // Must be POST
    if (method != 'POST') return false;

    // Check URL patterns
    if (uri.contains('graphql')) return true;
    if (uri.contains('/gql')) return true;
    if (uri.contains('/query')) return true;
    if (uri.contains('/api/graph')) return true;

    // Check content type
    final contentType = request['contentType']?.toString().toLowerCase() ?? '';
    if (contentType.contains('application/graphql')) return true;

    // Check if it's a JSON POST to common API endpoints
    if (contentType.contains('application/json')) {
      // These are common GraphQL endpoint patterns
      if (uri.endsWith('/api') || uri.endsWith('/v1') || uri.endsWith('/v2')) {
        return true;
      }
    }

    return false;
  }

  /// Fetch full request details including request/response bodies.
  Future<Map<String, dynamic>?> _fetchFullRequestDetails(
    dynamic vmService,
    String isolateId,
    String requestId,
  ) async {
    try {
      final response = await vmService.callServiceExtension(
        'ext.dart.io.getHttpProfileRequest',
        isolateId: isolateId,
        args: {'id': requestId},
      );

      if (response.json != null) {
        return response.json as Map<String, dynamic>;
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  /// Parse the HTTP profile response into a list of request metadata
  List<Map<String, dynamic>> _parseHttpProfileList(Map<String, dynamic> json) {
    final requestsJson =
        json['requests'] as List<dynamic>? ??
        json['httpProfile']?['requests'] as List<dynamic>? ??
        [];

    return requestsJson.whereType<Map<String, dynamic>>().toList();
  }

  /// Parse an HTTP request into a GraphQL operation if applicable.
  GraphQLOperation? _parseGraphQLRequest(Map<String, dynamic> json) {
    final request = HttpRequest.fromJson(json);

    // Try to parse the request body as GraphQL
    final body = _parseRequestBody(request.requestBody);
    if (body == null) return null;

    // Must have a query field to be GraphQL
    final query = body['query'];
    if (query == null || query is! String || query.isEmpty) return null;

    // Parse response
    final responseData = _parseResponseBody(request.responseBody);

    return GraphQLOperation(
      id: request.id,
      operationName: body['operationName'] as String?,
      query: query,
      variables: body['variables'] as Map<String, dynamic>?,
      type: GraphQLOperationType.fromQuery(query),
      statusCode: request.statusCode,
      duration: request.duration,
      timestamp: request.timestamp,
      uri: request.uri,
      responseData: responseData?['data'] as Map<String, dynamic>?,
      errors: _parseErrors(responseData?['errors']),
      rawRequestBody: request.requestBody,
      rawResponseBody: request.responseBody,
      requestHeaders: request.requestHeaders,
      responseHeaders: request.responseHeaders,
    );
  }

  /// Parse the request body as JSON
  Map<String, dynamic>? _parseRequestBody(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (e) {
      // Not valid JSON
    }
    return null;
  }

  /// Parse the response body as JSON
  Map<String, dynamic>? _parseResponseBody(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (e) {
      // Not valid JSON
    }
    return null;
  }

  /// Parse GraphQL errors from response
  List<Map<String, dynamic>>? _parseErrors(dynamic errors) {
    if (errors == null) return null;
    if (errors is! List) return null;

    return errors.whereType<Map<String, dynamic>>().toList();
  }

  /// Clear the HTTP profile data
  Future<void> clearProfile() async {
    try {
      final vmService = serviceManager.service;
      if (vmService == null) return;

      final vm = await vmService.getVM();
      for (final isolateRef in vm.isolates ?? []) {
        try {
          await vmService.callServiceExtension(
            'ext.dart.io.clearHttpProfile',
            isolateId: isolateRef.id,
          );
        } catch (e) {
          // Ignore errors
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }
}

/// Representation of an HTTP request from the profile
class HttpRequest {
  final String id;
  final String method;
  final String uri;
  final int? statusCode;
  final int? startTime;
  final int? endTime;
  final String? requestBody;
  final String? responseBody;
  final Map<String, String>? requestHeaders;
  final Map<String, String>? responseHeaders;
  final String? contentType;

  HttpRequest({
    required this.id,
    required this.method,
    required this.uri,
    this.statusCode,
    this.startTime,
    this.endTime,
    this.requestBody,
    this.responseBody,
    this.requestHeaders,
    this.responseHeaders,
    this.contentType,
  });

  factory HttpRequest.fromJson(Map<String, dynamic> json) {
    // Parse headers from various possible formats
    Map<String, String>? parseHeaders(dynamic headers) {
      if (headers == null) return null;
      if (headers is Map) {
        final result = <String, String>{};
        headers.forEach((key, value) {
          if (value is List) {
            result[key.toString()] = value.join(', ');
          } else {
            result[key.toString()] = value.toString();
          }
        });
        return result;
      }
      return null;
    }

    // Extract body from various possible formats
    String? extractBody(dynamic body) {
      if (body == null) return null;
      if (body is String) return body;

      // Handle List of bytes directly
      if (body is List) {
        try {
          return utf8.decode(List<int>.from(body));
        } catch (e) {
          // Failed to decode
        }
      }

      if (body is Map) {
        // Try 'string' field first
        if (body['string'] != null) {
          return body['string'] as String;
        }
        // Try decoding bytes from 'bytes' field
        if (body['bytes'] != null) {
          try {
            return utf8.decode(List<int>.from(body['bytes']));
          } catch (e) {
            // Failed to decode
          }
        }
        // Try 'data' field (some formats use this)
        if (body['data'] != null) {
          return extractBody(body['data']);
        }
        // Try 'body' field
        if (body['body'] != null) {
          return extractBody(body['body']);
        }
      }
      return null;
    }

    // Get request body - try multiple possible locations
    String? getRequestBody() {
      // Direct requestBody field
      final directBody = extractBody(json['requestBody']);
      if (directBody != null) return directBody;

      // Nested in request object - try various keys
      final request = json['request'];
      if (request is Map) {
        final nestedBody = extractBody(request['requestBody']);
        if (nestedBody != null) return nestedBody;

        final body = extractBody(request['body']);
        if (body != null) return body;

        final data = extractBody(request['data']);
        if (data != null) return data;
      }

      return null;
    }

    // Get response body - try multiple possible locations
    String? getResponseBody() {
      // Direct responseBody field
      final directBody = extractBody(json['responseBody']);
      if (directBody != null) return directBody;

      // Nested in response object - try various keys
      final response = json['response'];
      if (response is Map) {
        final nestedBody = extractBody(response['responseBody']);
        if (nestedBody != null) return nestedBody;

        final body = extractBody(response['body']);
        if (body != null) return body;

        final data = extractBody(response['data']);
        if (data != null) return data;
      }

      return null;
    }

    return HttpRequest(
      id: json['id']?.toString() ?? json['isolateId']?.toString() ?? '',
      method:
          json['method']?.toString() ??
          json['request']?['method']?.toString() ??
          'GET',
      uri: json['uri']?.toString() ?? json['request']?['uri']?.toString() ?? '',
      statusCode:
          json['statusCode'] as int? ?? json['response']?['statusCode'] as int?,
      startTime:
          json['startTime'] as int? ?? json['requestStartTimestamp'] as int?,
      endTime: json['endTime'] as int? ?? json['responseEndTimestamp'] as int?,
      requestBody: getRequestBody(),
      responseBody: getResponseBody(),
      requestHeaders: parseHeaders(
        json['requestHeaders'] ?? json['request']?['headers'],
      ),
      responseHeaders: parseHeaders(
        json['responseHeaders'] ?? json['response']?['headers'],
      ),
      contentType: json['contentType']?.toString(),
    );
  }

  Duration? get duration {
    if (startTime == null || endTime == null) return null;
    return Duration(microseconds: endTime! - startTime!);
  }

  DateTime get timestamp {
    if (startTime != null) {
      return DateTime.fromMicrosecondsSinceEpoch(startTime!);
    }
    return DateTime.now();
  }
}
