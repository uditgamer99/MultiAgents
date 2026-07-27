import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_session_model.dart';

/// Stores all chat session metadata as a single JSON blob in
/// SharedPreferences — entirely on-device, no network, no Firestore.
/// Survives app restarts by design (that's what SharedPreferences is).
class ChatSessionLocalDataSource {
  static const _storageKey = 'chat_sessions_v1';

  Future<Map<String, ChatSessionModel>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (agentId, json) => MapEntry(
        agentId,
        ChatSessionModel.fromJson(agentId, json as Map<String, dynamic>),
      ),
    );
  }

  Future<void> saveAll(Map<String, ChatSessionModel> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      sessions.map((agentId, session) => MapEntry(agentId, session.toJson())),
    );
    await prefs.setString(_storageKey, encoded);
  }
}
