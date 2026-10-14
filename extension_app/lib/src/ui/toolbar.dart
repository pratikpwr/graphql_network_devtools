import 'dart:async';

import 'package:flutter/material.dart';
import 'package:graphql_network_devtools/graphql_network_devtools.dart';

import '../network_controller.dart';
import '../support/zoom.dart';
import 'styles.dart';

/// The top bar: title, recording, clear, filters and zoom.
class Toolbar extends StatelessWidget {
  const Toolbar({
    super.key,
    required this.controller,
    required this.zoom,
    required this.searchFocus,
  });

  final NetworkController controller;
  final ZoomController zoom;
  final FocusNode searchFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = controller.allOperations.length;
    final visible = controller.operations.length;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: borderSide(theme)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.hub_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text('GraphQL Network', style: theme.textTheme.titleSmall),
              const SizedBox(width: 12),
              _RecordButton(controller: controller),
              IconButton(
                tooltip: 'Clear all operations',
                icon: const Icon(Icons.block, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: total == 0
                    ? null
                    : () => unawaited(controller.clear()),
              ),
              const Spacer(),
              Text(
                controller.hasFilters ? '$visible of $total' : '$total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                total == 1 ? ' operation' : ' operations',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              _ZoomControls(zoom: zoom),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: _SearchField(
                  controller: controller,
                  focusNode: searchFocus,
                ),
              ),
              for (final type in const [
                GraphQLOperationType.query,
                GraphQLOperationType.mutation,
                GraphQLOperationType.subscription,
              ])
                _FilterChip(
                  label: type.label,
                  count: controller.countOf(type),
                  color: typeColor(theme, type),
                  selected: controller.types.contains(type),
                  onSelected: (_) => controller.toggleType(type),
                ),
              _FilterChip(
                label: 'Errors',
                count: controller.errorCount,
                color: errorColor(theme),
                selected: controller.errorsOnly,
                onSelected: controller.setErrorsOnly,
              ),
              if (controller.hasFilters)
                TextButton(
                  onPressed: controller.clearFilters,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Reset filters'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.controller});

  final NetworkController controller;

  @override
  Widget build(BuildContext context) {
    final recording = controller.isRecording;
    final color = recording
        ? errorColor(Theme.of(context))
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return IconButton(
      tooltip: recording
          ? 'Pause recording. New requests are not captured.'
          : 'Resume recording',
      icon: Icon(
        recording ? Icons.fiber_manual_record : Icons.play_arrow_rounded,
        size: 18,
        color: color,
      ),
      visualDensity: VisualDensity.compact,
      onPressed: () => controller.setRecording(!recording),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller, required this.focusNode});

  final NetworkController controller;
  final FocusNode focusNode;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _text = TextEditingController(text: widget.controller.searchText);

  @override
  void didUpdateWidget(_SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in sync when the filters are reset from elsewhere.
    if (_text.text != widget.controller.searchText) {
      _text.text = widget.controller.searchText;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _text,
      focusNode: widget.focusNode,
      onChanged: widget.controller.setSearchText,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Filter by name, query, URL or variables',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        prefixIcon: const Icon(Icons.filter_list, size: 18),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        suffixIcon: _text.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear filter',
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _text.clear();
                  widget.controller.setSearchText('');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text('$label  $count'),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected ? color : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      avatar: selected
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: color,
      selectedColor: color.withValues(alpha: 0.16),
      side: BorderSide(
        color: selected ? color.withValues(alpha: 0.6) : borderColor(theme),
      ),
      visualDensity: VisualDensity.compact,
      onSelected: onSelected,
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.zoom});

  final ZoomController zoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: zoom,
      builder: (context, _, _) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor(theme)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Zoom out (Ctrl/Cmd + -)',
              icon: const Icon(Icons.text_decrease, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: zoom.canZoomOut ? zoom.zoomOut : null,
            ),
            Tooltip(
              message: 'Reset zoom (Ctrl/Cmd + 0)',
              child: InkWell(
                onTap: zoom.reset,
                child: SizedBox(
                  width: 44,
                  child: Text(
                    zoom.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Zoom in (Ctrl/Cmd + +)',
              icon: const Icon(Icons.text_increase, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: zoom.canZoomIn ? zoom.zoomIn : null,
            ),
          ],
        ),
      ),
    );
  }
}
