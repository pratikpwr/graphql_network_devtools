import 'package:devtools_app_shared/ui.dart' show SplitPane;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network_controller.dart';
import '../support/zoom.dart';
import 'details_panel.dart';
import 'operation_list.dart';
import 'styles.dart';
import 'toolbar.dart';
import 'widgets/common.dart';

/// The state of the connection to the app under debug.
enum AppConnection { connecting, connected, disconnected, webApp }

class _FocusFilterIntent extends Intent {
  const _FocusFilterIntent();
}

/// The main screen. It has no DevTools dependencies, so tests can use it
/// with a fake [NetworkController].
class NetworkScreen extends StatelessWidget {
  const NetworkScreen({
    super.key,
    required this.controller,
    required this.zoom,
    required this.connection,
  });

  final NetworkController controller;
  final ZoomController zoom;
  final ValueListenable<AppConnection> connection;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: extensionTheme(Theme.of(context)),
      child: ZoomedView(
        controller: zoom,
        child: _NetworkBody(
          controller: controller,
          zoom: zoom,
          connection: connection,
        ),
      ),
    );
  }
}

class _NetworkBody extends StatefulWidget {
  const _NetworkBody({
    required this.controller,
    required this.zoom,
    required this.connection,
  });

  final NetworkController controller;
  final ZoomController zoom;
  final ValueListenable<AppConnection> connection;

  @override
  State<_NetworkBody> createState() => _NetworkBodyState();
}

class _NetworkBodyState extends State<_NetworkBody> {
  final _searchFocus = FocusNode(debugLabel: 'filter');

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _FocusFilterIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _FocusFilterIntent(),
      },
      child: Actions(
        actions: {
          _FocusFilterIntent: CallbackAction<_FocusFilterIntent>(
            onInvoke: (_) => _searchFocus.requestFocus(),
          ),
        },
        child: Material(
          color: theme.colorScheme.surface,
          child: DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium,
            child: ListenableBuilder(
              listenable: Listenable.merge([
                widget.controller,
                widget.connection,
              ]),
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Toolbar(
                    controller: widget.controller,
                    zoom: widget.zoom,
                    searchFocus: _searchFocus,
                  ),
                  if (widget.controller.pollError != null)
                    _Banner(
                      message:
                          'Could not read HTTP traffic from the app: '
                          '${widget.controller.pollError}',
                    ),
                  if (!widget.controller.isRecording)
                    const _Banner(
                      message:
                          'Recording is paused. New requests are not '
                          'captured.',
                      icon: Icons.pause_circle_outline,
                    ),
                  Expanded(child: _buildContent(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final controller = widget.controller;
    switch (widget.connection.value) {
      case AppConnection.connecting:
        return const Center(child: CircularProgressIndicator());
      case AppConnection.webApp:
        return const EmptyState(
          icon: Icons.web_asset_off,
          title: 'Web apps are not supported',
          message:
              'GraphQL Network reads the Dart VM HTTP profile. That profile '
              'exists on Android, iOS, macOS, Windows and Linux, but not in '
              'a browser. Use the browser network panel for web apps.',
        );
      case AppConnection.disconnected:
        if (controller.allOperations.isEmpty) {
          return const EmptyState(
            icon: Icons.link_off,
            title: 'No app is connected',
            message:
                'Run your app in debug or profile mode, then connect '
                'DevTools to it.',
          );
        }
      case AppConnection.connected:
        break;
    }

    if (controller.allOperations.isEmpty) {
      return const EmptyState(
        icon: Icons.hub_outlined,
        title: 'Waiting for GraphQL requests',
        message:
            'Use your app to send a GraphQL request. It shows here within '
            'a second.\n\nThe app records HTTP traffic only after this tab '
            'turns recording on. To capture requests that run at app start, '
            'set HttpClient.enableTimelineLogging = true in main().',
      );
    }

    final list = controller.operations.isEmpty
        ? EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'No operations match the filters',
            action: OutlinedButton(
              onPressed: controller.clearFilters,
              child: const Text('Reset filters'),
            ),
          )
        : OperationList(controller: controller);

    final selected = controller.selected;
    final details = selected == null
        ? const EmptyState(
            icon: Icons.ads_click,
            title: 'Select an operation',
            message:
                'Click an operation to see its query, variables, response '
                'and headers. Use the Up and Down keys to move.',
          )
        : DetailsPanel(operation: selected);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 720;
        return SplitPane(
          key: ValueKey(horizontal),
          axis: horizontal ? Axis.horizontal : Axis.vertical,
          initialFractions: horizontal ? const [0.36, 0.64] : const [0.4, 0.6],
          minSizes: horizontal ? const [260, 360] : const [120, 200],
          children: [list, details],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, this.icon = Icons.warning_amber});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
