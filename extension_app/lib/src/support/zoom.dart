import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings.dart';

const _zoomKey = 'zoom';

/// The UI zoom level of the extension. `1.0` is 100 %.
///
/// The value is saved, so it stays after DevTools reloads.
class ZoomController extends ValueNotifier<double> {
  ZoomController() : super(_load());

  static const double minZoom = 0.7;
  static const double maxZoom = 2.0;
  static const double step = 0.1;

  void zoomIn() => _set(value + step);

  void zoomOut() => _set(value - step);

  void reset() => _set(1.0);

  bool get canZoomIn => value < maxZoom - 0.001;

  bool get canZoomOut => value > minZoom + 0.001;

  /// The zoom level as a percentage, for example `110%`.
  String get label => '${(value * 100).round()}%';

  void _set(double zoom) {
    final next = (zoom.clamp(minZoom, maxZoom) * 10).round() / 10;
    if (next == value) return;
    value = next;
    writeSetting(_zoomKey, '$next');
  }

  static double _load() {
    final saved = double.tryParse(readSetting(_zoomKey) ?? '');
    if (saved == null) return 1.0;
    return saved.clamp(minZoom, maxZoom);
  }
}

class ZoomInIntent extends Intent {
  const ZoomInIntent();
}

class ZoomOutIntent extends Intent {
  const ZoomOutIntent();
}

class ZoomResetIntent extends Intent {
  const ZoomResetIntent();
}

/// Keyboard shortcuts for zoom: Ctrl or Cmd with `+`, `-` and `0`.
final Map<ShortcutActivator, Intent> zoomShortcuts = {
  for (final modifier in [true, false]) ...{
    SingleActivator(
      LogicalKeyboardKey.equal,
      control: modifier,
      meta: !modifier,
    ): const ZoomInIntent(),
    SingleActivator(
      LogicalKeyboardKey.equal,
      control: modifier,
      meta: !modifier,
      shift: true,
    ): const ZoomInIntent(),
    SingleActivator(LogicalKeyboardKey.add, control: modifier, meta: !modifier):
        const ZoomInIntent(),
    SingleActivator(
      LogicalKeyboardKey.numpadAdd,
      control: modifier,
      meta: !modifier,
    ): const ZoomInIntent(),
    SingleActivator(
      LogicalKeyboardKey.minus,
      control: modifier,
      meta: !modifier,
    ): const ZoomOutIntent(),
    SingleActivator(
      LogicalKeyboardKey.numpadSubtract,
      control: modifier,
      meta: !modifier,
    ): const ZoomOutIntent(),
    SingleActivator(
      LogicalKeyboardKey.digit0,
      control: modifier,
      meta: !modifier,
    ): const ZoomResetIntent(),
    SingleActivator(
      LogicalKeyboardKey.numpad0,
      control: modifier,
      meta: !modifier,
    ): const ZoomResetIntent(),
  },
};

/// Scales [child] by the zoom level of [controller].
///
/// The whole UI scales, also icons, spacing, tooltips and menus, the same
/// way as browser zoom. The child gets an [Overlay] of its own inside the
/// scaled area, so tooltips, menus and the text selection toolbar scale too.
class ZoomedView extends StatefulWidget {
  const ZoomedView({super.key, required this.controller, required this.child});

  final ZoomController controller;
  final Widget child;

  @override
  State<ZoomedView> createState() => _ZoomedViewState();
}

class _ZoomedViewState extends State<ZoomedView> {
  late final OverlayEntry _entry = OverlayEntry(
    builder: (context) => widget.child,
  );

  @override
  void didUpdateWidget(ZoomedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: zoomShortcuts,
      child: Actions(
        actions: {
          ZoomInIntent: CallbackAction<ZoomInIntent>(
            onInvoke: (_) => widget.controller.zoomIn(),
          ),
          ZoomOutIntent: CallbackAction<ZoomOutIntent>(
            onInvoke: (_) => widget.controller.zoomOut(),
          ),
          ZoomResetIntent: CallbackAction<ZoomResetIntent>(
            onInvoke: (_) => widget.controller.reset(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: ValueListenableBuilder<double>(
            valueListenable: widget.controller,
            builder: (context, zoom, overlay) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth / zoom,
                    constraints.maxHeight / zoom,
                  );
                  // A tight box makes FittedBox fill the space and scale the
                  // smaller child up to it.
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.fill,
                        alignment: Alignment.topLeft,
                        child: SizedBox.fromSize(
                          size: size,
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(size: size),
                            child: overlay!,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            child: Overlay(initialEntries: [_entry]),
          ),
        ),
      ),
    );
  }
}
