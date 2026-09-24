import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../constants/asset_paths.dart';
import '../providers/app_state.dart';
import '../services/auth_service.dart';
import 'order_details_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  Map<String, dynamic>? _profileData;
  bool _isSigningOut = false;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    // Reload the profile whenever the auth state changes (e.g. a guest
    // continuing into a signed-in session) — the tab is kept alive inside the
    // IndexedStack shell, so initState alone would leave it forever stale.
    // Guarded so widget tests that run without a Firebase app still build.
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen(
        (_) => _loadUserProfile(),
        onError: (_) {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      Map<String, dynamic>? profile;
      if (user != null) {
        profile = await AuthService().getUserProfile(user.uid);
      }
      if (mounted) setState(() { _currentUser = user; _profileData = profile; });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  String get _displayName {
    final name = _profileData?['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    return _currentUser?.displayName ?? 'Customer';
  }

  String get _displayEmail {
    return _currentUser?.email ?? _currentUser?.phoneNumber ?? _profileData?['phone'] ?? 'Not signed in';
  }

  Future<void> _handleSignOut() async {
    setState(() => _isSigningOut = true);
    try {
      await AuthService().signOut();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    }
    if (mounted) setState(() => _isSigningOut = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final orders = appState.orders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Profile Avatar
            const CircleAvatar(
              radius: 45,
              backgroundColor: Color(0xFF6C5CE7),
              backgroundImage: AssetImage(AssetPaths.appLogo),
            ),
            const SizedBox(height: 12),
            Text(_displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(_displayEmail, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            const Divider(),
            // Sign Out
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  icon: _isSigningOut
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.logout, size: 18),
                  label: Text(
                    'Sign Out',
                    style: const TextStyle(fontSize: 15),
                  ),
                  onPressed: _isSigningOut ? null : _handleSignOut,
                ),
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Order History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            orders.isEmpty
                ? const Padding(padding: EdgeInsets.all(32), child: Text('No orders placed yet!'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ExpansionTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              order.items.isNotEmpty
                                  ? AssetPaths.productImageForCategory(order.items.first.category)
                                  : AssetPaths.appLogo,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(order.orderId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('₹${order.totalAmount.toStringAsFixed(0)} • ${order.status}'),
                          children: [
                            ...order.items.map((item) => ListTile(
                                  dense: true,
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.asset(
                                      AssetPaths.productImageForCategory(item.category),
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  title: Text('${item.category} - "${item.customText}"', style: const TextStyle(fontSize: 13)),
                                  trailing: Text('₹${item.price.toStringAsFixed(0)}'),
                                )),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.receipt_long, size: 18),
                                  label: const Text('View Order Details'),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          OrderDetailsScreen(order: order),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
