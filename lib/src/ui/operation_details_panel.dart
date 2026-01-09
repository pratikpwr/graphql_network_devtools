import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/graphql_operation.dart';

/// Panel showing details of a selected GraphQL operation.
class OperationDetailsPanel extends StatefulWidget {
  final GraphQLOperation operation;

  const OperationDetailsPanel({super.key, required this.operation});

  @override
  State<OperationDetailsPanel> createState() => _OperationDetailsPanelState();
}

class _OperationDetailsPanelState extends State<OperationDetailsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header
        _buildHeader(theme),
        const Divider(height: 1),
        // Tabs
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Query'),
            Tab(text: 'Variables'),
            Tab(text: 'Response'),
            Tab(text: 'Headers'),
          ],
          labelStyle: theme.textTheme.bodySmall,
          isScrollable: true,
        ),
        const Divider(height: 1),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _QueryTab(operation: widget.operation),
              _VariablesTab(operation: widget.operation),
              _ResponseTab(operation: widget.operation),
              _HeadersTab(operation: widget.operation),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final op = widget.operation;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTypeBadge(theme, op.type),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  op.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusBadge(theme),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.link,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SelectableText(
                  op.uri,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                op.durationDisplay,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(ThemeData theme, GraphQLOperationType type) {
    final color = _getTypeColor(type);
    final label = type.name.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    final op = widget.operation;
    final color = _getStatusColor(op);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (op.hasErrors)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.error_outline, size: 14, color: Colors.red),
            ),
          Text(
            op.statusDisplay,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(GraphQLOperationType type) {
    switch (type) {
      case GraphQLOperationType.query:
        return Colors.blue;
      case GraphQLOperationType.mutation:
        return Colors.orange;
      case GraphQLOperationType.subscription:
        return Colors.purple;
      case GraphQLOperationType.unknown:
        return Colors.grey;
    }
  }

  Color _getStatusColor(GraphQLOperation operation) {
    if (operation.statusCode == null) return Colors.grey;
    if (operation.hasErrors) return Colors.red;
    if (operation.isSuccess) return Colors.green;
    if (operation.statusCode! >= 400) return Colors.red;
    return Colors.orange;
  }
}

/// Tab showing the GraphQL query
class _QueryTab extends StatelessWidget {
  final GraphQLOperation operation;

  const _QueryTab({required this.operation});

  @override
  Widget build(BuildContext context) {
    return _SearchableCodeView(
      code: _formatGraphQL(operation.query),
      language: 'graphql',
    );
  }

  String _formatGraphQL(String query) {
    // Basic formatting - add proper indentation
    // This is a simple implementation; a proper parser would be better
    return query.trim();
  }
}

/// Tab showing variables
class _VariablesTab extends StatelessWidget {
  final GraphQLOperation operation;

  const _VariablesTab({required this.operation});

  @override
  Widget build(BuildContext context) {
    if (operation.variables == null || operation.variables!.isEmpty) {
      return const _EmptyState(message: 'No variables');
    }

    return _SearchableCodeView(
      code: _formatJson(operation.variables),
      language: 'json',
    );
  }

  String _formatJson(Map<String, dynamic>? json) {
    if (json == null) return '';
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}

/// Tab showing response data and errors
class _ResponseTab extends StatelessWidget {
  final GraphQLOperation operation;

  const _ResponseTab({required this.operation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (operation.rawResponseBody == null) {
      return const _EmptyState(message: 'No response yet');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Errors section
        if (operation.hasErrors)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.red.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Errors',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final error in operation.errors ?? [])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SelectableText(
                      '• ${error['message'] ?? error.toString()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        // Data section
        Expanded(
          child: operation.responseData != null
              ? _SearchableCodeView(
                  code: _formatJson(operation.responseData),
                  language: 'json',
                )
              : _SearchableCodeView(
                  code: _tryFormatJson(operation.rawResponseBody),
                  language: 'json',
                ),
        ),
      ],
    );
  }

  String _formatJson(Map<String, dynamic>? json) {
    if (json == null) return '';
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }

  String _tryFormatJson(String? rawBody) {
    if (rawBody == null) return '';
    try {
      final parsed = jsonDecode(rawBody);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(parsed);
    } catch (e) {
      return rawBody;
    }
  }
}

/// Tab showing request and response headers
class _HeadersTab extends StatelessWidget {
  final GraphQLOperation operation;

