/// A plain, transport-neutral record of one HTTP request and its response.
///
/// The DevTools extension creates these from the Dart VM HTTP profile.
/// [GraphQLRequestParser] reads them to find GraphQL operations.
class HttpTransaction {
  /// Creates an HTTP transaction record.
  const HttpTransaction({
    required this.id,
    required this.method,
    required this.uri,
    required this.startTime,
    this.endTime,
    this.statusCode,
    this.reasonPhrase,
    this.requestHeaders = const {},
    this.responseHeaders = const {},
    this.requestBody,
    this.responseBody,
    this.error,
  });

  /// A unique ID for this transaction.
  final String id;

  /// The HTTP method, for example `POST` or `GET`.
  final String method;

  /// The request URI.
  final Uri uri;

  /// The time when the request started.
  final DateTime startTime;

  /// The time when the response completed, or `null` while it is in progress.
  final DateTime? endTime;

  /// The HTTP status code, or `null` if no response arrived yet.
  final int? statusCode;

  /// The HTTP reason phrase, for example `OK`.
  final String? reasonPhrase;

  /// The request headers. Names are as sent by the client.
  final Map<String, String> requestHeaders;

  /// The response headers. Names are as sent by the server.
  final Map<String, String> responseHeaders;

  /// The decoded request body, or `null` if it is not available.
  final String? requestBody;

  /// The decoded response body, or `null` if it is not available.
  final String? responseBody;

  /// A transport error, for example a socket or TLS failure.
  final String? error;

  /// Whether the transaction finished, with a response or with an error.
  bool get isComplete => endTime != null || error != null;

  /// The value of the request `content-type` header, in lower case.
  String? get requestContentType => _header(requestHeaders, 'content-type');

  static String? _header(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value.toLowerCase();
    }
    return null;
  }
}
