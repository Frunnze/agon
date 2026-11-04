import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const int mouseDevice = 1;

MouseCursor? readMouseCursor() {
  return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(
    mouseDevice,
  );
}

Future<TestGesture> hoverMouseAt(WidgetTester tester, Offset location) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: mouseDevice,
  );
  await mouse.addPointer(location: location);
  await mouse.moveTo(location);
  await tester.pump();
  return mouse;
}

Future<MouseCursor?> readCursorOver(
  WidgetTester tester,
  Offset location,
) async {
  final TestGesture mouse = await hoverMouseAt(tester, location);
  final MouseCursor? hoveredCursor = readMouseCursor();

  await mouse.removePointer();
  await tester.pump();
  return hoveredCursor;
}
