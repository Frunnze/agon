import 'package:agent_orchestration/screens/files/syntax_languages.dart';

enum TextViewer { markdown, code, plain }

const String _extensionSeparator = '.';
const String _noExtension = '';
const Set<String> _markdownExtensions = <String>{'md', 'markdown'};
const Map<String, String> _knownFileKinds = <String, String>{
  'mp4': 'a video',
  'mov': 'a video',
  'webm': 'a video',
  'mkv': 'a video',
  'avi': 'a video',
  'mp3': 'an audio file',
  'wav': 'an audio file',
  'ogg': 'an audio file',
  'flac': 'an audio file',
  'm4a': 'an audio file',
  'zip': 'an archive',
  'tar': 'an archive',
  'gz': 'an archive',
  'tgz': 'an archive',
  '7z': 'an archive',
  'rar': 'an archive',
  'pdf': 'a PDF',
};

String readFileExtension(String fileName) {
  final int separatorIndex = fileName.lastIndexOf(_extensionSeparator);
  if (separatorIndex <= 0) {
    return _noExtension;
  }
  return fileName.substring(separatorIndex + 1).toLowerCase();
}

SyntaxLanguage? findSyntaxLanguageFor(String fileName) {
  return findSyntaxLanguage(readFileExtension(fileName));
}

TextViewer chooseTextViewer(String fileName) {
  final String extension = readFileExtension(fileName);
  if (_markdownExtensions.contains(extension)) {
    return TextViewer.markdown;
  }
  if (findSyntaxLanguage(extension) != null) {
    return TextViewer.code;
  }
  return TextViewer.plain;
}

String? describeKnownFileKind(String fileName) {
  return _knownFileKinds[readFileExtension(fileName)];
}
