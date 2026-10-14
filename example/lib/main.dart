import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'graphql_client.dart';
import 'scenarios.dart';

void main() {
  // Optional: record HTTP traffic from the first frame. Without this line,
  // the app records traffic only after you open the GraphQL tab in DevTools.
  if (kDebugMode) HttpClient.enableTimelineLogging = true;

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GraphQL Network DevTools demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFE10098)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFE10098),
        brightness: Brightness.dark,
      ),
      home: const ScenarioPage(),
    );
  }
}

class ScenarioPage extends StatefulWidget {
  const ScenarioPage({super.key});

  @override
  State<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<ScenarioPage> {
  final _results = <Scenario, _RunState>{};

  Future<void> _run(Scenario scenario) async {
    setState(() => _results[scenario] = const _RunState.running());
    _RunState state;
    try {
      state = _RunState.done(await scenario.run());
    } catch (error) {
      state = _RunState.failed('$error');
    }
    if (mounted) setState(() => _results[scenario] = state);
  }

  Future<void> _runAll() async {
    await Future.wait(scenarios.map(_run));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GraphQL Network demo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_runAll()),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Run all'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const _HowTo(),
          for (final scenario in scenarios)
            _ScenarioCard(
              scenario: scenario,
              state: _results[scenario],
              onRun: () => unawaited(_run(scenario)),
            ),
        ],
      ),
    );
  }
}

class _HowTo extends StatelessWidget {
  const _HowTo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to use this demo', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              '1. Open Flutter DevTools for this app.\n'
              '2. Open the "graphql_network_devtools" tab. If DevTools asks, '
              'enable the extension.\n'
              '3. Tap Run on a card below, or tap Run all.\n'
              '4. Select an operation in DevTools to see its query, '
              'variables, response and headers.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.state,
    required this.onRun,
  });

  final Scenario scenario;
  final _RunState? state;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(scenario.icon),
        title: Text(scenario.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scenario.description),
            if (state != null) ...[
              const SizedBox(height: 6),
              _ResultLine(state: state!),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: FilledButton.tonal(
          onPressed: state?.isRunning == true ? null : onRun,
          child: state?.isRunning == true
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : const Text('Run'),
        ),
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.state});

  final _RunState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = state.result;
    final String text;
    final Color color;
    if (state.isRunning) {
      text = 'Running…';
      color = theme.colorScheme.onSurfaceVariant;
    } else if (state.error != null) {
      text = 'Failed: ${state.error}';
      color = theme.colorScheme.error;
    } else if (result!.hasErrors || result.statusCode >= 400) {
      text =
          'HTTP ${result.statusCode} with errors · '
          '${result.duration.inMilliseconds} ms';
      color = theme.colorScheme.error;
    } else {
      text = 'HTTP ${result.statusCode} · ${result.duration.inMilliseconds} ms';
      color = Colors.green.shade700;
    }
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(color: color),
    );
  }
}

class _RunState {
  const _RunState.running() : result = null, error = null, isRunning = true;

  const _RunState.done(GraphQLResult this.result)
    : error = null,
      isRunning = false;

  const _RunState.failed(String this.error) : result = null, isRunning = false;

  final GraphQLResult? result;
  final String? error;
  final bool isRunning;
}
