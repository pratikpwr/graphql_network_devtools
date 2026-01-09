# GraphQL Network DevTools

A Flutter DevTools extension for inspecting GraphQL network operations in real-time.

## Features

- **Real-time Monitoring**: Auto-refresh every 2 seconds to capture new GraphQL operations as they happen
- **Operation Inspector**: View detailed request/response data, variables, headers, and errors
- **Smart Filtering**: Filter operations by type (Query, Mutation, Subscription) or search by operation name
- **Zero Configuration**: Works out of the box with any GraphQL client - no code changes required

## Installation

Add `graphql_network_devtools` to your `pubspec.yaml` under `dev_dependencies`:

```yaml
dev_dependencies:
  graphql_network_devtools: ^0.1.0
```

Or run:

```bash
flutter pub add --dev graphql_network_devtools
```

## Quick Start

1. Add the package to your project (see Installation above)
2. Run your Flutter app in **debug mode**
3. Open **Flutter DevTools**
4. Navigate to the **"GraphQL Network"** tab
5. Make GraphQL requests in your app — they appear automatically!

## How It Works

The extension automatically intercepts HTTP traffic using Flutter's built-in HTTP profiling. It detects GraphQL requests by checking:

- POST requests to URLs containing `graphql`, `/gql`, `/query`, or `/api/graph`
- Requests with `application/graphql` content type
- JSON POST requests with a `query` field in the body

**This works with any GraphQL client** including `graphql_flutter`, `ferry`, `dio`, `http`, etc.

## UI Controls

| Control | Description |
|---------|-------------|
| **Query / Mutation / Subscription** | Filter by operation type |
| **Search** | Filter by operation name or query content |
| **Refresh** | Manually refresh the operations list |
| **Clear** | Clear all captured operations |

## Troubleshooting

### Operations not appearing?

1. Ensure your app is running in **debug mode**
2. Check that your GraphQL endpoint URL contains `graphql`, `/gql`, `/query`, or `/api/graph`
3. Verify that requests are being made via HTTP POST

### Common issues:

| Issue | Solution |
|-------|----------|
| No HTTP requests captured | Ensure app is running in debug mode |
| Requests found but not GraphQL | URL might not match patterns - check if it contains `graphql` |
| GraphQL detected but no body | The HTTP client might not support body capture |

## Requirements

- Flutter SDK ≥ 3.16.0
- Dart SDK ≥ 3.0.0
- App must be running in **debug mode**

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details.
