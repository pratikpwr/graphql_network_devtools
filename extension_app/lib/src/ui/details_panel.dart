import 'package:flutter/material.dart';
import 'package:graphql_network_devtools/graphql_network_devtools.dart';

import '../support/settings.dart';
import 'code_view.dart';
import 'json_tree.dart';
import 'styles.dart';
import 'syntax.dart';
import 'widgets/common.dart';

const _responseViewKey = 'responseView';

/// Shows the selected operation: a summary header and tabs for the query,
/// the variables, the response and the headers.
class DetailsPanel extends StatefulWidget {
  const DetailsPanel({super.key, required this.operation});

  final GraphQLOperation operation;

  @override
  State<DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<DetailsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  bool _treeView = readSetting(_responseViewKey) != 'raw';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _setTreeView(bool value) {
    setState(() => _treeView = value);
    writeSetting(_responseViewKey, value ? 'tree' : 'raw');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final operation = widget.operation;
    final errorCount = operation.errors.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(operation: operation),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: theme.textTheme.labelLarge,
            dividerHeight: 0,
            tabs: [
              const Tab(height: 36, text: 'Query'),
              const Tab(height: 36, text: 'Variables'),
              Tab(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Response'),
                    if (errorCount > 0) ...[
                      const SizedBox(width: 6),
                      Pill(label: '$errorCount', color: errorColor(theme)),
                    ],
                  ],
                ),
              ),
              const Tab(height: 36, text: 'Headers'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            // Swipes between tabs would fight with text selection.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QueryTab(operation: operation),
              _VariablesTab(operation: operation),
              _ResponseTab(
                operation: operation,
                treeView: _treeView,
                onTreeViewChanged: _setTreeView,
              ),
              _HeadersTab(transaction: operation.transaction),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.operation});

  final GraphQLOperation operation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final transaction = operation.transaction;

    Widget fact(IconData icon, String text, {String? tooltip}) {
      final child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text, style: muted),
        ],
      );
      return tooltip == null ? child : Tooltip(message: tooltip, child: child);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: CopyableSelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SelectionContainer.disabled(
                  child: Pill(
                    label: operation.type.label.toUpperCase(),
                    color: typeColor(theme, operation.type),
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    operation.displayName,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SelectionContainer.disabled(
                  child: StatusPill(operation: operation),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${operation.method} ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '${operation.uri}'),
                ],
              ),
              style: muted?.copyWith(fontFamily: codeFontFamily),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SelectionContainer.disabled(
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  fact(
                    Icons.timer_outlined,
                    formatDuration(operation.duration),
                    tooltip: 'Duration',
                  ),
                  fact(
                    Icons.download_outlined,
                    formatBytes(operation.responseSize),
                    tooltip: 'Response size',
                  ),
                  fact(
                    Icons.schedule,
                    formatTime(operation.startTime),
                    tooltip: 'Start time',
                  ),
                  if (operation.isBatched)
                    fact(
                      Icons.layers_outlined,
                      'Batch ${operation.batchIndex + 1} of ${operation.batchSize}',
                    ),
                  if (operation.isPersistedQuery)
                    fact(
                      Icons.tag,
                      'Persisted query',
                      tooltip: operation.persistedQueryHash,
                    ),
                ],
              ),
            ),
            if (transaction.error != null) ...[
              const SizedBox(height: 8),
              Text(
                transaction.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: errorColor(theme),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SelectionContainer.disabled(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CopyButton(
                    label: 'cURL',
                    tooltip: 'Copy as cURL command',
                    message: 'Copied cURL command',
                    text: () => toCurlCommand(transaction),
                  ),
                  CopyButton(
                    label: 'Request',
                    tooltip: 'Copy the GraphQL request as JSON',
                    message: 'Copied request JSON',
                    text: () => jsonText(operation.toRequestJson()),
                  ),
                  CopyButton(
                    label: 'Response',
                    tooltip: 'Copy the full response body',
                    message: 'Copied response',
                    text: () => _responseText(operation),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _responseText(GraphQLOperation operation) {
  if (operation.response != null) return jsonText(operation.response);
  return operation.transaction.responseBody ?? '';
}

class _QueryTab extends StatelessWidget {
  const _QueryTab({required this.operation});

  final GraphQLOperation operation;

  @override
  Widget build(BuildContext context) {
    final document = operation.document;
    if (document == null && !operation.isPersistedQuery) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: 'No query text',
        message:
            'The request failed before the app recorded its body.\n'
            '${operation.transaction.error ?? ''}',
      );
    }
    if (document == null) {
      return EmptyState(
        icon: Icons.tag,
        title: 'Persisted query',
        message:
            'The client sent only the query hash, not the query text.\n'
            'Hash: ${operation.persistedQueryHash ?? 'unknown'}',
      );
    }
    final formatted = formatGraphQL(document);
    return CodeView(
      title: 'Query',
      subtitle: '${'\n'.allMatches(formatted).length + 1} lines',
      code: formatted,
      language: CodeLanguage.graphql,
      copyTooltip: 'Copy query',
      copyMessage: 'Copied query',
    );
  }
}

class _VariablesTab extends StatelessWidget {
  const _VariablesTab({required this.operation});

  final GraphQLOperation operation;

  @override
  Widget build(BuildContext context) {
    final variables = operation.variables;
    final extensions = operation.extensions;
    final hasVariables =
        variables != null && !(variables is Map && variables.isEmpty);

    if (!hasVariables && extensions == null) {
      return const EmptyState(
        icon: Icons.data_object,
        title: 'No variables',
        message: 'This operation was sent without variables.',
      );
    }
    final value = {
      if (hasVariables) 'variables': variables,
      'extensions': ?extensions,
    };
    return CodeView(
      title: hasVariables ? 'Variables' : 'Extensions',
      subtitle: extensions != null && hasVariables
          ? 'With the request extensions'
          : null,
      code: jsonText(hasVariables && extensions == null ? variables : value),
      language: CodeLanguage.json,
      copyTooltip: 'Copy variables',
      copyMessage: 'Copied variables',
    );
  }
}

class _ResponseTab extends StatelessWidget {
  const _ResponseTab({
    required this.operation,
    required this.treeView,
    required this.onTreeViewChanged,
  });

  final GraphQLOperation operation;
  final bool treeView;
  final ValueChanged<bool> onTreeViewChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = operation.transaction.responseBody;
    if (operation.status == GraphQLOperationStatus.pending && body == null) {
      return const EmptyState(
        icon: Icons.hourglass_empty,
        title: 'Waiting for the response',
      );
    }
    if (body == null && operation.response == null) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No response body',
        message: operation.transaction.error,
      );
    }

    final isJson = operation.response != null;
    final toggle = SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: true,
          label: Text('Tree'),
          icon: Icon(Icons.account_tree_outlined, size: 16),
        ),
        ButtonSegment(
          value: false,
          label: Text('Raw'),
          icon: Icon(Icons.code, size: 16),
        ),
      ],
      selected: {treeView && isJson},
      showSelectedIcon: false,
      onSelectionChanged: isJson ? (v) => onTreeViewChanged(v.first) : null,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: theme.textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (operation.hasErrors) _ErrorList(errors: operation.errors),
        Expanded(
          child: treeView && isJson
              ? JsonTreeView(value: operation.response, headerLeading: toggle)
              : CodeView(
                  title: 'Response',
                  headerLeading: toggle,
                  subtitle: isJson
                      ? formatBytes(operation.responseSize)
                      : 'Not JSON · ${formatBytes(operation.responseSize)}',
                  code: _responseText(operation),
                  language: isJson ? CodeLanguage.json : CodeLanguage.plain,
                  copyTooltip: 'Copy response',
                  copyMessage: 'Copied response',
                ),
        ),
      ],
    );
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.errors});

  final List<GraphQLError> errors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = errorColor(theme);
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.3))),
      ),
      child: CopyableSelectionArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  errors.length == 1
                      ? '1 GraphQL error'
                      : '${errors.length} GraphQL errors',
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
                const Spacer(),
                SelectionContainer.disabled(
                  child: CopyButton(
                    tooltip: 'Copy errors as JSON',
                    message: 'Copied errors',
                    text: () => jsonText([for (final e in errors) e.raw]),
                  ),
                ),
              ],
            ),
            for (final error in errors)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: error.message,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (error.pathDisplay != null)
                        TextSpan(text: '  at ${error.pathDisplay}'),
                      if (error.code != null)
                        TextSpan(text: '  [${error.code}]'),
                      if (error.locations?.isNotEmpty ?? false)
                        TextSpan(
                          text:
                              '  (line ${error.locations!.first.line}, '
                              'column ${error.locations!.first.column})',
                        ),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeadersTab extends StatelessWidget {
  const _HeadersTab({required this.transaction});

  final HttpTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return CopyableSelectionArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _HeaderSection(
            title: 'Request headers',
            headers: transaction.requestHeaders,
          ),
          _HeaderSection(
            title: 'Response headers',
            headers: transaction.responseHeaders,
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.title, required this.headers});

  final String title;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = headers.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectionContainer.disabled(
          child: SectionBar(
            title: title,
            subtitle: '${entries.length}',
            actions: [
              if (entries.isNotEmpty)
                CopyButton(
                  tooltip: 'Copy all ${title.toLowerCase()}',
                  message: 'Copied headers',
                  text: () =>
                      entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                ),
            ],
          ),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'None',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(flex: 0.4),
                1: FlexColumnWidth(),
              },
              children: [
                for (final entry in entries)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16, bottom: 6),
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFamily: codeFontFamily,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          entry.value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: codeFontFamily,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
