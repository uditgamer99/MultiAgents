import '../entities/user_entity.dart';

/// Abstract contract for authentication. The presentation layer and
/// usecases depend only on this — never on FirebaseAuth directly.
abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;

  UserEntity? get currentUser;

  Future<UserEntity> signIn({
    required String email,
    required String password,
  });

  Future<UserEntity> signUp({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
