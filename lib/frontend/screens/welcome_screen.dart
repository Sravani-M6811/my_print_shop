import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/asset_paths.dart';
import '../providers/app_state.dart';
import 'main_navigation_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    AssetPaths.appLogo,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to MY PRINT SHOP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Customized prints and designs tailored just for you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: () {
                  // Capture the AppState while this widget's context is still
                  // active. pushAndRemoveUntil immediately removes THIS route,
                  // so the route builder runs after this element is deactivated
                  // — reading Provider.of(context) inside the builder would
                  // throw "Looking up a deactivated widget's ancestor is
                  // unsafe." Hoisting the lookup avoids that.
                  final appState =
                      Provider.of<AppState>(context, listen: false);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: appState,
                        child: const MainNavigationScreen(),
                      ),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('Continue as Guest'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
