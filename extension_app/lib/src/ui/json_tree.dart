import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../support/clipboard.dart';
import 'styles.dart';
import 'syntax.dart';
import 'widgets/common.dart';

const _rowHeight = 24.0;
const _indent = 16.0;
const _maxExpandAll = 20000;

/// Converts [value] to indented JSON text. Strings stay as they are.
String jsonText(Object? value, {bool rawStrings = false}) {
  if (rawStrings && value is String) return value;
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return '$value';
  }
}

/// Converts a JSON path to text, for example `data.users[0].name`.
String jsonPathText(List<Object> path) {
  final buffer = StringBuffer();
  for (final segment in path) {
    if (segment is int) {
      buffer.write('[$segment]');
    } else {
      if (buffer.isNotEmpty) buffer.write('.');
      buffer.write(segment);
    }
  }
  return buffer.toString();
}

class _Row {
  const _Row(this.key, this.value, this.path, this.depth);

  final Object? key;
  final Object? value;
  final List<Object> path;
  final int depth;

  bool get isContainer =>
      (value is Map && (value as Map).isNotEmpty) ||
      (value is List && (value as List).isNotEmpty);
}

String _pathKey(List<Object> path) =>
    path.map((s) => s is int ? '[$s]' : '.$s').join();

/// A collapsible tree view of a JSON value.
///
/// Click a row to open or close it. Right-click a row, or use its copy
/// button, to copy the value, the key or the path.
class JsonTreeView extends StatefulWidget {
  const JsonTreeView({
    super.key,
    required this.value,
    this.initialDepth = 5,
    this.headerLeading,
  });

  final Object? value;

  /// If set, it shows in the header bar in place of the title.
  final Widget? headerLeading;

  /// Rows up to this depth are open at the start.
  final int initialDepth;

  @override
  State<JsonTreeView> createState() => _JsonTreeViewState();
}

class _JsonTreeViewState extends State<JsonTreeView> {
  final _expanded = <String>{};
  final _menu = MenuController();
  final _anchorKey = GlobalKey();
  final _scrollController = ScrollController();
  _Row? _menuRow;

  @override
  void initState() {
    super.initState();
    _expandTo(widget.value, const [], widget.initialDepth);
  }

