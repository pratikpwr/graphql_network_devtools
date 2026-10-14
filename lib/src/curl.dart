import 'http_transaction.dart';

/// Headers that `curl` computes itself, so the command leaves them out.
const _skippedHeaders = {'content-length', 'host'};

/// Builds a `curl` command that repeats [transaction].
///
/// The command uses POSIX shell quoting, so it works in bash and zsh. The
/// command includes all request headers, also `authorization` and
/// `cookie` headers, so treat the result as a secret.
String toCurlCommand(HttpTransaction transaction) {
  final lines = <String>['curl ${_quote(transaction.uri.toString())}'];
  final method = transaction.method.toUpperCase();
  final body = transaction.requestBody;

  if (method != 'GET' || body != null) lines.add('-X $method');

  final names = transaction.requestHeaders.keys.toList()..sort();
  for (final name in names) {
    if (_skippedHeaders.contains(name.toLowerCase())) continue;
    lines.add('-H ${_quote('$name: ${transaction.requestHeaders[name]}')}');
  }

  if (body != null && body.isNotEmpty) lines.add('--data-raw ${_quote(body)}');

  return lines.join(' \\\n  ');
}

String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";
