import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SuperAdminSidebar extends StatelessWidget {
  final String currentRoute;
  final bool isPermanent;

  const SuperAdminSidebar({
    super.key,
    required this.currentRoute,
    this.isPermanent = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          right: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // --- Logo/Brand Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(width: 12),
                const Text(
                  'SuperAdmin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // --- Navigation Items ---
          _buildNavItem(
            context,
            icon: Icons.analytics_rounded,
            label: 'Dashboard',
            route: '/',
            isSelected: currentRoute == '/',
          ),
          _buildNavItem(
            context,
            icon: Icons.business_center_rounded,
            label: 'Tenants',
            route: '/tenants',
            isSelected: currentRoute == '/tenants',
          ),
          _buildNavItem(
            context,
            icon: Icons.system_security_update_rounded,
            label: 'Updates',
            route: '/updates',
            isSelected: currentRoute == '/updates',
          ),
          _buildNavItem(
            context,
            icon: Icons.settings_suggest_rounded,
            label: 'Global Settings',
            route: '/settings',
            isSelected: currentRoute == '/settings',
          ),
          
          const Spacer(),
          
          // --- User Section ---
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Global Admin',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Platform Owner',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    bool isSelected = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.primary.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? colorScheme.primary : Colors.grey,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? colorScheme.primary : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms * (route.length % 5));
  }
}
