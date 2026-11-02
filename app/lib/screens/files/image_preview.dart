import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/files/file_frames.dart';

const double _largestImageWidth = 256;

class ImagePreview extends StatelessWidget {
  const ImagePreview({required this.bytes, required this.name, super.key});

  final Uint8List bytes;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ImageFrame(
      child: Image.memory(
        bytes,
        width: _largestImageWidth,
        semanticLabel: name,
        fit: BoxFit.contain,
        errorBuilder: _buildUnreadableImage,
      ),
    );
  }

  Widget _buildUnreadableImage(
    BuildContext context,
    Object problem,
    StackTrace? stackTrace,
  ) {
    return const SizedBox.shrink();
  }
}
