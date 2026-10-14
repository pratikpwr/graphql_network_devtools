# GraphQL Network DevTools

[![pub package](https://img.shields.io/pub/v/graphql_network_devtools.svg)](https://pub.dev/packages/graphql_network_devtools)
[![pub points](https://img.shields.io/pub/points/graphql_network_devtools)](https://pub.dev/packages/graphql_network_devtools/score)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Flutter DevTools extension that shows your app's GraphQL traffic.

The built-in **Network** tab shows every GraphQL call as `POST /graphql`. This
extension shows each operation by its **name**, with its **type**, **variables**,
**response**, **GraphQL errors**, **headers** and **timing**. You do not have to
change your app code.

![Operations list and the response tree of the selected operation](https://raw.githubusercontent.com/pratikpwr/graphql_network_devtools/main/screenshots/overview.png)

## Features

- **Operation names.** Each row shows the operation name, for example
  `GetCountry`, with a badge for the type: query, mutation or subscription.
- **Clear status.** Each row shows the HTTP status, the number of GraphQL errors
  and the duration. Failed requests and GraphQL errors show in red.
- **Formatted query.** The query is pretty-printed and has syntax colors, also
  when the client sends it minified.
- **Response tree.** Open and close JSON nodes. Each closed object shows a short
  preview. Right-click a node to copy its value, its key or its path.
- **GraphQL errors.** Errors show above the response, with message, path, code
  and location.
- **Copy that works everywhere.** Copy the query, the variables, the response,
  the headers, the request as JSON, or a ready-to-run **cURL** command. Copy also
  works in the IDE (VS Code, Android Studio, IntelliJ), where many web views
  block the clipboard. Ctrl+C / Cmd+C and the right-click menu work on any
  selected text.
- **Search.** Filter the list by name, query text, URL or variables. Search
  inside a query or response with Ctrl+F / Cmd+F.
- **Filters.** Show only queries, mutations, subscriptions or errors. Each
  filter shows a count.
- **Zoom.** Make the whole UI larger or smaller with the A− / A+ buttons or with
  Ctrl/Cmd + `+`, `-` and `0`. The setting stays after DevTools reloads.
- **Recording control.** Pause recording, or clear the list.
- **Many request formats.** JSON `POST`, `GET` with query parameters, batched
  operations, automatic persisted queries, `application/graphql` bodies and
  multipart file uploads.
- **Any client.** Works with `graphql_flutter`, `ferry`, `dio`, `http`,
  `artemis` and any other client that uses `dart:io` HTTP.

| Formatted query with search | GraphQL errors |
| --- | --- |
| ![Query tab with syntax colors and search](https://raw.githubusercontent.com/pratikpwr/graphql_network_devtools/main/screenshots/query.png) | ![Response tab with a GraphQL error](https://raw.githubusercontent.com/pratikpwr/graphql_network_devtools/main/screenshots/errors.png) |

## Install

Add the package to `dev_dependencies`. It is a development tool, so your
release build does not include it.

```bash
flutter pub add --dev graphql_network_devtools
```

Or edit `pubspec.yaml`:

```yaml
dev_dependencies:
  graphql_network_devtools: ^0.2.0
```

The package has no runtime dependencies, so it does not cause version
conflicts with the packages of your app.

## Use

1. Run your app in debug or profile mode on Android, iOS, macOS, Windows or
   Linux.
2. Open Flutter DevTools. You can open it from VS Code, Android Studio, or the
   link that `flutter run` prints.
3. Open the **graphql_network_devtools** tab. If DevTools asks, select
   **Enable** for the extension.
4. Use your app. GraphQL operations show in the list within one second.
5. Select an operation to see its query, variables, response and headers.

DevTools saves your choice to enable the extension in `devtools_options.yaml`
in the root of your project. Commit this file to enable the extension for your
team.

### Capture requests at app start

The app records HTTP traffic only after HTTP logging is on. The extension turns
it on when you open the tab. To capture the requests that run before that, for
example at app start, turn logging on in `main()`:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  if (kDebugMode) HttpClient.enableTimelineLogging = true;
  runApp(const MyApp());
}
```

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Up / Down | Select the previous or next operation (click the list first) |
| Ctrl/Cmd + F | Filter the list, or search in the open query or response |
| Enter / Shift + Enter | Go to the next or previous search result |
| Esc | Close the search |
| Ctrl/Cmd + C | Copy the selected text |
| Ctrl/Cmd + `+` / `-` / `0` | Zoom in, zoom out, reset the zoom |

## How it works

The Dart VM keeps an HTTP profile of the requests that `dart:io` makes. The
DevTools **Network** tab uses the same data. This extension:

1. Turns on HTTP logging in each isolate of your app. It does this again after
   a hot restart.
2. Polls the profile once each second and reads only the requests that changed.
3. Loads the request and response bodies only for requests that can be GraphQL.
   It skips images and other traffic.
4. Reads the GraphQL operations from the bodies.

The parser is also a public, pure Dart API. You can use it to read GraphQL
operations from your own HTTP logs:

```dart
import 'package:graphql_network_devtools/graphql_network_devtools.dart';

final operations = parseGraphQLOperations(
  HttpTransaction(
    id: '1',
    method: 'POST',
    uri: Uri.parse('https://api.example.com/graphql'),
    startTime: DateTime.now(),
    requestHeaders: {'content-type': 'application/json'},
    requestBody: '{"query": "query GetUser { user { id } }"}',
  ),
);
print(operations.single.displayName); // GetUser
print(formatGraphQL('{ user { id name } }'));
```

## Limits

- **Web apps are not supported.** The HTTP profile exists only on the Dart VM.
  For Flutter web, use the network panel of the browser.
- **WebSocket subscriptions are not shown.** The extension reads HTTP traffic
  only. Subscriptions that use HTTP (for example server-sent events or
  multipart responses) show as normal requests.
- **Native HTTP clients.** `cupertino_http` and `cronet_http` show only if
  they report to the HTTP profile through `package:http_profile`.
- **History resets on hot restart.** DevTools reloads the extension when the
  app restarts. Requests that the app sends after the restart show as usual.
- **Internet access.** The extension loads its web renderer (CanvasKit) from
  the Google CDN the first time it opens.

## Troubleshooting

| Problem | What to do |
| --- | --- |
| I cannot find the tab | Open the extensions menu (puzzle icon) in the DevTools toolbar and enable `graphql_network_devtools`. Then run `flutter pub get` and restart DevTools. |
| The list stays empty | Make sure that the app runs on a device or desktop, not in a browser. Send a request after you open the tab, or turn logging on in `main()` (see above). |
| A request is missing | The extension shows a request only if its body is GraphQL (a `query` field, a persisted query, or `application/graphql`). A request that fails before it is sent shows only if its URL path contains `graphql` or `gql`. |
| "Could not read HTTP traffic" banner | The app is paused at a breakpoint, or it disconnected. Resume the app. |
| The text is too small | Use A+ in the toolbar, or Ctrl/Cmd + `+`. |

## Example

The [example app](example) sends real GraphQL requests to public APIs. It
shows a query with variables, a large list, a mutation, fragments, a GraphQL
error, a `GET` request, custom headers, a batch and a network failure.

```bash
cd example
flutter run -d macos   # or an Android or iOS device
```

## Contribute

Issues and pull requests are welcome on
[GitHub](https://github.com/pratikpwr/graphql_network_devtools/issues).

The repository has three parts:

| Folder | Content |
| --- | --- |
| `lib/` | The pure Dart parser and models. This is the published library. |
| `extension_app/` | The Flutter web app that DevTools shows. It is not published. |
| `extension/devtools/` | The compiled extension and its `config.yaml`. This is published. |

To change the extension UI:

```bash
cd extension_app
flutter pub get
flutter test --platform chrome

# Run in a browser with a simulated DevTools environment.
flutter run -d chrome --dart-define=use_simulated_environment=true

# Build into ../extension/devtools/build, then check the result.
dart run devtools_extensions build_and_copy --source=. --dest=../extension/devtools
dart run devtools_extensions validate --package=..
```

Commit the new `extension/devtools/build` output with your change.

## License

MIT. See [LICENSE](LICENSE).
