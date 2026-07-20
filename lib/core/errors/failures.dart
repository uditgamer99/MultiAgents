/// Domain-layer failure types. Repositories return these (via Either-style
/// results, modeled here as thrown exceptions caught at the ViewModel
/// boundary) so the UI never has to know about Firebase-specific errors.
class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}
