import 'package:flutter/material.dart';

import '../../widgets/loading_indicator.dart';

/// Shown only for the brief moment while Firebase resolves whether a
/// session already exists (auto-login check). go_router redirects
/// away from here as soon as [authStateChangesProvider] settles.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: LoadingIndicator());
  }
}
