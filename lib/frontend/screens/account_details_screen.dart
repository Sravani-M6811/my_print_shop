import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, SetOptions, Timestamp;
import '../constants/asset_paths.dart';
import '../services/auth_service.dart';
import 'phone_login_screen.dart';

/// Account details: the signed-in user's phone, email and profile, read from
/// the `users/{uid}` Firestore document (created on first sign-in). Guests are
/// offered a sign-in entry point instead of a dead end. Name/email are
/// editable from this screen (Firestore + FirebaseAuth profile).
class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  User? _currentUser;
  Map<String, dynamic>? _profileData;
  bool _loading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      Map<String, dynamic>? profile;
      if (user != null) {
        profile = await AuthService().getUserProfile(user.uid);
      }
      if (mounted) {
        setState(() {
          _currentUser = user;
          _profileData = profile;
          _loading = false;
        });
      }
    } catch (_) {
      // Firebase unavailable (e.g. guest browsing before any sign-in service
      // is reachable): show the signed-out state instead of crashing.
      if (mounted) {
        setState(() {
          _currentUser = null;
          _profileData = null;
          _loading = false;
        });
      }
    }
  }

  String get _displayName {
    final name = _profileData?['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    return _currentUser?.displayName ?? 'Customer';
  }

  String get _displayPhone =>
      _currentUser?.phoneNumber ?? (_profileData?['phone'] as String? ?? '—');

  String get _displayEmail =>
      _currentUser?.email ?? (_profileData?['email'] as String? ?? '—');

  String get _customerSince {
    final createdAt = _profileData?['createdAt'];
    if (createdAt is DateTime) {
      return createdAt.toLocal().toString().split(' ').first;
    }
    if (createdAt is Timestamp) {
      return createdAt.toDate().toLocal().toString().split(' ').first;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? _buildSignedOut(context)
              : _buildSignedIn(context),
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Not signed in',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to sync your orders and manage your account details.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PhoneLoginScreen()),
                ),
                icon: const Icon(Icons.phone_android),
                label: const Text('Sign in with Phone',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedIn(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 42,
            backgroundColor: const Color(0xFF6C5CE7),
            backgroundImage: const AssetImage(AssetPaths.appLogo),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _displayName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _profileData?['phone'] != null
                ? _displayPhone
                : 'Customer since $_customerSince',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        // ── Edit profile ──
        if (!_isSaving)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C5CE7),
                side: const BorderSide(color: Color(0xFF6C5CE7)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        else
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              _detailRow(context, Icons.badge_outlined, 'Name', _displayName),
              const Divider(height: 1),
              _detailRow(context, Icons.phone_outlined, 'Phone', _displayPhone),
              const Divider(height: 1),
              _detailRow(
                  context, Icons.alternate_email, 'Email', _displayEmail),
              const Divider(height: 1),
              _detailRow(
                  context,
                  Icons.calendar_today_outlined,
                  'Customer Since',
                  _customerSince),
              const Divider(height: 1),
              _detailRow(
                  context, Icons.key_outlined, 'Account ID', _currentUser!.uid),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your phone number and account ID are fixed from your phone sign-in. '
          'Name and email are editable right here and stay synced to your device.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  /// Opens the name/email edit sheet and persists changes to Firestore
  /// `users/{uid}` (merge) plus the FirebaseAuth display name.
  Future<void> _editProfile() async {
    final user = _currentUser;
    if (user == null) return;
    final nameController =
        TextEditingController(text: _displayName == 'Customer' ? '' : _displayName);
    final emailController =
        TextEditingController(text: _displayEmail == '—' ? '' : _displayEmail);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    if (name.isEmpty && email.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
            {
              'name': name.isEmpty ? _displayName : name,
              'email': email.isEmpty ? _displayEmail : email,
              'updatedAt': DateTime.now(),
            },
            SetOptions(merge: true),
          );
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save. Please check your connection.')),
        );
      }
    }
    _load();
  }

  Widget _detailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6C5CE7)),
          const SizedBox(width: 14),
          SizedBox(
            width: 110,
            child: Text(label,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
