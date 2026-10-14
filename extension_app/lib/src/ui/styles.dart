import 'package:flutter/material.dart';
import 'package:graphql_network_devtools/graphql_network_devtools.dart';

/// Base font sizes, before zoom. DevTools uses 12 px text, which is hard to
/// read for long JSON, so the extension uses a slightly larger scale.
abstract final class FontSizes {
  static const double small = 12;
  static const double body = 13;
  static const double code = 13;
  static const double title = 16;
  static const double badge = 11;
}

const codeFontFamily = 'RobotoMono';

/// Returns [base] with the font sizes of the extension.
/// The color of all lines and outlines in the extension.
///
/// The DevTools theme sets `dividerColor` to transparent, so the extension
/// uses `outlineVariant`, which is visible in light and dark themes.
Color borderColor(ThemeData theme) => theme.colorScheme.outlineVariant;

BorderSide borderSide(ThemeData theme) => BorderSide(color: borderColor(theme));

ThemeData extensionTheme(ThemeData base) {
  final text = base.textTheme;
  final border = borderColor(base);
  return base.copyWith(
    dividerColor: border,
    dividerTheme: base.dividerTheme.copyWith(
      color: border,
      thickness: 1,
      space: 1,
    ),
    textTheme: text.copyWith(
      titleMedium: text.titleMedium?.copyWith(
        fontSize: FontSizes.title,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: text.titleSmall?.copyWith(
        fontSize: FontSizes.body + 1,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: FontSizes.body + 1),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: FontSizes.body),
      bodySmall: text.bodySmall?.copyWith(fontSize: FontSizes.small),
      labelLarge: text.labelLarge?.copyWith(fontSize: FontSizes.body),
      labelMedium: text.labelMedium?.copyWith(fontSize: FontSizes.small),
      labelSmall: text.labelSmall?.copyWith(fontSize: FontSizes.badge),
    ),
    tooltipTheme: base.tooltipTheme.copyWith(
      textStyle: TextStyle(
        fontSize: FontSizes.small,
        color: base.colorScheme.onInverseSurface,
      ),
      waitDuration: const Duration(milliseconds: 400),
    ),
  );
}

TextStyle codeTextStyle(ThemeData theme) => TextStyle(
  fontFamily: codeFontFamily,
  fontSize: FontSizes.code,
  height: 1.5,
  color: theme.colorScheme.onSurface,
);

bool _isDark(ThemeData theme) => theme.brightness == Brightness.dark;

Color typeColor(ThemeData theme, GraphQLOperationType type) {
  final dark = _isDark(theme);
  return switch (type) {
    GraphQLOperationType.query =>
      dark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
    GraphQLOperationType.mutation =>
      dark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
    GraphQLOperationType.subscription =>
      dark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2),
    GraphQLOperationType.unknown =>
      dark ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A),
  };
}

String typeLetter(GraphQLOperationType type) => switch (type) {
  GraphQLOperationType.query => 'Q',
  GraphQLOperationType.mutation => 'M',
  GraphQLOperationType.subscription => 'S',
  GraphQLOperationType.unknown => '?',
};

Color successColor(ThemeData theme) =>
    _isDark(theme) ? const Color(0xFF81C784) : const Color(0xFF2E7D32);

Color errorColor(ThemeData theme) =>
    _isDark(theme) ? const Color(0xFFEF9A9A) : const Color(0xFFC62828);

Color statusColor(ThemeData theme, GraphQLOperationStatus status) =>
    switch (status) {
      GraphQLOperationStatus.success => successColor(theme),
      GraphQLOperationStatus.pending => theme.colorScheme.onSurfaceVariant,
      _ => errorColor(theme),
    };

String statusLabel(GraphQLOperation operation) {
  final code = operation.statusCode;
  return switch (operation.status) {
    GraphQLOperationStatus.pending => 'Pending',
    GraphQLOperationStatus.failed => 'Failed',
    GraphQLOperationStatus.graphQLError =>
      '$code · ${operation.errors.length} '
          '${operation.errors.length == 1 ? 'error' : 'errors'}',
    _ => '$code',
  };
}

String formatDuration(Duration? duration) {
  if (duration == null) return '–';
  final ms = duration.inMicroseconds / 1000;
  if (ms < 1000) return '${ms.round()} ms';
  return '${(ms / 1000).toStringAsFixed(2)} s';
}

String formatBytes(int? bytes) {
  if (bytes == null) return '–';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatTime(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  final local = time.toLocal();
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}'
      '.${local.millisecond.toString().padLeft(3, '0')}';
}
