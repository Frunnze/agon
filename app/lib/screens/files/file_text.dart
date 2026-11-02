import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/screens/files/file_kinds.dart';
import 'package:agent_orchestration/screens/files/file_sizes.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';
import 'package:agent_orchestration/screens/files/text_lines.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _partSeparator = ' · ';
const String _dimensionSeparator = ' × ';
const String _viewerSentence =
    'The viewer shows code, images, Markdown and plain text.';

String describeFileDetails(RepositoryFile file) {
  final String size = describeFileSize(file.size);

  switch (file.preview) {
    case TextFilePreview(:final String text):
      if (chooseTextViewer(fileNameOf(file.path)) == TextViewer.markdown) {
        return size;
      }
      final String lines = describeCount(
        splitTextLines(text).length,
        singular: 'line',
        plural: 'lines',
      );
      return '$lines$_partSeparator$size';
    case ImageFilePreview(:final int width, :final int height):
      return '$width$_dimensionSeparator$height$_partSeparator$size';
    case UnavailableFilePreview():
      return size;
  }
}

List<TextSegment> describeFileSummary({
  required String branch,
  required RepositoryFile file,
}) {
  return <TextSegment>[
    TextSegment.monospace(branch),
    TextSegment('$_partSeparator${describeFileDetails(file)}'),
  ];
}

String describeUnavailablePreview({
  required String fileName,
  required PreviewUnavailableReason reason,
}) {
  final String? knownKind = describeKnownFileKind(fileName);
  if (knownKind != null) {
    return '$_viewerSentence This file is $knownKind.';
  }

  final String reasonSentence = switch (reason) {
    PreviewUnavailableReason.tooLarge => 'This file is too large to preview.',
    PreviewUnavailableReason.binary => 'This file is not text.',
    PreviewUnavailableReason.link => 'This file is a link.',
  };
  return '$_viewerSentence $reasonSentence';
}

String describeOwnCloneHint(String repositoryPath) {
  return 'Copy its path to find it in your own clone of $repositoryPath.';
}
