import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

const String zoomOutLabel = '−';
const String zoomInLabel = '+';
const String fitLabel = 'Fit';

class CanvasZoomButtons extends StatelessWidget {
  const CanvasZoomButtons({
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onFit,
    super.key,
  });

  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.space1,
      children: <Widget>[
        Semantics(
          label: 'Zoom out',
          child: AppButton.secondary(
            label: zoomOutLabel,
            onPressed: onZoomOut,
          ),
        ),
        Semantics(
          label: 'Zoom in',
          child: AppButton.secondary(label: zoomInLabel, onPressed: onZoomIn),
        ),
        AppButton.secondary(label: fitLabel, onPressed: onFit),
      ],
    );
  }
}
