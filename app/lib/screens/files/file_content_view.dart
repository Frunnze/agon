import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/code_view.dart';
import 'package:agent_orchestration/screens/files/file_frames.dart';
import 'package:agent_orchestration/screens/files/file_kinds.dart';
import 'package:agent_orchestration/screens/files/image_preview.dart';
import 'package:agent_orchestration/screens/files/markdown_view.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';
import 'package:agent_orchestration/screens/files/unavailable_preview.dart';

class FileContentView extends StatelessWidget {
  const FileContentView({
    required this.file,
    required this.repositoryPath,
    super.key,
  });

  final RepositoryFile file;
  final String repositoryPath;

  @override
  Widget build(BuildContext context) {
    final String name = fileNameOf(file.path);

    switch (file.preview) {
      case TextFilePreview(:final String text):
        return _buildText(name, text);
      case ImageFilePreview(:final Uint8List bytes):
        return ImagePreview(bytes: bytes, name: name);
      case UnavailableFilePreview(:final PreviewUnavailableReason reason):
        return UnavailablePreview(
          fileName: name,
          reason: reason,
          repositoryPath: repositoryPath,
        );
    }
  }

  Widget _buildText(String name, String text) {
    switch (chooseTextViewer(name)) {
      case TextViewer.markdown:
        return FileFrame(child: MarkdownView(text: text));
      case TextViewer.code:
        return CodeView(text: text, language: findSyntaxLanguageFor(name));
      case TextViewer.plain:
        return CodeView(text: text, language: null);
    }
  }
}
