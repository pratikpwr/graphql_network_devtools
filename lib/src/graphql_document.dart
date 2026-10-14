import 'graphql_lexer.dart';
import 'graphql_operation.dart';

/// The type and name of one operation in a GraphQL document.
class GraphQLOperationSignature {
  /// Creates an operation signature.
  const GraphQLOperationSignature(this.type, this.name);

  /// The operation type.
  final GraphQLOperationType type;

  /// The operation name, or `null` for an anonymous operation.
  final String? name;
}

/// Finds the operation that a request executes in [document].
///
/// A document can contain many operations and fragments. If
/// [operationName] is set, the operation with that name is returned.
/// If not, the first operation is returned. If the document has no
/// operation, the result has the type [GraphQLOperationType.unknown].
GraphQLOperationSignature findOperation(
  String document, {
  String? operationName,
}) {
  final operations = listOperations(document);
  if (operations.isEmpty) {
    return GraphQLOperationSignature(GraphQLOperationType.unknown, null);
  }
  if (operationName != null && operationName.isNotEmpty) {
    for (final operation in operations) {
      if (operation.name == operationName) return operation;
    }
  }
  return operations.first;
}

/// Lists all operations (not fragments) in [document], in source order.
List<GraphQLOperationSignature> listOperations(String document) {
  final tokens = tokenizeGraphQL(document, includeComments: false);
  final operations = <GraphQLOperationSignature>[];
  var depth = 0;

  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.isPunctuator('{')) {
      if (depth == 0 && _isAnonymousQueryStart(tokens, i)) {
        operations.add(
          const GraphQLOperationSignature(GraphQLOperationType.query, null),
        );
      }
      depth++;
    } else if (token.isPunctuator('}')) {
      if (depth > 0) depth--;
    } else if (depth == 0 && token.kind == GraphQLTokenKind.name) {
      final type = switch (token.text) {
        'query' => GraphQLOperationType.query,
        'mutation' => GraphQLOperationType.mutation,
        'subscription' => GraphQLOperationType.subscription,
        _ => null,
      };
      if (type == null) continue;
      final next = i + 1 < tokens.length ? tokens[i + 1] : null;
      final name = next != null && next.kind == GraphQLTokenKind.name
          ? next.text
          : null;
      operations.add(GraphQLOperationSignature(type, name));
    }
  }
  return operations;
}

/// Whether the `{` at [index] starts a shorthand query such as `{ me { id } }`.
bool _isAnonymousQueryStart(List<GraphQLToken> tokens, int index) {
  // A shorthand query has no header, so nothing but the end of a previous
  // definition can come before its `{`.
  return index == 0 || tokens[index - 1].isPunctuator('}');
}

