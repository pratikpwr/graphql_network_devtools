import 'package:flutter/material.dart';

import '../models/graphql_operation.dart';

/// List view of GraphQL operations.
class OperationList extends StatelessWidget {
  final List<GraphQLOperation> operations;
  final GraphQLOperation? selectedOperation;
  final ValueChanged<GraphQLOperation?> onOperationSelected;

  const OperationList({
    super.key,
    required this.operations,
    required this.selectedOperation,
    required this.onOperationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: operations.length,
      itemBuilder: (context, index) {
        final operation = operations[index];
        final isSelected = selectedOperation?.id == operation.id;

        return OperationListTile(
          operation: operation,
          isSelected: isSelected,
          onTap: () => onOperationSelected(operation),
        );
      },
    );
  }
}

/// Individual operation list tile.
class OperationListTile extends StatelessWidget {
  final GraphQLOperation operation;
  final bool isSelected;
  final VoidCallback onTap;

  const OperationListTile({
    super.key,
    required this.operation,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            // Operation type badge
            _buildTypeBadge(theme),
            const SizedBox(width: 8),
            // Operation info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Operation name
                  Text(
                    operation.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Timestamp and duration
                  Text(
                    _formatTimestamp(operation.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status and duration
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusBadge(theme),
                const SizedBox(height: 2),
                Text(
                  operation.durationDisplay,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(ThemeData theme) {
    final color = _getTypeColor(operation.type);
    final label = _getTypeLabel(operation.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    final color = _getStatusColor(operation);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        operation.statusDisplay,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
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

  String _getTypeLabel(GraphQLOperationType type) {
    switch (type) {
      case GraphQLOperationType.query:
        return 'Q';
      case GraphQLOperationType.mutation:
        return 'M';
      case GraphQLOperationType.subscription:
        return 'S';
      case GraphQLOperationType.unknown:
        return '?';
    }
  }

  Color _getStatusColor(GraphQLOperation operation) {
    if (operation.statusCode == null) return Colors.grey;
    if (operation.hasErrors) return Colors.red;
    if (operation.isSuccess) return Colors.green;
    if (operation.statusCode! >= 400) return Colors.red;
    return Colors.orange;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }

    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
