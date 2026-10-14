import 'settings_stub.dart'
    if (dart.library.js_interop) 'settings_web.dart'
    as impl;

/// Reads a saved setting, or returns `null` if there is none.
String? readSetting(String key) => impl.readSetting(key);

/// Saves a setting. It stays when DevTools reloads.
void writeSetting(String key, String value) => impl.writeSetting(key, value);
