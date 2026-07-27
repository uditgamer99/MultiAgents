/// Centralized route path constants for go_router.
class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String chats = '/chats';
  static const String chat = '/chat/:agentId';

  static String chatPath(String agentId) => '/chat/$agentId';
}