  @override
  void didUpdateWidget(JsonTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.value, widget.value)) {
      _expanded.clear();
      _expandTo(widget.value, const [], widget.initialDepth);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _expandTo(Object? value, List<Object> path, int depth) {
    if (depth <= 0 || _expanded.length > _maxExpandAll) return;
    if (value is Map) {
      if (path.isNotEmpty) _expanded.add(_pathKey(path));
      for (final entry in value.entries) {
        _expandTo(entry.value, [...path, '${entry.key}'], depth - 1);
      }
    } else if (value is List) {
      if (path.isNotEmpty) _expanded.add(_pathKey(path));
      // Open only the first items of long lists.
      for (var i = 0; i < value.length && i < 3; i++) {
        _expandTo(value[i], [...path, i], depth - 1);
      }
    }
  }

  List<_Row> _rows() {
    final rows = <_Row>[];
    final root = widget.value;
    if (root is Map || root is List) {
      _addChildren(rows, root, const [], 0);
    } else {
      rows.add(_Row(null, root, const [], 0));
    }
    return rows;
  }

  void _addChildren(
    List<_Row> rows,
    Object? value,
    List<Object> path,
    int depth,
  ) {
    void add(Object key, Object? child, List<Object> childPath) {
      final row = _Row(key, child, childPath, depth);
      rows.add(row);
      if (row.isContainer && _expanded.contains(_pathKey(childPath))) {
        _addChildren(rows, child, childPath, depth + 1);
      }
    }

    if (value is Map) {
      for (final entry in value.entries) {
        add(entry.key, entry.value, [...path, '${entry.key}']);
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        add(i, value[i], [...path, i]);
      }
    }
  }

  void _toggle(_Row row) {
    if (!row.isContainer) return;
    final key = _pathKey(row.path);
    setState(() {
      if (!_expanded.remove(key)) _expanded.add(key);
    });
  }

  void _setAll(bool open) {
    setState(() {
      _expanded.clear();
      if (open) _expandTo(widget.value, const [], 1 << 20);
    });
  }

  void _openMenu(_Row row, Offset globalPosition) {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _menuRow = row);
    _menu.open(position: box.globalToLocal(globalPosition));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _rows();
    final colors = SyntaxColors.of(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionBar(
          title: 'Tree',
          leading: widget.headerLeading,
          actions: [
            IconButton(
              tooltip: 'Expand all',
              icon: const Icon(Icons.unfold_more, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => _setAll(true),
            ),
            IconButton(
              tooltip: 'Collapse all',
              icon: const Icon(Icons.unfold_less, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => _setAll(false),
            ),
            CopyButton(
              text: () => jsonText(widget.value),
              tooltip: 'Copy all as JSON',
              message: 'Copied JSON',
            ),
          ],
        ),
        Expanded(
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerLowest,
            child: MenuAnchor(
              controller: _menu,
              menuChildren: _menuItems(),
              child: CopyableSelectionArea(
                key: _anchorKey,
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemExtent: _rowHeight,
                    itemCount: rows.length,
                    itemBuilder: (context, index) => _JsonRow(
                      row: rows[index],
                      expanded: _expanded.contains(_pathKey(rows[index].path)),
                      colors: colors,
                      onToggle: _toggle,
                      onMenu: _openMenu,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _menuItems() {
    final row = _menuRow;
    if (row == null) return const [];
    return [
      MenuItemButton(
        leadingIcon: const Icon(Icons.copy_rounded, size: 16),
        onPressed: () => unawaited(
          copyText(
            jsonText(row.value, rawStrings: true),
            message: 'Copied value',
          ),
        ),
        child: const Text('Copy value'),
      ),
      if (row.key != null)
        MenuItemButton(
          leadingIcon: const Icon(Icons.key, size: 16),
          onPressed: () =>
              unawaited(copyText('${row.key}', message: 'Copied key')),
          child: const Text('Copy key'),
        ),
      if (row.path.isNotEmpty)
        MenuItemButton(
          leadingIcon: const Icon(Icons.route, size: 16),
          onPressed: () => unawaited(
            copyText(jsonPathText(row.path), message: 'Copied path'),
          ),
          child: const Text('Copy path'),
        ),
    ];
  }
}

class _JsonRow extends StatefulWidget {
  const _JsonRow({
    required this.row,
    required this.expanded,
    required this.colors,
    required this.onToggle,
    required this.onMenu,
  });

  final _Row row;
  final bool expanded;
  final SyntaxColors colors;
  final ValueChanged<_Row> onToggle;
  final void Function(_Row row, Offset globalPosition) onMenu;

  @override
  State<_JsonRow> createState() => _JsonRowState();
}

class _JsonRowState extends State<_JsonRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = widget.row;
    final colors = widget.colors;
    final style = codeTextStyle(theme).copyWith(height: 1.2);

    final preview = _preview(row.value, colors, widget.expanded);
    final valueText = row.value is String ? row.value as String : null;

    Widget content = Text.rich(
      TextSpan(
        children: [
          if (row.key != null)
            TextSpan(
              text: '${row.key}',
              style: TextStyle(
                color: row.key is int ? colors.number : colors.field,
              ),
            ),
          if (row.key != null)
            TextSpan(
              text: ': ',
              style: TextStyle(color: colors.punctuation),
            ),
          preview,
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: style,
    );
    if (valueText != null && valueText.length > 60) {
      content = Tooltip(
        message: valueText.length > 2000
            ? '${valueText.substring(0, 2000)}…'
            : valueText,
        child: content,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onToggle(row),
        onSecondaryTapDown: (details) =>
            widget.onMenu(row, details.globalPosition),
        child: Container(
          color: _hovered
              ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
              : null,
          padding: EdgeInsets.only(left: 8 + row.depth * _indent, right: 4),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: row.isContainer
                    ? Icon(
                        widget.expanded
                            ? Icons.arrow_drop_down
                            : Icons.arrow_right,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              Expanded(child: content),
              if (_hovered)
                SelectionContainer.disabled(
                  child: CopyButton(
                    dense: true,
                    tooltip: 'Copy value',
                    message: 'Copied value',
                    text: () => jsonText(row.value, rawStrings: true),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InlineSpan _preview(Object? value, SyntaxColors colors, bool expanded) {
    TextSpan muted(String text) => TextSpan(
      text: text,
      style: TextStyle(color: colors.punctuation),
    );
    return switch (value) {
      Map(:final length) when length == 0 => muted('{}'),
      List(:final length) when length == 0 => muted('[]'),
      Map() => muted(expanded ? '{' : _mapSummary(value)),
      List(:final length) => muted(
        expanded ? '[' : '[…] $length ${length == 1 ? 'item' : 'items'}',
      ),
      String() => TextSpan(
        text: jsonEncode(value),
        style: TextStyle(color: colors.string),
      ),
      num() => TextSpan(
        text: '$value',
        style: TextStyle(color: colors.number),
      ),
      bool() || null => TextSpan(
        text: '$value',
        style: TextStyle(color: colors.keyword),
      ),
      _ => TextSpan(text: '$value'),
    };
  }
}

/// A short one-line summary of a map, for example
/// `{id: "1", name: "Rick", …}`.
String _mapSummary(Map<Object?, Object?> map) {
  const maxLength = 70;
  final buffer = StringBuffer('{');
  var first = true;
  for (final entry in map.entries) {
    final value = switch (entry.value) {
      Map() => '{…}',
      List(:final length) => '[$length]',
      String() => jsonEncode(entry.value),
      final other => '$other',
    };
    final part = '${first ? '' : ', '}${entry.key}: $value';
    if (buffer.length + part.length > maxLength) {
      buffer.write(first ? '…' : ', …');
      break;
    }
    buffer.write(part);
    first = false;
  }
  buffer.write('}');
  return buffer.toString();
}
