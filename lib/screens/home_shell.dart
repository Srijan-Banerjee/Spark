import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';
import '../core/theme.dart';
import '../core/widgets/logo.dart';

/// Bottom navigation shell: Home dashboard · Friends · Settings.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const SparkLogo(size: 34),
            const SizedBox(width: 10),
            Text(
              'Spark',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: SparkColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add friend',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => showAddFriendSheet(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOut,
        child: IndexedStack(
          key: ValueKey(_index),
          index: _index,
          children: const [HomeScreen(), FriendsScreen(), SettingsScreen()],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          decoration: BoxDecoration(
            color: SparkColors.bgElevated.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SparkColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: SparkColors.amber.withValues(alpha: 0.16),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: states.contains(WidgetState.selected)
                        ? SparkColors.amber
                        : SparkColors.textSecondary,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    size: 22,
                    color: states.contains(WidgetState.selected)
                        ? SparkColors.amber
                        : SparkColors.textSecondary,
                  ),
                ),
              ),
              child: NavigationBar(
                height: 62,
                selectedIndex: _index,
                onDestinationSelected: (i) {
                  if (i != _index) {
                    setState(() => _index = i);
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.wb_sunny_outlined),
                    selectedIcon: Icon(Icons.wb_sunny_rounded),
                    label: 'Today',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline_rounded),
                    selectedIcon: Icon(Icons.people_alt_rounded),
                    label: 'Friends',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: 'You',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
