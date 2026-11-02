import 'package:flutter/widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/pairing_invitation.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

const double _qrCodeExtent = 192;

class PairingQrCode extends StatelessWidget {
  const PairingQrCode({required this.invitation, super.key});

  final PairingInvitation invitation;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: encodePairingInvitation(invitation),
      size: _qrCodeExtent,
      padding: const EdgeInsets.all(AppSpacing.space3),
      backgroundColor: AppColors.onFill,
      semanticsLabel: 'QR code for ${invitation.code}',
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.paper,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.paper,
      ),
    );
  }
}
