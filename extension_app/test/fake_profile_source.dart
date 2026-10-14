import 'dart:convert';

import 'package:graphql_network_devtools/graphql_network_devtools.dart';
import 'package:graphql_network_devtools_extension/src/profile_source.dart';

const isolateId = 'isolates/1';

/// An in-memory [HttpProfileSource] that acts like the VM HTTP profile.
class FakeProfileSource implements HttpProfileSource {
  final _requests = <String, HttpTransaction>{};
  final _updatedAt = <String, int>{};
  final enabledIsolates = <String>[];
  final fetchedRequests = <String>[];
  int _clock = 0;

  /// Adds or replaces a request, as if the app sent or updated it.
  void put(String requestId, HttpTransaction transaction) {
    _requests[requestId] = transaction;
    _updatedAt[requestId] = ++_clock;
  }

  @override
  Future<List<String>> isolateIds() async => [isolateId];

  @override
  Future<void> enableLogging(String isolateId) async {
    enabledIsolates.add(isolateId);
  }

  @override
  Future<ProfileSnapshot> fetchProfile(
    String isolateId, {
    DateTime? updatedSince,
  }) async {
    final since = updatedSince?.microsecondsSinceEpoch ?? -1;
    return ProfileSnapshot(DateTime.fromMicrosecondsSinceEpoch(_clock), [
      for (final MapEntry(:key, :value) in _requests.entries)
        if (_updatedAt[key]! > since)
          (requestId: key, summary: _withoutBodies(value)),
    ]);
  }

  @override
  Future<HttpTransaction> fetchRequest(
    String isolateId,
    String requestId,
  ) async {
    fetchedRequests.add(requestId);
    return _requests[requestId]!;
  }

  @override
  Future<void> clear(String isolateId) async {
    _requests.clear();
  }

  HttpTransaction _withoutBodies(HttpTransaction t) => HttpTransaction(
    id: t.id,
    method: t.method,
    uri: t.uri,
    startTime: t.startTime,
    endTime: t.endTime,
    statusCode: t.statusCode,
    requestHeaders: t.requestHeaders,
    responseHeaders: t.responseHeaders,
    error: t.error,
  );
}

/// Builds a GraphQL POST transaction.
HttpTransaction graphQLRequest(
  String requestId, {
  required String query,
  Object? variables,
  Object? response = const {'data': <String, Object?>{}},
  int startSecond = 0,
  bool complete = true,
}) {
  final start = DateTime(2026, 1, 1, 12, 0, startSecond);
  return HttpTransaction(
    id: transactionKey(isolateId, requestId),
    method: 'POST',
    uri: Uri.parse('https://api.example.com/graphql'),
    startTime: start,
    endTime: complete ? start.add(const Duration(milliseconds: 85)) : null,
    statusCode: complete ? 200 : null,
    requestHeaders: const {'content-type': 'application/json'},
    responseHeaders: const {'content-type': 'application/json'},
    requestBody: jsonEncode({'query': query, 'variables': ?variables}),
    responseBody: complete ? jsonEncode(response) : null,
  );
}
