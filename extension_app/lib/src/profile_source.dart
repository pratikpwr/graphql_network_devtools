import 'dart:convert';
import 'dart:typed_data';

import 'package:devtools_app_shared/service.dart';
import 'package:graphql_network_devtools/graphql_network_devtools.dart';
import 'package:vm_service/vm_service.dart';

/// One request in an HTTP profile, without bodies.
typedef ProfileEntry = ({String requestId, HttpTransaction summary});

/// The requests that changed in one isolate since the last poll.
class ProfileSnapshot {
  const ProfileSnapshot(this.timestamp, this.entries);

  /// The VM time of the snapshot. Pass it as `updatedSince` to the next poll.
  final DateTime timestamp;

  final List<ProfileEntry> entries;
}

/// Reads HTTP traffic from the connected app.
///
/// The extension uses [VmServiceProfileSource]. Tests use a fake.
abstract interface class HttpProfileSource {
  /// The IDs of the isolates that can have HTTP traffic.
  Future<List<String>> isolateIds();

  /// Turns on HTTP timeline logging in [isolateId].
  ///
  /// The VM records HTTP traffic only while logging is on.
  Future<void> enableLogging(String isolateId);

  /// Returns the requests that changed since [updatedSince].
  Future<ProfileSnapshot> fetchProfile(
    String isolateId, {
    DateTime? updatedSince,
  });

  /// Returns one request with its request and response bodies.
  Future<HttpTransaction> fetchRequest(String isolateId, String requestId);

  /// Deletes all recorded requests in [isolateId].
  Future<void> clear(String isolateId);
}

/// Reads HTTP traffic through the Dart VM service `ext.dart.io` extensions.
class VmServiceProfileSource implements HttpProfileSource {
  VmServiceProfileSource(this._serviceManager);

  final ServiceManager _serviceManager;

  VmService get _service {
    final service = _serviceManager.service;
    if (service == null) throw StateError('Not connected to an app.');
    return service;
  }

  @override
  Future<List<String>> isolateIds() async {
    final vm = await _service.getVM();
    return [
      for (final isolate in vm.isolates ?? const <IsolateRef>[])
        if (isolate.id != null) isolate.id!,
    ];
  }

  @override
  Future<void> enableLogging(String isolateId) async {
    if (!await _service.isHttpTimelineLoggingAvailable(isolateId)) return;
    await _service.httpEnableTimelineLogging(isolateId, true);
  }

  @override
  Future<ProfileSnapshot> fetchProfile(
    String isolateId, {
    DateTime? updatedSince,
  }) async {
    final profile = await _service.getHttpProfile(
      isolateId,
      updatedSince: updatedSince,
    );
    return ProfileSnapshot(profile.timestamp, [
      for (final request in profile.requests)
        (requestId: request.id, summary: _toTransaction(isolateId, request)),
    ]);
  }

  @override
  Future<HttpTransaction> fetchRequest(
    String isolateId,
    String requestId,
  ) async {
    final request = await _service.getHttpProfileRequest(isolateId, requestId);
    return _toTransaction(
      isolateId,
      request,
      requestBody: request.requestBody,
      responseBody: request.responseBody,
    );
  }

  @override
  Future<void> clear(String isolateId) async {
    await _service.clearHttpProfile(isolateId);
  }
}

/// The key that identifies a request across isolates.
String transactionKey(String isolateId, String requestId) =>
    '$isolateId::$requestId';

HttpTransaction _toTransaction(
  String isolateId,
  HttpProfileRequestRef ref, {
  Uint8List? requestBody,
  Uint8List? responseBody,
}) {
  final request = ref.request;
  final response = ref.response;
  final requestError = request != null && request.hasError
      ? request.error
      : null;
  final error = requestError ?? response?.error;

  return HttpTransaction(
    id: transactionKey(isolateId, ref.id),
    method: ref.method,
    uri: ref.uri,
    startTime: ref.startTime,
    endTime: response?.endTime ?? (error != null ? ref.endTime : null),
    statusCode: response?.statusCode,
    reasonPhrase: response?.reasonPhrase,
    requestHeaders: request == null || request.hasError
        ? const {}
        : _headers(request.headers),
    responseHeaders: _headers(response?.headers),
    requestBody: _decode(requestBody),
    responseBody: _decode(responseBody),
    error: error,
  );
}

Map<String, String> _headers(Map<String, dynamic>? headers) {
  if (headers == null) return const {};
  return {
    for (final entry in headers.entries)
      entry.key: entry.value is List
          ? (entry.value as List).join(', ')
          : '${entry.value}',
  };
}

String? _decode(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  return utf8.decode(bytes, allowMalformed: true);
}
