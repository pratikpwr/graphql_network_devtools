import 'package:graphql_network_devtools/graphql_network_devtools.dart';
import 'package:test/test.dart';

void main() {
  test('toCurlCommand quotes the body and skips computed headers', () {
    final command = toCurlCommand(
      HttpTransaction(
        id: '1',
        method: 'POST',
        uri: Uri.parse('https://api.example.com/graphql'),
        startTime: DateTime(2026),
        requestHeaders: {
          'content-type': 'application/json',
          'content-length': '42',
          'authorization': 'Bearer t',
        },
        requestBody: '{"query":"{ user(name: \\"O\'Neil\\") { id } }"}',
      ),
    );

    expect(
      command,
      "curl 'https://api.example.com/graphql' \\\n"
      '  -X POST \\\n'
      "  -H 'authorization: Bearer t' \\\n"
      "  -H 'content-type: application/json' \\\n"
      '  --data-raw \'{"query":"{ user(name: \\"O\'\\\'\'Neil\\") { id } }"}\'',
    );
  });

  test('toCurlCommand leaves out -X for GET requests', () {
    final command = toCurlCommand(
      HttpTransaction(
        id: '1',
        method: 'GET',
        uri: Uri.parse('https://x.dev/graphql?query=%7Ba%7D'),
        startTime: DateTime(2026),
      ),
    );
    expect(command, "curl 'https://x.dev/graphql?query=%7Ba%7D'");
  });
}
