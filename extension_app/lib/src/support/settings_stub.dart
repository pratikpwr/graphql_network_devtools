final _settings = <String, String>{};

String? readSetting(String key) => _settings[key];

void writeSetting(String key, String value) => _settings[key] = value;
