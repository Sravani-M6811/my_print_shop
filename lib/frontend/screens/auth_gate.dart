import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../../admin/services/admin_service.dart';
import '../../admin/screens/admin_shell.dart';
import 'main_navigation_screen.dart';
import 'welcome_screen.dart';

/// Top-level gate deciding what the app shows on launch: signed-in users go to
/// the admin-aware gate, guests land on the welcome screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildGuestOrSignedIn(context);
  }

  Widget _buildGuestOrSignedIn(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return AdminAwareGate(user: snapshot.data!);
        }
        return const WelcomeScreen();
      },
    );
  }
}

/// Picks the correct home screen for a signed-in user: the Admin Panel when
/// the user holds an `admins/{uid}` role document, otherwise the customer app.
class AdminAwareGate extends StatefulWidget {
  final User user;

  const AdminAwareGate({super.key, required this.user});

  @override
  State<AdminAwareGate> createState() => _AdminAwareGateState();
}

class _AdminAwareGateState extends State<AdminAwareGate> {
  late Future<bool> _adminCheck;

  @override
  void initState() {
    super.initState();
    _refreshCheck();
  }

  @override
  void didUpdateWidget(covariant AdminAwareGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) _refreshCheck();
  }

  void _refreshCheck() {
    _adminCheck = AdminService().isAdmin(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _adminCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isAdmin = snapshot.data ?? false;
        return ChangeNotifierProvider.value(
          value: Provider.of<AppState>(context, listen: false),
          key: ValueKey(isAdmin ? 'admin' : 'home'),
          child: isAdmin ? const AdminShell() : const MainNavigationScreen(),
        );
      },
    );
  }
}