/// Pretty-prints a GraphQL [document] with two-space indentation.
///
/// Each field goes on its own line. Arguments, variables, lists and
/// input objects stay on one line. Comments are kept. If the document
/// contains text that is not valid GraphQL, the trimmed input is returned
/// without changes.
String formatGraphQL(String document) {
  final tokens = tokenizeGraphQL(document);
  if (tokens.isEmpty ||
      tokens.any((token) => token.kind == GraphQLTokenKind.unknown)) {
    return document.trim();
  }

  final out = StringBuffer();
  var indent = 0;
  var inlineDepth = 0;
  var atLineStart = true;
  var blankLinePending = false;
  GraphQLToken? previous;
  GraphQLToken? beforePrevious;

  void newLine() {
    if (!atLineStart) {
      out.write('\n');
      atLineStart = true;
    }
  }

  void write(String text, {String separator = ''}) {
    if (atLineStart) {
      if (blankLinePending && out.isNotEmpty) out.write('\n');
      blankLinePending = false;
      out.write('  ' * indent);
      atLineStart = false;
    } else {
      out.write(separator);
    }
    out.write(text);
  }

  for (final token in tokens) {
    if (token.kind == GraphQLTokenKind.comment) {
      if (inlineDepth == 0) newLine();
      write(token.text, separator: ' ');
      if (inlineDepth == 0) newLine();
    } else if (inlineDepth > 0) {
      final opens =
          token.isPunctuator('(') ||
          token.isPunctuator('[') ||
          token.isPunctuator('{');
      final closes =
          token.isPunctuator(')') ||
          token.isPunctuator(']') ||
          token.isPunctuator('}');
      write(token.text, separator: _inlineSeparator(previous, token));
      if (opens) inlineDepth++;
      if (closes) inlineDepth--;
    } else if (token.isPunctuator('{')) {
      write('{', separator: ' ');
      indent++;
      newLine();
    } else if (token.isPunctuator('}')) {
      if (indent > 0) indent--;
      newLine();
      write('}');
      newLine();
      if (indent == 0) blankLinePending = true;
    } else if (token.isPunctuator('(') || token.isPunctuator('[')) {
      write(token.text);
      inlineDepth++;
    } else {
      if (indent > 0 && _startsNewSelection(beforePrevious, previous, token)) {
        newLine();
      }
      write(token.text, separator: _blockSeparator(previous, token));
    }
    beforePrevious = previous;
    previous = token;
  }

  return out.toString().trimRight();
}

bool _startsNewSelection(
  GraphQLToken? beforePrevious,
  GraphQLToken? previous,
  GraphQLToken token,
) {
  if (previous == null) return false;
  final startsItem =
      token.kind == GraphQLTokenKind.name || token.isPunctuator('...');
  if (!startsItem) return false;
  if (previous.isPunctuator(':') || previous.isPunctuator('...')) return false;
  if (previous.isName('on') &&
      beforePrevious != null &&
      beforePrevious.isPunctuator('...')) {
    return false;
  }
  return previous.kind == GraphQLTokenKind.name ||
      previous.kind == GraphQLTokenKind.directive ||
      previous.isPunctuator(')') ||
      previous.isPunctuator('}');
}

String _blockSeparator(GraphQLToken? previous, GraphQLToken token) {
  if (previous == null) return '';
  if (token.isPunctuator(':') || token.isPunctuator('!')) return '';
  if (previous.isPunctuator('...')) {
    return token.kind == GraphQLTokenKind.name && !token.isName('on')
        ? ''
        : ' ';
  }
  return ' ';
}

String _inlineSeparator(GraphQLToken? previous, GraphQLToken token) {
  if (previous == null) return '';
  if (previous.isPunctuator('(') ||
      previous.isPunctuator('[') ||
      previous.isPunctuator('{')) {
    return '';
  }
  if (token.isPunctuator(')') ||
      token.isPunctuator(']') ||
      token.isPunctuator('}') ||
      token.isPunctuator(':') ||
      token.isPunctuator('!')) {
    return '';
  }
  if (token.isPunctuator('(')) return '';
  if (previous.isPunctuator(':') ||
      previous.isPunctuator('=') ||
      token.isPunctuator('=')) {
    return ' ';
  }
  if (token.kind == GraphQLTokenKind.directive) return ' ';
  if (_endsValue(previous) && _startsValue(token)) return ', ';
  return ' ';
}

bool _endsValue(GraphQLToken token) =>
    token.kind == GraphQLTokenKind.name ||
    token.kind == GraphQLTokenKind.variable ||
    token.kind == GraphQLTokenKind.string ||
    token.kind == GraphQLTokenKind.number ||
    token.isPunctuator(']') ||
    token.isPunctuator('}') ||
    token.isPunctuator(')') ||
    token.isPunctuator('!');

bool _startsValue(GraphQLToken token) =>
    token.kind == GraphQLTokenKind.name ||
    token.kind == GraphQLTokenKind.variable ||
    token.kind == GraphQLTokenKind.string ||
    token.kind == GraphQLTokenKind.number ||
    token.isPunctuator('[') ||
    token.isPunctuator('{');
