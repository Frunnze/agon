import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';

class SpinningBox extends StatefulWidget {
  const SpinningBox({required this.child, super.key});

  final Widget child;

  @override
  State<SpinningBox> createState() => _SpinningBoxState();
}

class _SpinningBoxState extends State<SpinningBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: AppDurations.spin,
  );

  @override
  void initState() {
    super.initState();
    _rotation.repeat().ignore();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _rotation, child: widget.child);
  }
}
