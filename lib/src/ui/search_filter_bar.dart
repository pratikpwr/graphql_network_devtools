import 'package:flutter/material.dart';

import '../models/graphql_operation.dart';

/// Search and filter bar for GraphQL operations.
class SearchFilterBar extends StatelessWidget {
  final String searchQuery;
  final Set<GraphQLOperationType> typeFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Set<GraphQLOperationType>> onTypeFilterChanged;

  const SearchFilterBar({
    super.key,
    required this.searchQuery,
    required this.typeFilters,
    required this.onSearchChanged,
    required this.onTypeFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by operation name or query...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => onSearchChanged(''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: onSearchChanged,
                controller: TextEditingController(text: searchQuery)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: searchQuery.length),
                  ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Type filters
          _buildTypeFilterChip(
            context,
            theme,
            GraphQLOperationType.query,
            'Query',
            Colors.blue,
          ),
          const SizedBox(width: 4),
          _buildTypeFilterChip(
            context,
            theme,
            GraphQLOperationType.mutation,
            'Mutation',
            Colors.orange,
          ),
          const SizedBox(width: 4),
          _buildTypeFilterChip(
            context,
            theme,
            GraphQLOperationType.subscription,
            'Subscription',
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip(
    BuildContext context,
    ThemeData theme,
    GraphQLOperationType type,
    String label,
    Color color,
  ) {
    final isSelected = typeFilters.contains(type);

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : color,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      checkmarkColor: Colors.white,
      onSelected: (selected) {
        final newFilters = Set<GraphQLOperationType>.from(typeFilters);
        if (selected) {
          newFilters.add(type);
        } else {
          newFilters.remove(type);
        }
        onTypeFilterChanged(newFilters);
      },
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

