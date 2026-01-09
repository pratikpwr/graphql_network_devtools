import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'models/graphql_operation.dart';
import 'services/http_profile_service.dart';
import 'ui/graphql_network_screen.dart';

/// The service extension name for enabling HTTP timeline logging.
const _httpEnableTimelineLogging = 'ext.dart.io.httpEnableTimelineLogging';

/// The service extension name for enabling socket profiling.
const _socketProfilingEnabled = 'ext.dart.io.socketProfilingEnabled';

/// Main entry point for the GraphQL Network DevTools extension.
class GraphQLNetworkExtension extends StatelessWidget {
  const GraphQLNetworkExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: _GraphQLExtensionBody());
  }
}

class _GraphQLExtensionBody extends StatefulWidget {
  const _GraphQLExtensionBody();

  @override
  State<_GraphQLExtensionBody> createState() => _GraphQLExtensionBodyState();
}

class _GraphQLExtensionBodyState extends State<_GraphQLExtensionBody> {
  HttpProfileService? _httpProfileService;
  List<GraphQLOperation> _operations = [];
  GraphQLOperation? _selectedOperation;
  String _searchQuery = '';
  Set<GraphQLOperationType> _typeFilters = {};
  bool _isLoading = false;
  String? _error;

  Timer? _refreshTimer;
  static const _refreshInterval = Duration(seconds: 2);

  /// Listener for connection state changes to re-enable profiling.
  void Function()? _connectionStateListener;

  @override
  void initState() {
    super.initState();
    _initServices();
    _startAutoRefresh();
    _setupConnectionListener();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_connectionStateListener != null) {
      serviceManager.connectedState.removeListener(_connectionStateListener!);
    }
    super.dispose();
  }

  /// Sets up a listener for connection state changes to re-enable HTTP profiling
  /// after hot restarts or reconnections.
  void _setupConnectionListener() {
    _connectionStateListener = () {
      final state = serviceManager.connectedState.value;
      if (state.connected) {
        // Re-enable HTTP profiling when connection is established
        _enableHttpProfiling();
      }
    };
    serviceManager.connectedState.addListener(_connectionStateListener!);
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _fetchOperations(silent: true);
    });
  }

  void _initServices() {
    try {
      _httpProfileService = HttpProfileService(serviceManager);

      // Enable HTTP profiling using the ServiceExtensionManager
      _enableHttpProfiling();

      _fetchOperations();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  /// Enables HTTP timeline logging using the ServiceExtensionManager.
  ///
  /// This properly handles isolate lifecycle, paused isolates, and ensures
  /// the extension is called on all isolates (not just the main one).
  Future<void> _enableHttpProfiling() async {
    try {
      final extensionManager = serviceManager.serviceExtensionManager;

      // Enable HTTP timeline logging - this is required for HTTP profile to capture requests.
      // Using ServiceExtensionManager ensures proper handling of:
      // - Isolate lifecycle (waits for isolates to be ready)
      // - Paused isolates (queues callback until resumed)
      // - All isolates (calls on all isolates, not just main)
      // - State persistence (restores after hot restart)
      await extensionManager.setServiceExtensionState(
        _httpEnableTimelineLogging,
        enabled: true,
        value: true,
      );

      // Also enable socket profiling for complete network visibility
      await extensionManager.setServiceExtensionState(
        _socketProfilingEnabled,
        enabled: true,
        value: true,
      );
    } catch (e) {
      // Ignore errors - extensions might not be available
    }
  }

  Future<void> _fetchOperations({bool silent = false}) async {
    if (_isLoading) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final operations = <GraphQLOperation>[];

      if (_httpProfileService != null) {
        final httpOps = await _httpProfileService!.getGraphQLOperations();
        operations.addAll(httpOps);
      }

      // Sort by timestamp, newest first
      operations.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Only update if there are changes
      if (_operationsChanged(operations)) {
        setState(() {
          _operations = operations;
          if (!silent) _isLoading = false;
        });
      } else if (!silent) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!silent) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool _operationsChanged(List<GraphQLOperation> newOps) {
    if (newOps.length != _operations.length) return true;
    for (var i = 0; i < newOps.length; i++) {
      if (newOps[i].id != _operations[i].id) return true;
    }
    return false;
  }

  Future<void> _clearOperations() async {
    await _httpProfileService?.clearProfile();
    setState(() {
      _operations = [];
      _selectedOperation = null;
    });
  }

  List<GraphQLOperation> get _filteredOperations {
    var filtered = _operations;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((op) {
        return op.displayName.toLowerCase().contains(query) ||
            op.query.toLowerCase().contains(query) ||
            (op.operationName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_typeFilters.isNotEmpty) {
      filtered = filtered
          .where((op) => _typeFilters.contains(op.type))
          .toList();
    }

    return filtered;
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
  }

  void _onTypeFilterChanged(Set<GraphQLOperationType> types) {
    setState(() => _typeFilters = types);
  }

  void _onOperationSelected(GraphQLOperation? operation) {
    setState(() => _selectedOperation = operation);
  }

  @override
  Widget build(BuildContext context) {
    return GraphQLNetworkScreen(
      operations: _filteredOperations,
      selectedOperation: _selectedOperation,
      searchQuery: _searchQuery,
      typeFilters: _typeFilters,
      isLoading: _isLoading,
      error: _error,
      onRefresh: _fetchOperations,
      onClear: _clearOperations,
      onSearchChanged: _onSearchChanged,
      onTypeFilterChanged: _onTypeFilterChanged,
      onOperationSelected: _onOperationSelected,
    );
  }
}
