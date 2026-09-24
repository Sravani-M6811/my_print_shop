import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../frontend/models/order_item.dart';
import '../services/admin_service.dart';
import '../../frontend/services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_designs_screen.dart';

/// Admin Panel shell — a responsive layout with a sidebar on web/desktop and a
/// drawer on narrow screens. Owns the shared orders stream so the Dashboard
/// and Orders screens always stay in sync.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _widthBreakpoint = 900.0;

  final AdminService _adminService = AdminService();
  late Stream<List<OrderItem>> _ordersStream;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _ordersStream = _adminService.allOrdersStream();
  }

  void _retry() {
    setState(() {
      _ordersStream = _adminService.allOrdersStream();
    });
  }

  Future<void> _logout() async {
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _widthBreakpoint;

    return Scaffold(
      drawer: isWide ? null : _buildDrawer(context),
      body: Row(
        children: [
          if (isWide) _buildSidebar(context),
          Expanded(
            child: Column(
              children: [
                if (!isWide) _buildTopBar(context),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _buildScreens(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact top bar with a drawer hamburger for narrow screens.
  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF1E1B2E),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
          const SizedBox(width: 4),
          const Icon(Icons.print_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'MY PRINT SHOP — ADMIN',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  /// Screens refreshed on every build so a swapped stream (after retry) is
  /// picked up automatically.
  List<Widget> _buildScreens() {
    return [
      AdminDashboardScreen(
        ordersStream: _ordersStream,
        adminService: _adminService,
        onRetry: _retry,
      ),
      AdminOrdersScreen(
        ordersStream: _ordersStream,
        adminService: _adminService,
        onRetry: _retry,
      ),
      const AdminProductsScreen(),
      const AdminDesignsScreen(),
    ];
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF1E1B2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Brand header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.print_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MY PRINT SHOP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'ADMIN PANEL',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Nav items
          _sidebarItem(context, 0, Icons.space_dashboard_outlined, 'Dashboard'),
          _sidebarItem(context, 1, Icons.receipt_long_outlined, 'Orders'),
          _sidebarItem(context, 2, Icons.inventory_2_outlined, 'Products'),
          _sidebarItem(context, 3, Icons.palette_outlined, 'Designs'),
          const Spacer(),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _adminEmail(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Logout',
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
      BuildContext context, int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: selected
            ? const Color(0xFF6C5CE7).withValues(alpha: 0.25)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _currentIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1E1B2E),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.print_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MY PRINT SHOP',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'ADMIN PANEL',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _drawerItem(context, 0, Icons.space_dashboard_outlined, 'Dashboard'),
            _drawerItem(context, 1, Icons.receipt_long_outlined, 'Orders'),
            _drawerItem(context, 2, Icons.inventory_2_outlined, 'Products'),
            _drawerItem(context, 3, Icons.palette_outlined, 'Designs'),
            const Spacer(),
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _adminEmail(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout,
                        color: Colors.white70, size: 20),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context, int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: selected
            ? const Color(0xFF6C5CE7).withValues(alpha: 0.25)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context).pop();
            setState(() => _currentIndex = index);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _adminEmail() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email ?? user?.phoneNumber ?? 'Admin';
  }
}
