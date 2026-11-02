final class SyntaxLanguage {
  const SyntaxLanguage({
    required this.keywords,
    required this.stringDelimiters,
  });

  final Set<String> keywords;
  final Set<String> stringDelimiters;
}

const Set<String> _doubleQuoteOnly = <String>{'"'};
const Set<String> _bothQuotes = <String>{'"', "'"};
const String _wordSeparator = ' ';

Set<String> _splitWords(String words) {
  return Set<String>.unmodifiable(words.split(_wordSeparator));
}

final SyntaxLanguage _scriptLanguage = SyntaxLanguage(
  stringDelimiters: <String>{'"', "'", '`'},
  keywords: _splitWords(
    'any as async await boolean break case catch class const '
    'continue default delete do else enum export extends false '
    'finally for from function if implements import in '
    'instanceof interface let new null number of private '
    'protected public readonly return static string super '
    'switch this throw true try type typeof undefined unknown '
    'var void while yield',
  ),
);

final SyntaxLanguage _dartLanguage = SyntaxLanguage(
  stringDelimiters: _bothQuotes,
  keywords: _splitWords(
    'abstract as async await bool break case catch class const '
    'continue default do double dynamic else enum export '
    'extends extension factory false final finally for get if '
    'implements import in int interface is late mixin new null '
    'num required return sealed set static String super switch '
    'this throw true try var void while with yield',
  ),
);

final SyntaxLanguage _rustLanguage = SyntaxLanguage(
  stringDelimiters: _doubleQuoteOnly,
  keywords: _splitWords(
    'as async await bool break const continue crate dyn else '
    'enum false fn for if impl in let loop match mod move mut '
    'pub ref return self Self static str struct super trait '
    'true type unsafe use where while',
  ),
);

final SyntaxLanguage _pythonLanguage = SyntaxLanguage(
  stringDelimiters: _bothQuotes,
  keywords: _splitWords(
    'and as assert async await break class continue def del '
    'elif else except False finally for from global if import '
    'in is lambda None nonlocal not or pass raise return self '
    'True try while with yield',
  ),
);

final SyntaxLanguage _goLanguage = SyntaxLanguage(
  stringDelimiters: <String>{'"', '`'},
  keywords: _splitWords(
    'bool break case chan const continue default defer else '
    'error false for func go if import int interface map nil '
    'package range return select string struct switch true type '
    'var',
  ),
);

final SyntaxLanguage _jvmLanguage = SyntaxLanguage(
  stringDelimiters: _doubleQuoteOnly,
  keywords: _splitWords(
    'abstract boolean break case catch class continue data '
    'default do double else enum extends false final finally '
    'for fun if implements import int interface long new null '
    'object override package private protected public return '
    'static super switch this throw true try val var void when '
    'while',
  ),
);

final SyntaxLanguage _swiftLanguage = SyntaxLanguage(
  stringDelimiters: _doubleQuoteOnly,
  keywords: _splitWords(
    'as break case catch class continue default defer do else '
    'enum extension false for func guard if import in init '
    'internal is let nil private protocol public return self '
    'static struct super switch throw throws true try var where '
    'while',
  ),
);

final SyntaxLanguage _cFamilyLanguage = SyntaxLanguage(
  stringDelimiters: _bothQuotes,
  keywords: _splitWords(
    'auto bool break case catch char class const continue '
    'default delete do double else enum extern false float for '
    'if include inline int long namespace new nullptr private '
    'protected public return short sizeof static struct switch '
    'template this throw true try typedef union unsigned using '
    'virtual void while',
  ),
);

final SyntaxLanguage _rubyLanguage = SyntaxLanguage(
  stringDelimiters: _bothQuotes,
  keywords: _splitWords(
    'and begin break case class def do else elsif end ensure '
    'false for if in module next nil not or require rescue '
    'return self super then true unless until when while yield',
  ),
);

final SyntaxLanguage _shellLanguage = SyntaxLanguage(
  stringDelimiters: _bothQuotes,
  keywords: _splitWords(
    'case do done echo elif else esac exit export fi for '
    'function if in local return set then until while',
  ),
);

final SyntaxLanguage _jsonLanguage = SyntaxLanguage(
  stringDelimiters: _doubleQuoteOnly,
  keywords: _splitWords('true false null'),
);

final SyntaxLanguage _settingsLanguage = SyntaxLanguage(
  stringDelimiters: _bothQuotes,
  keywords: _splitWords('true false null'),
);

final Map<String, SyntaxLanguage> _languagesByExtension =
    <String, SyntaxLanguage>{
      'ts': _scriptLanguage,
      'tsx': _scriptLanguage,
      'js': _scriptLanguage,
      'jsx': _scriptLanguage,
      'mjs': _scriptLanguage,
      'cjs': _scriptLanguage,
      'dart': _dartLanguage,
      'rs': _rustLanguage,
      'py': _pythonLanguage,
      'go': _goLanguage,
      'java': _jvmLanguage,
      'kt': _jvmLanguage,
      'kts': _jvmLanguage,
      'swift': _swiftLanguage,
      'c': _cFamilyLanguage,
      'h': _cFamilyLanguage,
      'cc': _cFamilyLanguage,
      'cpp': _cFamilyLanguage,
      'hpp': _cFamilyLanguage,
      'cs': _cFamilyLanguage,
      'm': _cFamilyLanguage,
      'rb': _rubyLanguage,
      'sh': _shellLanguage,
      'bash': _shellLanguage,
      'zsh': _shellLanguage,
      'json': _jsonLanguage,
      'yaml': _settingsLanguage,
      'yml': _settingsLanguage,
      'toml': _settingsLanguage,
    };

SyntaxLanguage? findSyntaxLanguage(String extension) {
  return _languagesByExtension[extension];
}
