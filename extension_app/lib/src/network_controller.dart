import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:graphql_network_devtools/graphql_network_devtools.dart';

import 'profile_source.dart';

/// Holds the captured GraphQL operations and the filter and selection state.
///
/// The controller polls the [HttpProfileSource] while it runs. Each poll
/// asks only for the requests that changed since the previous poll, and
/// loads bodies only for requests that can be GraphQL.
class NetworkController extends ChangeNotifier {
  NetworkController(
    this._source, {
    this.pollInterval = const Duration(seconds: 1),
  });

  final HttpProfileSource _source;

  /// The time between two polls.
  final Duration pollInterval;

  /// Operations by transaction key. A batch request has many operations.
  final _byTransaction = <String, List<GraphQLOperation>>{};

  /// Keys of complete requests that are not GraphQL, or that arrived while
  /// recording was paused.
  final _ignored = <String>{};

  final _lastProfileTime = <String, DateTime>{};
  final _loggingEnabled = <String>{};

  Timer? _timer;
  bool _polling = false;

  List<GraphQLOperation> _all = const [];
  List<GraphQLOperation> _visible = const [];

  /// All captured operations, newest first.
  List<GraphQLOperation> get allOperations => _all;

  /// The operations that match the filters, newest first.
  List<GraphQLOperation> get operations => _visible;

  String _searchText = '';
  String get searchText => _searchText;

  Set<GraphQLOperationType> _types = const {};

  /// The selected operation types. An empty set shows all types.
  Set<GraphQLOperationType> get types => _types;

  bool _errorsOnly = false;

  /// Whether the list shows only failed operations.
  bool get errorsOnly => _errorsOnly;

  bool _recording = true;

  /// Whether new requests are captured.
  bool get isRecording => _recording;

  bool get isRunning => _timer != null;

  String? _pollError;

  /// The last error from the connected app, if the last poll failed.
  String? get pollError => _pollError;

  bool get hasFilters =>
      _searchText.isNotEmpty || _types.isNotEmpty || _errorsOnly;

  String? _selectedId;

