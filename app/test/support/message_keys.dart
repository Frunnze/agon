import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Set<TargetPlatform> computerPlatforms = <TargetPlatform>{
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
};
const Set<TargetPlatform> phonePlatforms = <TargetPlatform>{
  TargetPlatform.android,
  TargetPlatform.iOS,
};
final List<TargetPlatform> computerPlatformList = computerPlatforms.toList();
final List<TargetPlatform> phonePlatformList = phonePlatforms.toList();
final List<TargetPlatform> everyPlatformList = <TargetPlatform>[
  ...computerPlatformList,
  ...phonePlatformList,
];

const TargetPlatformVariant onComputers = TargetPlatformVariant(
  computerPlatforms,
);

Future<bool> pressEnter(WidgetTester tester) async {
  final bool isHandled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
  return isHandled;
}

Future<bool> pressShiftEnter(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  final bool isHandled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
  return isHandled;
}
