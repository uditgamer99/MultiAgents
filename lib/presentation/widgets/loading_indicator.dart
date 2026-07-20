import 'package:flutter/material.dart';

/// Simple full-space centered loading indicator, used while auth
/// state is resolving (auto-login check) or during async screens.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
