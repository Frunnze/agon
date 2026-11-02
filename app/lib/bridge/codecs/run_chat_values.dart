import 'package:agent_orchestration/bridge/codecs/json_values.dart';

enum ChatAuthor implements WireNamed {
  you('you'),
  agent('agent'),
  tool('tool');

  const ChatAuthor(this.wireName);

  @override
  final String wireName;

  static ChatAuthor decode(Object? json) => decodeWireName(values, json);
}

final class LogLine implements JsonEncodable {
  const LogLine({
    required this.at,
    required this.stepName,
    required this.text,
    required this.isError,
  });

  factory LogLine.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return LogLine(
      at: readField(fields, 'at', decodeMoment),
      stepName: readField(fields, 'step_name', decodeText),
      text: readField(fields, 'text', decodeText),
      isError: readField(fields, 'is_error', decodeFlag),
    );
  }

  final DateTime at;
  final String stepName;
  final String text;
  final bool isError;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'at': encodeMoment(at),
      'step_name': stepName,
      'text': text,
      'is_error': isError,
    };
  }
}

final class ChatMessage implements JsonEncodable {
  const ChatMessage({
    required this.at,
    required this.author,
    required this.text,
    required this.isError,
    required this.waitingToSend,
  });

  factory ChatMessage.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return ChatMessage(
      at: readField(fields, 'at', decodeMoment),
      author: readField(fields, 'author', ChatAuthor.decode),
      text: readField(fields, 'text', decodeText),
      isError: readField(fields, 'is_error', decodeFlag),
      waitingToSend: readField(fields, 'waiting_to_send', decodeFlag),
    );
  }

  final DateTime at;
  final ChatAuthor author;
  final String text;
  final bool isError;
  final bool waitingToSend;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'at': encodeMoment(at),
      'author': author.wireName,
      'text': text,
      'is_error': isError,
      'waiting_to_send': waitingToSend,
    };
  }
}
