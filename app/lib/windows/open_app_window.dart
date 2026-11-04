import 'package:agent_orchestration/windows/app_window_page.dart';
import 'package:agent_orchestration/windows/native_windows.dart';

final class OpenAppWindow {
  const OpenAppWindow({required this.page, required this.nativeWindow});

  final AppWindowPage page;
  final NativeWindow nativeWindow;
}
