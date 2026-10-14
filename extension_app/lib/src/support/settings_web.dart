import 'package:web/web.dart' as web;

const _prefix = 'graphql_network_devtools.';

String? readSetting(String key) {
  try {
    return web.window.localStorage.getItem('$_prefix$key');
  } catch (_) {
    // Storage can be blocked in an IDE web view.
    return null;
  }
}

void writeSetting(String key, String value) {
  try {
    web.window.localStorage.setItem('$_prefix$key', value);
  } catch (_) {
    // Storage can be blocked in an IDE web view.
  }
}
