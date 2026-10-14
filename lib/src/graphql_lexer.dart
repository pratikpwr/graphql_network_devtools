/// The kind of a [GraphQLToken].
enum GraphQLTokenKind {
  /// A name, for example a field, a type or a keyword.
  name,

  /// A variable reference such as `$id`. The token includes the `$`.
  variable,

  /// A directive such as `@include`. The token includes the `@`.
  directive,

  /// A string or a block string, with its quotes.
  string,

  /// An integer or a float.
  number,

  /// A punctuator, for example `{`, `(`, `:` or `...`.
  punctuator,

  /// A comment that starts with `#`.
  comment,

  /// Text that is not valid GraphQL. The lexer keeps it so that no input
  /// is lost.
  unknown,
}

/// One lexical token of a GraphQL document.
class GraphQLToken {
  /// Creates a token.
  const GraphQLToken(this.kind, this.text, this.offset);

  /// The kind of token.
  final GraphQLTokenKind kind;

  /// The source text of the token.
  final String text;

  /// The offset of the token in the source.
  final int offset;

  /// Whether this token is a name with the value [value].
  bool isName(String value) => kind == GraphQLTokenKind.name && text == value;

  /// Whether this token is the punctuator [value].
  bool isPunctuator(String value) =>
      kind == GraphQLTokenKind.punctuator && text == value;

  @override
  String toString() => '${kind.name}($text)';
}

/// Splits a GraphQL [source] into tokens.
///
/// Whitespace and commas outside strings are dropped, because they have
/// no meaning in GraphQL. Comments are kept when [includeComments] is true.
/// The lexer never throws. Text that it cannot read becomes
/// [GraphQLTokenKind.unknown] tokens.
List<GraphQLToken> tokenizeGraphQL(
  String source, {
  bool includeComments = true,
}) {
  final tokens = <GraphQLToken>[];
  var i = 0;
  final length = source.length;

  while (i < length) {
    final char = source[i];
    final code = source.codeUnitAt(i);

    if (char == ' ' ||
        char == '\t' ||
        char == '\n' ||
        char == '\r' ||
        char == ',' ||
        code == 0xFEFF) {
      i++;
      continue;
    }

    if (char == '#') {
      final start = i;
      while (i < length && source[i] != '\n' && source[i] != '\r') {
        i++;
      }
      if (includeComments) {
        tokens.add(
          GraphQLToken(
            GraphQLTokenKind.comment,
            source.substring(start, i),
            start,
          ),
        );
      }
      continue;
    }

    if (source.startsWith('...', i)) {
      tokens.add(GraphQLToken(GraphQLTokenKind.punctuator, '...', i));
      i += 3;
      continue;
    }

    if ('!&():=[]{|}'.contains(char)) {
      tokens.add(GraphQLToken(GraphQLTokenKind.punctuator, char, i));
      i++;
      continue;
    }

    if ((char == r'$' || char == '@') &&
        i + 1 < length &&
        _isNameStart(source.codeUnitAt(i + 1))) {
      final start = i;
      i++;
      while (i < length && _isNameContinue(source.codeUnitAt(i))) {
        i++;
      }
      tokens.add(
        GraphQLToken(
          char == r'$' ? GraphQLTokenKind.variable : GraphQLTokenKind.directive,
          source.substring(start, i),
          start,
        ),
      );
      continue;
    }

    if (_isNameStart(code)) {
      final start = i;
      while (i < length && _isNameContinue(source.codeUnitAt(i))) {
        i++;
      }
      tokens.add(
        GraphQLToken(GraphQLTokenKind.name, source.substring(start, i), start),
      );
      continue;
    }

    if (char == '-' || _isDigit(code)) {
      final start = i;
      i++;
      while (i < length) {
        final c = source[i];
        if (_isDigit(source.codeUnitAt(i)) ||
            c == '.' ||
            c == 'e' ||
            c == 'E' ||
            ((c == '+' || c == '-') &&
                (source[i - 1] == 'e' || source[i - 1] == 'E'))) {
          i++;
        } else {
          break;
        }
      }
      tokens.add(
        GraphQLToken(
          GraphQLTokenKind.number,
          source.substring(start, i),
          start,
        ),
      );
      continue;
    }

    if (source.startsWith('"""', i)) {
      final start = i;
      i += 3;
      while (i < length && !source.startsWith('"""', i)) {
        if (source.startsWith(r'\"""', i)) {
          i += 4;
        } else {
          i++;
        }
      }
      i = i + 3 > length ? length : i + 3;
      tokens.add(
        GraphQLToken(
          GraphQLTokenKind.string,
          source.substring(start, i),
          start,
        ),
      );
      continue;
    }

    if (char == '"') {
      final start = i;
      i++;
      while (i < length && source[i] != '"' && source[i] != '\n') {
        if (source[i] == r'\') i++;
        i++;
      }
      if (i < length && source[i] == '"') i++;
      if (i > length) i = length;
      tokens.add(
        GraphQLToken(
          GraphQLTokenKind.string,
          source.substring(start, i),
          start,
        ),
      );
      continue;
    }

    tokens.add(GraphQLToken(GraphQLTokenKind.unknown, char, i));
    i++;
  }

  return tokens;
}

bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

bool _isNameStart(int code) =>
    code == 0x5F || // _
    (code >= 0x41 && code <= 0x5A) || // A-Z
    (code >= 0x61 && code <= 0x7A); // a-z

bool _isNameContinue(int code) => _isNameStart(code) || _isDigit(code);