  const _HeadersTab({required this.operation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Request headers
          Text(
            'Request Headers',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (operation.requestHeaders == null ||
              operation.requestHeaders!.isEmpty)
            Text(
              'No request headers',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            _HeadersTable(headers: operation.requestHeaders!),
          const SizedBox(height: 24),
          // Response headers
          Text(
            'Response Headers',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (operation.responseHeaders == null ||
              operation.responseHeaders!.isEmpty)
            Text(
              'No response headers',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            _HeadersTable(headers: operation.responseHeaders!),
        ],
      ),
    );
  }
}

/// Table showing headers
class _HeadersTable extends StatelessWidget {
  final Map<String, String> headers;

  const _HeadersTable({required this.headers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = headers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children: [
        for (final entry in entries)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 4),
                child: SelectableText(
                  entry.key,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  entry.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Searchable code view with copy and search buttons
class _SearchableCodeView extends StatefulWidget {
  final String code;
  final String language;

  const _SearchableCodeView({required this.code, required this.language});

  @override
  State<_SearchableCodeView> createState() => _SearchableCodeViewState();
}

class _SearchableCodeViewState extends State<_SearchableCodeView> {
  bool _isSearchVisible = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  int _currentMatchIndex = 0;
  List<int> _matchPositions = [];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SearchableCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _updateMatches();
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (_isSearchVisible) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _searchFocusNode.requestFocus();
        });
      } else {
        _searchQuery = '';
        _searchController.clear();
        _matchPositions = [];
        _currentMatchIndex = 0;
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _currentMatchIndex = 0;
      _updateMatches();
    });
  }

  void _updateMatches() {
    if (_searchQuery.isEmpty) {
      _matchPositions = [];
      return;
    }

    _matchPositions = [];
    final lowerCode = widget.code.toLowerCase();
    final lowerQuery = _searchQuery.toLowerCase();
    int index = 0;

    while (true) {
      index = lowerCode.indexOf(lowerQuery, index);
      if (index == -1) break;
      _matchPositions.add(index);
      index += lowerQuery.length;
    }
  }

  void _goToNextMatch() {
    if (_matchPositions.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchPositions.length;
    });
  }

  void _goToPreviousMatch() {
    if (_matchPositions.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _matchPositions.length) %
          _matchPositions.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Search bar (collapsible)
        if (_isSearchVisible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    onSubmitted: (_) => _goToNextMatch(),
                  ),
                ),
                if (_matchPositions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${_currentMatchIndex + 1}/${_matchPositions.length}',
                    style: theme.textTheme.bodySmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                    onPressed: _goToPreviousMatch,
                    tooltip: 'Previous match',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    onPressed: _goToNextMatch,
                    tooltip: 'Next match',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ] else if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    'No matches',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _toggleSearch,
                  tooltip: 'Close search',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),
        // Code view
        Expanded(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  child: _buildHighlightedText(theme),
                ),
              ),
              // Toolbar buttons
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToolbarButton(
                      icon: Icons.search,
                      tooltip: 'Search (Ctrl+F)',
                      isActive: _isSearchVisible,
                      onPressed: _toggleSearch,
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: Icons.copy,
                      tooltip: 'Copy to clipboard',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightedText(ThemeData theme) {
    if (_searchQuery.isEmpty || _matchPositions.isEmpty) {
      return SelectableText(
        widget.code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: theme.colorScheme.onSurface,
        ),
      );
    }

    // Build text spans with highlights
    final spans = <TextSpan>[];
    int lastEnd = 0;
    final lowerQuery = _searchQuery.toLowerCase();

    for (int i = 0; i < _matchPositions.length; i++) {
      final matchStart = _matchPositions[i];
      final matchEnd = matchStart + lowerQuery.length;

      // Add text before this match
      if (matchStart > lastEnd) {
        spans.add(TextSpan(text: widget.code.substring(lastEnd, matchStart)));
      }

      // Add highlighted match
      final isCurrentMatch = i == _currentMatchIndex;
      spans.add(
        TextSpan(
          text: widget.code.substring(matchStart, matchEnd),
          style: TextStyle(
            backgroundColor: isCurrentMatch
                ? Colors.orange.withValues(alpha: 0.6)
                : Colors.yellow.withValues(alpha: 0.4),
            color: theme.colorScheme.onSurface,
          ),
        ),
      );

      lastEnd = matchEnd;
    }

    // Add remaining text
    if (lastEnd < widget.code.length) {
      spans.add(TextSpan(text: widget.code.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: theme.colorScheme.onSurface,
        ),
        children: spans,
      ),
    );
  }
}

/// Toolbar button widget
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isActive
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 16,
              color: isActive
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