  /// The selected operation. It stays selected when filters hide it.
  GraphQLOperation? get selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final operation in _all) {
      if (operation.id == id) return operation;
    }
    return null;
  }

  /// Starts to poll. It is safe to call this when the controller runs.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    unawaited(refresh());
  }

  /// Stops polling. The captured operations stay.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Forgets per-isolate state, for example after the app restarts.
  ///
  /// The captured operations stay, so you can compare runs.
  void resetConnection() {
    _lastProfileTime.clear();
    _loggingEnabled.clear();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Reads new and changed requests from the app.
  Future<void> refresh() async {
    if (_polling) return;
    _polling = true;
    var changed = false;
    String? error;

    try {
      final isolates = await _source.isolateIds();
      for (final isolateId in isolates) {
        if (_loggingEnabled.add(isolateId)) {
          try {
            await _source.enableLogging(isolateId);
          } catch (_) {
            // The isolate can be paused or not have dart:io yet. Retry on the
            // next poll.
            _loggingEnabled.remove(isolateId);
          }
        }

        final ProfileSnapshot snapshot;
        try {
          snapshot = await _source.fetchProfile(
            isolateId,
            updatedSince: _lastProfileTime[isolateId],
          );
        } catch (_) {
          continue;
        }
        _lastProfileTime[isolateId] = snapshot.timestamp;

        for (final entry in snapshot.entries) {
          if (await _update(isolateId, entry)) changed = true;
        }
      }
    } catch (e) {
      error = '$e';
    } finally {
      _polling = false;
    }

    if (error != _pollError) {
      _pollError = error;
      changed = true;
    }
    if (changed) _rebuild();
  }

  /// Updates one request. Returns whether the operation list changed.
  Future<bool> _update(String isolateId, ProfileEntry entry) async {
    final summary = entry.summary;
    final key = summary.id;
    if (_ignored.contains(key)) return false;

    final known = _byTransaction.containsKey(key);
    if (!known && !_recording) {
      _ignored.add(key);
      return false;
    }
    if (!mightBeGraphQL(summary)) {
      // The VM adds the request headers when the request is sent. Wait for
      // them before the request is ignored.
      if (summary.requestHeaders.isEmpty && !summary.isComplete) return false;
      _ignored.add(key);
      return false;
    }

    final HttpTransaction full;
    try {
      full = await _source.fetchRequest(isolateId, entry.requestId);
    } catch (_) {
      return false;
    }

    final operations = parseGraphQLOperations(full);
    if (operations.isEmpty) {
      if (full.isComplete) _ignored.add(key);
      return _byTransaction.remove(key) != null;
    }
    _byTransaction[key] = operations;
    return true;
  }

  /// Deletes all captured operations, in the app and in this view.
  Future<void> clear() async {
    try {
      for (final isolateId in await _source.isolateIds()) {
        try {
          await _source.clear(isolateId);
        } catch (_) {
          // The isolate can exit while we clear it.
        }
      }
    } catch (_) {
      // Not connected. Clear the local list only.
    }
    _byTransaction.clear();
    _ignored.clear();
    _selectedId = null;
    _rebuild();
  }

  void setSearchText(String value) {
    if (value == _searchText) return;
    _searchText = value;
    _applyFilters();
  }

  void toggleType(GraphQLOperationType type) {
    final next = {..._types};
    if (!next.remove(type)) next.add(type);
    _types = next;
    _applyFilters();
  }

  void setErrorsOnly(bool value) {
    if (value == _errorsOnly) return;
    _errorsOnly = value;
    _applyFilters();
  }

  void clearFilters() {
    _searchText = '';
    _types = const {};
    _errorsOnly = false;
    _applyFilters();
  }

  void setRecording(bool value) {
    if (value == _recording) return;
    _recording = value;
    notifyListeners();
  }

  void select(GraphQLOperation? operation) {
    if (operation?.id == _selectedId) return;
    _selectedId = operation?.id;
    notifyListeners();
  }

  /// Moves the selection by [delta] rows in the visible list.
  void moveSelection(int delta) {
    if (_visible.isEmpty) return;
    final index = _visible.indexWhere((o) => o.id == _selectedId);
    final next = index == -1
        ? (delta > 0 ? 0 : _visible.length - 1)
        : (index + delta).clamp(0, _visible.length - 1);
    select(_visible[next]);
  }

  /// The number of captured operations of [type].
  int countOf(GraphQLOperationType type) =>
      _all.where((o) => o.type == type).length;

  /// The number of captured operations that failed.
  int get errorCount => _all.where(_isError).length;

  void _rebuild() {
    final all = [for (final list in _byTransaction.values) ...list]
      ..sort((a, b) {
        final byTime = b.startTime.compareTo(a.startTime);
        return byTime != 0 ? byTime : a.batchIndex.compareTo(b.batchIndex);
      });
    _all = List.unmodifiable(all);
    _applyFilters();
  }

  void _applyFilters() {
    final search = _searchText.trim().toLowerCase();
    _visible = List.unmodifiable(
      _all.where((operation) {
        if (_types.isNotEmpty && !_types.contains(operation.type)) {
          return false;
        }
        if (_errorsOnly && !_isError(operation)) return false;
        if (search.isEmpty) return true;
        return operation.displayName.toLowerCase().contains(search) ||
            (operation.document?.toLowerCase().contains(search) ?? false) ||
            operation.uri.toString().toLowerCase().contains(search) ||
            _variablesText(operation).contains(search);
      }),
    );
    notifyListeners();
  }

  static bool _isError(GraphQLOperation operation) =>
      switch (operation.status) {
        GraphQLOperationStatus.graphQLError ||
        GraphQLOperationStatus.httpError ||
        GraphQLOperationStatus.failed => true,
        _ => false,
      };

  static String _variablesText(GraphQLOperation operation) {
    final variables = operation.variables;
    if (variables == null) return '';
    try {
      return jsonEncode(variables).toLowerCase();
    } catch (_) {
      return '';
    }
  }
}
