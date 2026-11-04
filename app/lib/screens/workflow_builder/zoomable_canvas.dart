import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

const double _wheelPixelsPerScaleFactor = 200;
const double _unchangedPinchScale = 1;
const double _buttonsInset = AppSpacing.space3;

const Set<PointerDeviceKind> canvasDragDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.unknown,
};

class ZoomableCanvas extends StatefulWidget {
  const ZoomableCanvas({
    required this.view,
    required this.diagramBounds,
    required this.child,
    super.key,
  });

  final ValueNotifier<CanvasView> view;
  final Rect diagramBounds;
  final Widget child;

  @override
  State<ZoomableCanvas> createState() => _ZoomableCanvasState();
}

class _ZoomableCanvasState extends State<ZoomableCanvas> {
  double _pinchScaleSoFar = _unchangedPinchScale;

  @override
  Widget build(BuildContext context) {
    return CanvasFrame(child: LayoutBuilder(builder: _buildViewport));
  }

  Widget _buildViewport(BuildContext context, BoxConstraints limits) {
    final Size viewport = limits.biggest;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerSignal: _receivePointerSignal,
            onPointerPanZoomStart: _startPinch,
            onPointerPanZoomUpdate: _continuePinch,
            child: ClipRect(
              child: ValueListenableBuilder<CanvasView>(
                valueListenable: widget.view,
                builder: _buildPlacedCanvas,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 0,
                  minHeight: 0,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: _buttonsInset,
          bottom: _buttonsInset,
          child: CanvasZoomButtons(
            onZoomOut: () => _zoomAtCentre(viewport, -CanvasZoom.buttonStep),
            onZoomIn: () => _zoomAtCentre(viewport, CanvasZoom.buttonStep),
            onFit: () => _fitNodes(viewport),
          ),
        ),
      ],
    );
  }

  Widget _buildPlacedCanvas(
    BuildContext context,
    CanvasView view,
    Widget? canvas,
  ) {
    final Matrix4 placement = Matrix4.translationValues(
      view.offset.dx,
      view.offset.dy,
      0,
    );
    placement.scaleByDouble(view.scale, view.scale, 1, 1);

    return Transform(transform: placement, child: canvas);
  }

  void _receivePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(
        event,
        _scrollWithWheel,
      );
    }
  }

  void _scrollWithWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    _scrollAt(pointer: event.localPosition, scrollDelta: event.scrollDelta);
  }

  void _startPinch(PointerPanZoomStartEvent _) {
    _pinchScaleSoFar = _unchangedPinchScale;
  }

  void _continuePinch(PointerPanZoomUpdateEvent event) {
    final double pinchStep = event.scale / _pinchScaleSoFar;
    _pinchScaleSoFar = event.scale;

    final CanvasView view = widget.view.value;
    widget.view.value = zoomCanvasView(
      view: view,
      focus: event.localPosition,
      scale: view.scale * pinchStep,
    );

    _scrollAt(pointer: event.localPosition, scrollDelta: -event.panDelta);
  }

  void _scrollAt({required Offset pointer, required Offset scrollDelta}) {
    final CanvasView view = widget.view.value;
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isZoomKeyPressed =
        keyboard.isControlPressed || keyboard.isMetaPressed;

    if (!isZoomKeyPressed) {
      widget.view.value = panCanvasView(view: view, delta: -scrollDelta);
      return;
    }

    final double wheelZoom = exp(-scrollDelta.dy / _wheelPixelsPerScaleFactor);
    widget.view.value = zoomCanvasView(
      view: view,
      focus: pointer,
      scale: view.scale * wheelZoom,
    );
  }

  void _zoomAtCentre(Size viewport, double scaleStep) {
    final CanvasView view = widget.view.value;
    widget.view.value = zoomCanvasView(
      view: view,
      focus: viewport.center(Offset.zero),
      scale: view.scale + scaleStep,
    );
  }

  void _fitNodes(Size viewport) {
    widget.view.value = fitCanvasView(
      diagramBounds: widget.diagramBounds,
      viewport: viewport,
    );
  }
}
