import 'package:flutter/material.dart';
import '../core/navigation_service.dart';
import '../services/customer_catalogue.dart';
import 'home_screen.dart';
import 'design_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'assistant_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  ValueChanged<int>? Function()? _unlisten;

  /// Tabs are kept alive in an [IndexedStack] so scroll position, search text
  /// and filter state are preserved when switching tabs instead of being
  /// rebuilt from scratch.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      // The Design tab is the global design library: it browses reusable
      // designs from every category (filterable by theme/type/category), so no
      // category is hardcoded here.
      const DesignScreen(),
      const CartScreen(),
      const ProfileScreen(),
    ];
    _unlisten = NavigationService.instance
        .listen((index) => setState(() => _currentIndex = index));
  }

  @override
  void dispose() {
    _unlisten?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the tabs once the background catalogue merge completes so any
    // admin changes land on Home/Designs without a restart. The static
    // catalogue is shown first, so there is never a blank/loading flash.
    return ListenableBuilder(
      listenable: CustomerCatalogue.instance,
      builder: (context, _) => Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AssistantScreen()),
            );
          },
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
          tooltip: 'Ask the assistant',
          child: const Icon(Icons.chat_bubble_rounded),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF6C5CE7),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.palette_rounded), label: 'Designs'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_rounded), label: 'Cart'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
