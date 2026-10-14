import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_network_devtools/graphql_network_devtools.dart';

import '../network_controller.dart';
import 'styles.dart';
import 'widgets/common.dart';

const _rowHeight = 54.0;

/// The list of captured operations. Up and Down move the selection.
class OperationList extends StatefulWidget {
  const OperationList({super.key, required this.controller});

  final NetworkController controller;

  @override
  State<OperationList> createState() => _OperationListState();
}

class _OperationListState extends State<OperationList> {
  final _scrollController = ScrollController();
  final _focusNode = FocusNode(debugLabel: 'operation list');

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    if (delta == 0) return KeyEventResult.ignored;
    widget.controller.moveSelection(delta);
    _reveal();
    return KeyEventResult.handled;
  }

  void _reveal() {
    final operations = widget.controller.operations;
    final index = operations.indexWhere(
      (o) => o.id == widget.controller.selected?.id,
    );
    if (index == -1 || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final top = index * _rowHeight;
    final bottom = top + _rowHeight;
    if (top < position.pixels) {
      _scrollController.jumpTo(top);
    } else if (bottom > position.pixels + position.viewportDimension) {
      _scrollController.jumpTo(bottom - position.viewportDimension);
    }
  }

  @override
  Widget build(BuildContext context) {
    final operations = widget.controller.operations;
    final selectedId = widget.controller.selected?.id;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Scrollbar(
        controller: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          itemExtent: _rowHeight,
          itemCount: operations.length,
          itemBuilder: (context, index) {
            final operation = operations[index];
            return _OperationRow(
              operation: operation,
              selected: operation.id == selectedId,
              onTap: () {
                _focusNode.requestFocus();
                widget.controller.select(operation);
              },
            );
          },
        ),
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.operation,
    required this.selected,
    required this.onTap,
  });

  final GraphQLOperation operation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isError = switch (operation.status) {
      GraphQLOperationStatus.success || GraphQLOperationStatus.pending => false,
      _ => true,
    };
    final uri = operation.uri;

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 3,
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
              ),
              bottom: BorderSide(
                color: borderColor(theme).withValues(alpha: 0.7),
              ),
            ),
          ),
          child: Row(
            children: [
              TypeBadge(type: operation.type),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            operation.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isError ? errorColor(theme) : null,
                            ),
                          ),
                        ),
                        if (operation.isBatched) ...[
                          const SizedBox(width: 6),
                          Pill(
                            label:
                                'batch ${operation.batchIndex + 1}/${operation.batchSize}',
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatTime(operation.startTime)} · ${uri.host}${uri.path}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(operation: operation),
                  const SizedBox(height: 4),
                  Text(formatDuration(operation.duration), style: muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
