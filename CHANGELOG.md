# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-10-14

### Added

- Response tree view. Open and close nodes, see a preview of closed objects,
  and right-click a node to copy its value, key or path.
- Syntax colors and pretty-printing for queries, also for minified queries.
- GraphQL error list above the response, with message, path, code and location.
- Copy buttons for the query, variables, response, headers, the request as
  JSON, and a cURL command.
- UI zoom with A− / A+ buttons and Ctrl/Cmd + `+`, `-`, `0`. The zoom level is
  saved.
- Filter for errors, filter counts, and a filter on URL and variables.
- Pause recording.
- Keyboard navigation: Up and Down in the list, Ctrl/Cmd + F to search.
- Resizable split view, which changes to a vertical layout in narrow windows.
- The operation list and the details show in outlined panels, with visible
  lines between the header, the tabs and each section.
- Support for batched operations, automatic persisted queries, `GET` requests,
  `application/graphql` bodies and multipart file uploads.
- Failed requests (for example a failed host lookup) to GraphQL URLs now show
  in the list.
- Messages for "no app connected" and "web app not supported".
- A public, pure Dart API: `parseGraphQLOperations`, `formatGraphQL`,
  `tokenizeGraphQL`, `toCurlCommand` and the `GraphQLOperation` model.
- A runnable example app that sends nine kinds of GraphQL requests to public
  APIs.

### Fixed

- Copy did not work in IDE web views (VS Code, Android Studio, IntelliJ). Copy
  now goes through DevTools, and Ctrl/Cmd + C and the right-click menu use the
  same path.
- The "Copy" in the Response tab copied only `data`. It now copies the full
  response, with `errors` and `extensions`.
- Operations stayed "Pending" after their response arrived.
- The details panel did not update when the selected operation completed.
- The search field moved the cursor to the end while you typed.
- Requests were found only for some URL patterns. Detection now reads the
  request body, so any GraphQL endpoint works.
- Code text did not use a monospace font.
- Lines between views were invisible, because the DevTools theme makes
  `dividerColor` transparent. All lines now use the `outlineVariant` color.
- The extension loaded all request bodies on each poll. It now loads only new
  and changed requests.

### Changed

- **Breaking:** The library no longer exports the `GraphQLNetworkExtension`
  widget. The extension UI moved to a separate, unpublished app in
  `extension_app/`.
- The package has no runtime dependencies. It no longer adds
  `devtools_extensions`, `vm_service` or `url_launcher` to your app.
- The base font size is larger (13 px instead of 12 px).
- The extension `config.yaml` uses the package name, as the DevTools
  specification requires. If DevTools asks again, enable the extension again.

## [0.1.1] - 2026-01-09

### Changed

- Updated the repository and issue tracker links.

## [0.1.0] - 2025-01-09

### Added

- First release of the GraphQL Network DevTools extension.
- Auto-refresh every 2 seconds.
- Request and response data, variables, headers and errors.
- Filter by operation type (query, mutation, subscription).
- Search by operation name or query text.
- No setup. Works with any GraphQL client.
