import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../services/history_service.dart';
import 'chat_screen.dart';

abstract class ChatStorage {
  Future<void> init();
  List<ChatMessage> loadMessages();
  Future<void> saveMessage(ChatMessage msg);
  Future<void> clear();
  Future<void> updateMessage(int index, ChatMessage msg);
}

class HiveChatStorage implements ChatStorage {
  late Box<String> _chatBox;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _chatBox = await Hive.openBox<String>('murassikh_chat_box');
  }

  @override
  List<ChatMessage> loadMessages() {
    final List<ChatMessage> loaded = [];
    for (final raw in _chatBox.values) {
      try {
        final data = jsonDecode(raw);
        loaded.add(ChatMessage.fromMap(data));
      } catch (_) {}
    }
    return loaded;
  }

  @override
  Future<void> saveMessage(ChatMessage msg) async {
    await _chatBox.add(jsonEncode(msg.toMap()));
  }

  @override
  Future<void> clear() async {
    await _chatBox.clear();
  }

  @override
  Future<void> updateMessage(int index, ChatMessage msg) async {
    await _chatBox.putAt(index, jsonEncode(msg.toMap()));
  }
}

abstract class DelayedResponseProvider {
  Future<List<DelayedResponseItem>> getDueResponses();
  bool get shouldPoll;
}

class DefaultDelayedResponseProvider implements DelayedResponseProvider {
  @override
  Future<List<DelayedResponseItem>> getDueResponses() {
    return HistoryService().getDueDelayedResponses();
  }

  @override
  bool get shouldPoll => true;
}
