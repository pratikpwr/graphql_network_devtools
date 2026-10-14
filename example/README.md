# GraphQL Network DevTools example

This Flutter app sends real GraphQL requests to public APIs. Use it to try the
GraphQL tab in Flutter DevTools.

## Run the example

1. Run the app on a device or a desktop. Web is not supported.

   ```bash
   cd example
   flutter run -d macos   # or: flutter run -d <android-or-ios-device>
   ```

2. Open Flutter DevTools from the link that `flutter run` prints, or from
   your IDE.
3. Open the **graphql_network_devtools** tab. The file
   `devtools_options.yaml` already enables the extension.
4. In the app, tap **Run** on a card, or tap **Run all**.
5. Select an operation in DevTools.

## Scenarios

| Scenario | Operation | What to look at |
| --- | --- | --- |
| Query with variables | `GetCountry` | The Variables tab |
| Large paginated list | `Characters` | The Tree view, and search in the Raw view |
| Mutation | `CreatePost` | The mutation badge and the input object |
| Fragments and aliases | `CompareCharacters` | The formatted query |
| GraphQL error | `BrokenCountry` | The error list above the response |
| GET request | `Continents` | The query in the URL |
| Request headers | `Viewer` | The Headers tab and the cURL copy |
| Batched operations | `FirstPost`, `FirstUser` | One HTTP request shows as two rows |
| Network failure | Unknown operation | The failed status and the socket error |

## Add the extension to your app

Add the package to `dev_dependencies`:

```yaml
dev_dependencies:
  graphql_network_devtools: ^0.2.0
```

You do not have to change your app code. Any GraphQL client that uses
`dart:io` HTTP works, for example `graphql_flutter`, `ferry`, `dio` or `http`.

To also capture requests that run at app start, turn on HTTP logging in
`main()`, as [lib/main.dart](lib/main.dart) does:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  if (kDebugMode) HttpClient.enableTimelineLogging = true;
  runApp(const MyApp());
}
```

## Files

| File | Content |
| --- | --- |
| [lib/main.dart](lib/main.dart) | The app UI: one card for each scenario. |
| [lib/scenarios.dart](lib/scenarios.dart) | The GraphQL requests. |
| [lib/graphql_client.dart](lib/graphql_client.dart) | A small GraphQL client on top of `package:http`. |
| [devtools_options.yaml](devtools_options.yaml) | Enables the extension in DevTools. |

The public APIs are
[Countries](https://countries.trevorblades.com),
[Rick and Morty](https://rickandmortyapi.com/graphql) and
[GraphQLZero](https://graphqlzero.almansi.me).
