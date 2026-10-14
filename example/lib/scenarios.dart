import 'package:flutter/material.dart';

import 'graphql_client.dart';

final _countries = GraphQLClient(
  Uri.parse('https://countries.trevorblades.com/graphql'),
);
final _rickAndMorty = GraphQLClient(
  Uri.parse('https://rickandmortyapi.com/graphql'),
);
final _graphQLZero = GraphQLClient(
  Uri.parse('https://graphqlzero.almansi.me/api'),
);

/// One demo request. Each scenario shows a different feature of the
/// GraphQL tab in DevTools.
class Scenario {
  const Scenario({
    required this.title,
    required this.description,
    required this.icon,
    required this.run,
  });

  final String title;
  final String description;
  final IconData icon;
  final Future<GraphQLResult> Function() run;
}

final scenarios = <Scenario>[
  Scenario(
    title: 'Query with variables',
    description: 'GetCountry: one country by its code. See the Variables tab.',
    icon: Icons.flag_outlined,
    run: () => _countries.post(
      r'''
query GetCountry($code: ID!) {
  country(code: $code) {
    name
    native
    capital
    emoji
    currency
    languages { code name }
  }
}''',
      operationName: 'GetCountry',
      variables: {'code': 'IN'},
    ),
  ),
  Scenario(
    title: 'Large paginated list',
    description:
        'Characters: 20 items with nested objects. Try the Tree view and '
        'the search in the Raw view.',
    icon: Icons.view_list_outlined,
    run: () => _rickAndMorty.post(
      r'''
query Characters($page: Int!, $filter: FilterCharacter) {
  characters(page: $page, filter: $filter) {
    info { count pages next prev }
    results {
      id
      name
      status
      species
      gender
      origin { name }
      location { name }
      image
      episode { id episode }
    }
  }
}''',
      operationName: 'Characters',
      variables: {
        'page': 1,
        'filter': {'status': 'Alive'},
      },
    ),
  ),
  Scenario(
    title: 'Mutation',
    description: 'CreatePost: a mutation with an input object.',
    icon: Icons.edit_note,
    run: () => _graphQLZero.post(
      r'''
mutation CreatePost($input: CreatePostInput!) {
  createPost(input: $input) {
    id
    title
    body
  }
}''',
      operationName: 'CreatePost',
      variables: {
        'input': {
          'title': 'Hello from GraphQL Network DevTools',
          'body': 'This post is not saved. The API is a fake.',
        },
      },
    ),
  ),
  Scenario(
    title: 'Fragments and aliases',
    description:
        'CompareCharacters: two aliased fields that share one fragment.',
    icon: Icons.call_split,
    run: () => _rickAndMorty.post('''
query CompareCharacters {
  rick: character(id: 1) { ...CharacterFields }
  morty: character(id: 2) { ...CharacterFields }
}

fragment CharacterFields on Character {
  id
  name
  status
  species
  origin { name dimension }
}'''),
  ),
  Scenario(
    title: 'GraphQL error',
    description:
        'BrokenCountry asks for a field that does not exist. The server '
        'sends an errors list.',
    icon: Icons.error_outline,
    run: () => _countries.post('''
query BrokenCountry {
  country(code: "BR") {
    name
    population
  }
}'''),
  ),
  Scenario(
    title: 'GET request',
    description: 'Continents: the query is sent in the URL, not in a body.',
    icon: Icons.public,
    run: () => _countries.get('query Continents { continents { code name } }'),
  ),
  Scenario(
    title: 'Request headers',
    description:
        'Viewer: sends an authorization header. See the Headers tab and '
        'the cURL copy.',
    icon: Icons.key_outlined,
    run: () => _graphQLZero.post(
      'query Viewer { user(id: 1) { id name email company { name } } }',
      headers: {
        'authorization': 'Bearer demo-token',
        'x-request-id': 'example-${DateTime.now().millisecondsSinceEpoch}',
      },
    ),
  ),
  Scenario(
    title: 'Batched operations',
    description:
        'Two operations in one HTTP request. The tab shows them as two rows. '
        'This API rejects batches, so both rows show the error.',
    icon: Icons.layers_outlined,
    run: () => _graphQLZero.batch([
      {'query': 'query FirstPost { post(id: 1) { id title } }'},
      {'query': 'query FirstUser { user(id: 1) { id name } }'},
    ]),
  ),
  Scenario(
    title: 'Network failure',
    description:
        'Sends a query to a host that does not exist. The tab shows the '
        'request as failed.',
    icon: Icons.cloud_off,
    run: () => GraphQLClient(
      Uri.parse('https://graphql.invalid/graphql'),
    ).post('query Unreachable { status }'),
  ),
];
