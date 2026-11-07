final RegExp _controlCharacter = RegExp(r'[\u0000-\u001f\u007f-\u009f]');

bool hasControlCharacter(String text) => text.contains(_controlCharacter);
