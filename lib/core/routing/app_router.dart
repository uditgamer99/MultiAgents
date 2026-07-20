import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/login/login_screen.dart';
import '../../presentation/screens/register/register_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import 'route_names.dart';

/// Riverpod provider exposing the app's GoRouter instance.
///
/// Watches [authStateChangesProvider] so the router rebuilds whenever
/// auth state changes — this drives auto-login, post-login, and
/// logout redirects without any manual navigation calls from the UI.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    redirect: (context, state) {
      final isSplash = state.matchedLocation == RouteNames.splash;
      final isAuthRoute = state.matchedLocation == RouteNames.login ||
          state.matchedLocation == RouteNames.register;

      // Still resolving whether a session already exists — park on
      // the splash screen until we know either way.
      if (authState.isLoading) {
        return isSplash ? null : RouteNames.splash;
      }

      final isLoggedIn = authState.valueOrNull != null;

      if (isSplash) {
        return isLoggedIn ? RouteNames.home : RouteNames.login;
      }
      if (!isLoggedIn && !isAuthRoute) {
        return RouteNames.login;
      }
      if (isLoggedIn && isAuthRoute) {
        return RouteNames.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteNames.chat,
        builder: (context, state) => ChatScreen(
          agentId: state.pathParameters['agentId']!,
        ),
      ),
    ],
  );
});
