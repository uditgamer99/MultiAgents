import 'package:equatable/equatable.dart';

/// Domain-layer representation of an authenticated user.
/// Deliberately minimal for Phase 2 — only what auth flows need.
class UserEntity extends Equatable {
  final String uid;
  final String email;

  const UserEntity({
    required this.uid,
    required this.email,
  });

  @override
  List<Object?> get props => [uid, email];
}
