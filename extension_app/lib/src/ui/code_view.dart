import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'styles.dart';
import 'syntax.dart';
import 'widgets/common.dart';

const _maxMatches = 5000;

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}

/// Read-only source text with syntax colors, text search and copy.
///
/// The text is selectable. Ctrl+F or Cmd+F opens the search bar when the
/// focus is in the view. Enter and Shift+Enter move between matches.
class CodeView extends StatefulWidget {
  const CodeView({
    super.key,
    required this.code,
    required this.language,
    required this.title,
    this.subtitle,
    this.headerLeading,
    this.actions = const [],
    this.copyTooltip = 'Copy all',
    this.copyMessage,
  });

  final String code;
  final CodeLanguage language;
  final String title;
  final String? subtitle;

  /// If set, it shows in the header bar in place of [title].
  final Widget? headerLeading;

  /// More buttons for the header bar, before the search and copy buttons.
  final List<Widget> actions;
  final String copyTooltip;
  final String? copyMessage;

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _textKey = GlobalKey();

  bool _searchOpen = false;
  List<int> _matches = const [];
  int _current = 0;

  List<StyledRange>? _ranges;
  String? _rangesCode;
  Brightness? _rangesBrightness;

  @override
  void didUpdateWidget(CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _findMatches();
      if (oldWidget.title != widget.title && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    });
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchController.clear();
      _matches = const [];
      _current = 0;
    });
  }

  void _findMatches() {
    final query = _searchController.text.toLowerCase();
    final matches = <int>[];
    if (query.isNotEmpty) {
      final code = widget.code.toLowerCase();
      var index = code.indexOf(query);
      while (index != -1 && matches.length < _maxMatches) {
        matches.add(index);
        index = code.indexOf(query, index + query.length);
      }
    }
    _matches = matches;
    _current = 0;
  }

  void _onQueryChanged(String _) {
    setState(_findMatches);
    _revealCurrent();
  }

  void _step(int delta) {
    if (_matches.isEmpty) return;
    setState(() {
      _current = (_current + delta) % _matches.length;
      if (_current < 0) _current += _matches.length;
    });
    _revealCurrent();
  }

  void _revealCurrent() {
    if (_matches.isEmpty) return;
    final offset = _matches[_current];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final paragraph = _findParagraph(
        _textKey.currentContext?.findRenderObject(),
      );
      if (paragraph == null || !paragraph.attached) return;
      final caret = paragraph.getOffsetForCaret(
        TextPosition(offset: offset),
        Rect.zero,
      );
      final lineHeight = FontSizes.code * 1.5;
      paragraph.showOnScreen(
        rect: Rect.fromLTWH(
          caret.dx,
          caret.dy - lineHeight * 2,
          1,
          lineHeight * 5,
        ),
        duration: const Duration(milliseconds: 150),
      );
    });
  }

  RenderParagraph? _findParagraph(RenderObject? object) {
    if (object == null) return null;
    if (object is RenderParagraph) return object;
    RenderParagraph? found;
    object.visitChildren((child) => found ??= _findParagraph(child));
    return found;
  }

  List<StyledRange> _rangesFor(ThemeData theme) {
    if (_ranges == null ||
        _rangesCode != widget.code ||
        _rangesBrightness != theme.brightness) {
      _ranges = highlight(widget.code, widget.language, SyntaxColors.of(theme));
      _rangesCode = widget.code;
      _rangesBrightness = theme.brightness;
    }
    return _ranges!;
  }

  List<InlineSpan> _spans(ThemeData theme) {
    final code = widget.code;
    final ranges = _rangesFor(theme);
    final length = _searchController.text.length;
    final matchColor = Colors.amber.withValues(alpha: 0.35);
    final currentColor = Colors.orange.withValues(alpha: 0.75);

    final spans = <InlineSpan>[];
    var m = 0;
    for (final range in ranges) {
      var position = range.start;
      while (position < range.end) {
        while (m < _matches.length && _matches[m] + length <= position) {
          m++;
        }
        var end = range.end;
        Color? background;
        if (m < _matches.length && _matches[m] <= position) {
          end = math.min(range.end, _matches[m] + length);
          background = m == _current ? currentColor : matchColor;
        } else if (m < _matches.length && _matches[m] < range.end) {
          end = _matches[m];
        }
        spans.add(
          TextSpan(
            text: code.substring(position, end),
            style: range.color == null && background == null
                ? null
                : TextStyle(color: range.color, backgroundColor: background),
          ),
        );
        position = end;
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _OpenSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _OpenSearchIntent(),
      },
      child: Actions(
        actions: {
          _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
            onInvoke: (_) => _openSearch(),
          ),
        },
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionBar(
                title: widget.title,
                subtitle: widget.subtitle,
                leading: widget.headerLeading,
                actions: [
                  ...widget.actions,
                  IconButton(
                    tooltip: 'Search (Ctrl+F / Cmd+F)',
                    isSelected: _searchOpen,
                    icon: const Icon(Icons.search, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: _searchOpen ? _closeSearch : _openSearch,
                  ),
                  CopyButton(
                    text: () => widget.code,
                    tooltip: widget.copyTooltip,
                    message: widget.copyMessage,
                  ),
                ],
              ),
              if (_searchOpen) _buildSearchBar(theme),
              Expanded(
                child: ColoredBox(
                  color: theme.colorScheme.surfaceContainerLowest,
                  child: CopyableSelectionArea(
                    child: Scrollbar(
                      controller: _scrollController,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                        child: Text.rich(
                          TextSpan(children: _spans(theme)),
                          key: _textKey,
                          style: codeTextStyle(theme),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    final hasQuery = _searchController.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(bottom: borderSide(theme)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _closeSearch,
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  shift: true,
                ): () =>
                    _step(-1),
              },
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onQueryChanged,
                onSubmitted: (_) {
                  if (!HardwareKeyboard.instance.isShiftPressed) _step(1);
                },
                onEditingComplete: () {},
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Find in ${widget.title.toLowerCase()}',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(
              !hasQuery
                  ? ''
                  : _matches.isEmpty
                  ? 'No results'
                  : '${_current + 1} of ${_matches.length}'
                        '${_matches.length >= _maxMatches ? '+' : ''}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasQuery && _matches.isEmpty
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Previous (Shift+Enter)',
            icon: const Icon(Icons.keyboard_arrow_up, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: _matches.isEmpty ? null : () => _step(-1),
          ),
          IconButton(
            tooltip: 'Next (Enter)',
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: _matches.isEmpty ? null : () => _step(1),
          ),
          IconButton(
            tooltip: 'Close (Esc)',
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: _closeSearch,
          ),
        ],
      ),
    );
  }
}
