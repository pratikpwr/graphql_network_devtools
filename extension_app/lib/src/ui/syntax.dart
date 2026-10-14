import 'package:flutter/material.dart';
import 'package:graphql_network_devtools/graphql_network_devtools.dart';

enum CodeLanguage { graphql, json, plain }

/// Token colors for syntax highlighting, in light and dark themes.
class SyntaxColors {
  const SyntaxColors({
    required this.keyword,
    required this.field,
    required this.type,
    required this.variable,
    required this.directive,
    required this.string,
    required this.number,
    required this.comment,
    required this.punctuation,
  });

  factory SyntaxColors.of(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return SyntaxColors(
        keyword: const Color(0xFFC586C0),
        field: const Color(0xFF9CDCFE),
        type: const Color(0xFF4EC9B0),
        variable: const Color(0xFF4FC1FF),
        directive: const Color(0xFFDCDCAA),
        string: const Color(0xFFCE9178),
        number: const Color(0xFFB5CEA8),
        comment: const Color(0xFF6A9955),
        punctuation: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      );
    }
    return SyntaxColors(
      keyword: const Color(0xFFAF00DB),
      field: const Color(0xFF001080),
      type: const Color(0xFF267F99),
      variable: const Color(0xFF0070C1),
      directive: const Color(0xFF795E26),
      string: const Color(0xFFA31515),
      number: const Color(0xFF098658),
      comment: const Color(0xFF008000),
      punctuation: theme.colorScheme.onSurface.withValues(alpha: 0.7),
    );
  }

  final Color keyword;
  final Color field;
  final Color type;
  final Color variable;
  final Color directive;
  final Color string;
  final Color number;
  final Color comment;
  final Color punctuation;
}

/// A colored range of source text.
class StyledRange {
  const StyledRange(this.start, this.end, this.color);

  final int start;
  final int end;
  final Color? color;
}

const _graphqlKeywords = {
  'query',
  'mutation',
  'subscription',
  'fragment',
  'on',
  'true',
  'false',
  'null',
};

/// Source longer than this is shown without colors, to keep the UI fast.
const maxHighlightLength = 400000;

/// Splits [code] into colored ranges that cover the whole text.
List<StyledRange> highlight(
  String code,
  CodeLanguage language,
  SyntaxColors colors,
) {
  if (code.length > maxHighlightLength) {
    return [StyledRange(0, code.length, null)];
  }
  final tokens = switch (language) {
    CodeLanguage.graphql => _graphqlRanges(code, colors),
    CodeLanguage.json => _jsonRanges(code, colors),
    CodeLanguage.plain => const <StyledRange>[],
  };

  // Fill the gaps between tokens with plain ranges.
  final ranges = <StyledRange>[];
  var position = 0;
  for (final token in tokens) {
    if (token.start > position) {
      ranges.add(StyledRange(position, token.start, null));
    }
    ranges.add(token);
    position = token.end;
  }
  if (position < code.length) {
    ranges.add(StyledRange(position, code.length, null));
  }
  return ranges;
}

List<StyledRange> _graphqlRanges(String code, SyntaxColors colors) {
  return [
    for (final token in tokenizeGraphQL(code))
      StyledRange(token.offset, token.offset + token.text.length, switch (token
          .kind) {
        GraphQLTokenKind.name when _graphqlKeywords.contains(token.text) =>
          colors.keyword,
        GraphQLTokenKind.name when _startsUpperCase(token.text) => colors.type,
        GraphQLTokenKind.name => colors.field,
        GraphQLTokenKind.variable => colors.variable,
        GraphQLTokenKind.directive => colors.directive,
        GraphQLTokenKind.string => colors.string,
        GraphQLTokenKind.number => colors.number,
        GraphQLTokenKind.comment => colors.comment,
        GraphQLTokenKind.punctuator => colors.punctuation,
        GraphQLTokenKind.unknown => null,
      }),
  ];
}

bool _startsUpperCase(String text) {
  final code = text.codeUnitAt(0);
  return code >= 0x41 && code <= 0x5A;
}

final _jsonToken = RegExp(
  r'"(?:[^"\\]|\\.)*"(\s*:)?|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|[{}\[\],:]',
);

List<StyledRange> _jsonRanges(String code, SyntaxColors colors) {
  return [
    for (final match in _jsonToken.allMatches(code))
      if (match.group(0)!.startsWith('"'))
        // A string that a colon follows is a key. Color only the quoted part.
        StyledRange(
          match.start,
          match.group(1) == null
              ? match.end
              : match.end - match.group(1)!.length,
          match.group(1) == null ? colors.string : colors.field,
        )
      else
        StyledRange(match.start, match.end, switch (match.group(0)!) {
          'true' || 'false' || 'null' => colors.keyword,
          '{' || '}' || '[' || ']' || ',' || ':' => colors.punctuation,
          _ => colors.number,
        }),
  ];
}
