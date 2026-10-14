import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'network_controller.dart';
import 'profile_source.dart';
import 'support/zoom.dart';
import 'ui/network_screen.dart';

const _httpLoggingExtension = 'ext.dart.io.httpEnableTimelineLogging';

/// The root widget of the GraphQL Network DevTools extension.
class GraphQLNetworkApp extends StatelessWidget {
  const GraphQLNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: _ConnectedHome());
  }
}

class _ConnectedHome extends StatefulWidget {
  const _ConnectedHome();

  @override
  State<_ConnectedHome> createState() => _ConnectedHomeState();
}

class _ConnectedHomeState extends State<_ConnectedHome> {
  late final _controller = NetworkController(
    VmServiceProfileSource(serviceManager),
  );
  final _zoom = ZoomController();
  final _connection = ValueNotifier(AppConnection.connecting);
  int _connectionGeneration = 0;

  @override
  void initState() {
    super.initState();
    // The browser menu cannot copy text that Flutter draws. Use the Flutter
    // menu, which copies through DevTools.
    if (kIsWeb) unawaited(BrowserContextMenu.disableContextMenu());
    serviceManager.connectedState.addListener(_onConnectionChanged);
    unawaited(_onConnectionChanged());
  }

  @override
  void dispose() {
    serviceManager.connectedState.removeListener(_onConnectionChanged);
    _controller.dispose();
    _zoom.dispose();
    _connection.dispose();
    super.dispose();
  }

  Future<void> _onConnectionChanged() async {
    final generation = ++_connectionGeneration;
    if (!serviceManager.connectedState.value.connected) {
      _controller.stop();
      _connection.value = AppConnection.disconnected;
      return;
    }

    var isWebApp = false;
    try {
      isWebApp = await serviceManager.connectedApp?.isDartWebApp ?? false;
    } catch (_) {
      // Assume a native app. The poll shows an error if it is not.
    }
    if (generation != _connectionGeneration || !mounted) return;

    if (isWebApp) {
      _controller.stop();
      _connection.value = AppConnection.webApp;
      return;
    }

    _connection.value = AppConnection.connected;
    _controller
      ..resetConnection()
      ..start();
    unawaited(_keepHttpLoggingOn());
  }

  /// Asks DevTools to keep HTTP logging on. DevTools turns it on again in
  /// new isolates, for example after a hot restart, before the first poll.
  Future<void> _keepHttpLoggingOn() async {
    try {
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        _httpLoggingExtension,
        enabled: true,
        value: true,
      );
    } catch (_) {
      // The controller also turns logging on in each isolate.
    }
  }

  @override
  Widget build(BuildContext context) {
    return NetworkScreen(
      controller: _controller,
      zoom: _zoom,
      connection: _connection,
    );
  }
}
