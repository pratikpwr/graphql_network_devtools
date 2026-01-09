import 'package:flutter/material.dart';

import '../models/graphql_operation.dart';
import 'operation_details_panel.dart';
import 'operation_list.dart';
import 'search_filter_bar.dart';

/// Main screen for the GraphQL Network extension.
class GraphQLNetworkScreen extends StatelessWidget {
  final List<GraphQLOperation> operations;
  final GraphQLOperation? selectedOperation;
  final String searchQuery;
  final Set<GraphQLOperationType> typeFilters;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onClear;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Set<GraphQLOperationType>> onTypeFilterChanged;
  final ValueChanged<GraphQLOperation?> onOperationSelected;

  const GraphQLNetworkScreen({
    super.key,
    required this.operations,
    required this.selectedOperation,
    required this.searchQuery,
    required this.typeFilters,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onClear,
    required this.onSearchChanged,
    required this.onTypeFilterChanged,
    required this.onOperationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Toolbar
        _buildToolbar(context, theme),
        const Divider(height: 1),
        // Search and filter bar
        SearchFilterBar(
          searchQuery: searchQuery,
          typeFilters: typeFilters,
          onSearchChanged: onSearchChanged,
          onTypeFilterChanged: onTypeFilterChanged,
        ),
        const Divider(height: 1),
        // Main content
        Expanded(child: _buildContent(context, theme)),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.hub, size: 20),
          const SizedBox(width: 8),
          Text(
            'GraphQL Network',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${operations.length} operations',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: isLoading ? null : onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Clear all',
            onPressed: onClear,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error loading operations',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRefresh,
            ),
          ],
        ),
      );
    }

    if (isLoading && operations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (operations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No GraphQL operations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Make some GraphQL requests in your app to see them here',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Split view: list on left, details on right
    return Row(
      children: [
        // Operation list
        SizedBox(
          width: 400,
          child: OperationList(
            operations: operations,
            selectedOperation: selectedOperation,
            onOperationSelected: onOperationSelected,
          ),
        ),
        const VerticalDivider(width: 1),
        // Details panel
        Expanded(
          child: selectedOperation != null
              ? OperationDetailsPanel(operation: selectedOperation!)
              : Center(
                  child: Text(
                    'Select an operation to view details',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
