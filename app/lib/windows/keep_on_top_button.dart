import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/windows/native_windows.dart';

const String keepOnTopLabel = 'Keep on top';
const String stopKeepingOnTopLabel = 'Stop keeping on top';

class KeepOnTopButton extends StatefulWidget {
  const KeepOnTopButton({required this.onTopSwitch, super.key});

  final OnTopSwitch onTopSwitch;

  @override
  State<KeepOnTopButton> createState() => _KeepOnTopButtonState();
}

class _KeepOnTopButtonState extends State<KeepOnTopButton> {
  bool _isKeptOnTop = false;

  @override
  Widget build(BuildContext context) {
    if (_isKeptOnTop) {
      return AppButton.primary(
        label: stopKeepingOnTopLabel,
        icon: AppIconKind.pin,
        onPressed: _stopKeepingOnTop,
      );
    }
    return AppButton.secondary(
      label: keepOnTopLabel,
      icon: AppIconKind.pin,
      onPressed: _keepOnTop,
    );
  }

  void _keepOnTop() {
    widget.onTopSwitch.keepOnTop();
    setState(() {
      _isKeptOnTop = true;
    });
  }

  void _stopKeepingOnTop() {
    widget.onTopSwitch.stopKeepingOnTop();
    setState(() {
      _isKeptOnTop = false;
    });
  }
}
