import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/chat_message_model.dart';

/// Wraps all direct Firestore calls for chat. Each agent gets its own
/// independent history at:
///   users/{uid}/agents/{agentId}/messages/{messageId}
class ChatRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _firebaseAuth;

  ChatRemoteDataSource({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? firebaseAuth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String agentId) {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No authenticated user — cannot access chat history.');
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('agents')
        .doc(agentId)
        .collection('messages');
  }

  Stream<List<ChatMessageModel>> watchMessages(String agentId) {
    return _messagesRef(agentId).orderBy('timestamp').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addMessage(String agentId, ChatMessageModel message) async {
    await _messagesRef(agentId).add(message.toFirestore());
  }
}
