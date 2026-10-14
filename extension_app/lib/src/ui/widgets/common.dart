import 'dart:async';

import 'package:flutter/material.dart';
import 'package:graphql_network_devtools/graphql_network_devtools.dart';

import '../../support/clipboard.dart';
import '../styles.dart';

/// A [SelectionArea] whose copy goes through DevTools.
///
/// The default copy action of Flutter calls `Clipboard.setData`, which an
/// IDE web view blocks. This widget sends Ctrl+C, Cmd+C and the context
/// menu "Copy" item to [copyText] instead.
class CopyableSelectionArea extends StatefulWidget {
  const CopyableSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  State<CopyableSelectionArea> createState() => _CopyableSelectionAreaState();
}

class _CopyableSelectionAreaState extends State<CopyableSelectionArea> {
  String _selectedText = '';

  void _copySelection() {
    if (_selectedText.isEmpty) return;
    unawaited(copyText(_selectedText));
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
          onInvoke: (_) => _copySelection(),
        ),
      },
      child: SelectionArea(
        onSelectionChanged: (content) =>
            _selectedText = content?.plainText ?? '',
        contextMenuBuilder: (context, state) {
          final items = [
            for (final item in state.contextMenuButtonItems)
              if (item.type == ContextMenuButtonType.copy)
                item.copyWith(
                  onPressed: () {
                    _copySelection();
                    state.hideToolbar();
                  },
                )
              else
                item,
          ];
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: state.contextMenuAnchors,
            buttonItems: items,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// An icon button that copies text and shows a check mark for a moment.
class CopyButton extends StatefulWidget {
  const CopyButton({
    super.key,
    required this.text,
    this.tooltip = 'Copy',
    this.label,
    this.message,
    this.dense = false,
  });

  /// Returns the text to copy. It runs on tap, so large text is only built
  /// when it is necessary.
  final String Function() text;
  final String tooltip;

  /// If set, the button shows this label next to the icon.
  final String? label;

  /// The message that DevTools shows after the copy.
  final String? message;
  final bool dense;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _copy() {
    unawaited(
      copyText(widget.text(), message: widget.message ?? 'Copied to clipboard'),
    );
    _timer?.cancel();
    setState(() => _copied = true);
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = Icon(
      _copied ? Icons.check : Icons.copy_rounded,
      size: widget.dense ? 14 : 16,
      color: _copied ? successColor(theme) : null,
    );
    final tooltip = _copied ? 'Copied' : widget.tooltip;

    if (widget.label != null) {
      return Tooltip(
        message: tooltip,
        child: OutlinedButton.icon(
          onPressed: _copy,
          icon: icon,
          label: Text(_copied ? 'Copied' : widget.label!),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: theme.textTheme.labelLarge,
          ),
        ),
      );
    }
    return IconButton(
      onPressed: _copy,
      tooltip: tooltip,
      icon: icon,
      visualDensity: VisualDensity.compact,
      constraints: widget.dense
          ? const BoxConstraints(minWidth: 24, minHeight: 24)
          : null,
      padding: widget.dense ? EdgeInsets.zero : null,
    );
  }
}

/// A small rounded label with a tinted background.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: FontSizes.badge,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A square badge with the first letter of the operation type.
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type});

  final GraphQLOperationType type;

  @override
  Widget build(BuildContext context) {
    final color = typeColor(Theme.of(context), type);
    return Tooltip(
      message: type.label,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          typeLetter(type),
          style: TextStyle(
            color: color,
            fontSize: FontSizes.badge,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// A status pill, for example `200` or `200 · 2 errors`.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.operation});

  final GraphQLOperation operation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = operation.status;
    if (status == GraphQLOperationStatus.pending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Pill(label: 'Pending', color: theme.colorScheme.onSurfaceVariant),
        ],
      );
    }
    return Pill(
      label: statusLabel(operation),
      color: statusColor(theme, status),
      icon: status == GraphQLOperationStatus.success
          ? null
          : Icons.error_outline,
    );
  }
}

/// A centered message with an icon, a title and optional details.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: muted.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// A thin header bar above a content area, with a title and actions.
class SectionBar extends StatelessWidget {
  const SectionBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.showTopBorder = false,
  });

  final String title;
  final String? subtitle;

  /// If set, it shows in place of [title].
  final Widget? leading;
  final List<Widget> actions;

  /// Draws a line above the bar, to separate it from content above.
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: EdgeInsets.only(left: leading == null ? 12 : 8, right: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: showTopBorder ? borderSide(theme) : BorderSide.none,
          bottom: borderSide(theme),
        ),
      ),
      child: Row(
        children: [
          // The title side takes all free space, so the actions stay at the
          // right edge.
          Expanded(
            child: Row(
              children: [
                leading ??
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// An outlined box with rounded corners around one area of the screen, the
/// same way DevTools draws its own panes. An optional [header] shows above
/// [child], with a line between them.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.header});

  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: borderColor(theme)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: header == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header!,
                Expanded(child: child),
              ],
            ),
    );
  }
}
