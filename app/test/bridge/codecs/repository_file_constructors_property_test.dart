import 'support/codec_rows.dart';
import 'support/repository_file_codec_rows.dart';
import 'support/repository_preview_codec_rows.dart';

const int _firstSeed = 9360000;
const int _firstPreviewSeed = 9365000;

void main() {
  testConstructorRows(
    rows: repositoryFileConstructorRows,
    firstSeed: _firstSeed,
  );
  testConstructorRows(
    rows: repositoryPreviewConstructorRows,
    firstSeed: _firstPreviewSeed,
  );
}
