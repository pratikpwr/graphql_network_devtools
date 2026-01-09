# GraphQL Network DevTools Example

This package is a **Flutter DevTools extension** that automatically integrates with Flutter DevTools when added to your project.

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

## Usage

1. **Run your Flutter app in debug mode:**

   ```bash
   flutter run
   ```

2. **Open Flutter DevTools** (typically at `http://127.0.0.1:9100`)

3. **Navigate to the "GraphQL Network" tab**

4. **Make GraphQL requests** in your app — they appear automatically!

## Example with graphql_flutter

```dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

void main() async {
  await initHiveForFlutter();
  
  final HttpLink httpLink = HttpLink(
    'https://api.example.com/graphql',
  );

  final client = ValueNotifier(
    GraphQLClient(
      link: httpLink,
      cache: GraphQLCache(store: HiveStore()),
    ),
  );

  runApp(
    GraphQLProvider(
      client: client,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Query(
          options: QueryOptions(
            document: gql('''
              query GetUsers {
                users {
                  id
                  name
                  email
                }
              }
            '''),
          ),
          builder: (result, {fetchMore, refetch}) {
            if (result.hasException) {
              return Text('Error: ${result.exception}');
            }
            if (result.isLoading) {
              return const CircularProgressIndicator();
            }
            // The GraphQL Network DevTools extension will 
            // automatically capture this request!
            return ListView.builder(
              itemCount: result.data?['users']?.length ?? 0,
              itemBuilder: (context, index) {
                final user = result.data!['users'][index];
                return ListTile(
                  title: Text(user['name']),
                  subtitle: Text(user['email']),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
```

## What You'll See

In the GraphQL Network tab, you'll see:

- **Operation Name**: `GetUsers`
- **Operation Type**: Query
- **Status**: 200
- **Duration**: Response time
- **Request Details**: Headers, variables, full query
- **Response Details**: Data and any GraphQL errors
