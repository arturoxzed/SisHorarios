import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final current = provider.currentScreen;

    return Container(
      width: 230,
      color: AppTheme.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Horarios\nEscolares',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sistema de Gestión',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // Nav items
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            screen: AppScreen.dashboard,
            current: current,
            onTap: () => provider.navigate(AppScreen.dashboard),
          ),

          _SectionLabel('Configuración'),

          _NavItem(
            icon: Icons.account_tree_rounded,
            label: 'Niveles y Grados',
            screen: AppScreen.levels,
            current: current,
            onTap: () => provider.navigate(AppScreen.levels),
          ),
          _NavItem(
            icon: Icons.menu_book_rounded,
            label: 'Materias',
            screen: AppScreen.subjects,
            current: current,
            onTap: () => provider.navigate(AppScreen.subjects),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Maestros',
            screen: AppScreen.teachers,
            current: current,
            onTap: () => provider.navigate(AppScreen.teachers),
          ),

          _SectionLabel('Horarios'),

          _NavItem(
            icon: Icons.auto_fix_high_rounded,
            label: 'Generación',
            screen: AppScreen.schedules,
            current: current,
            onTap: () => provider.navigate(AppScreen.schedules),
          ),
          _NavItem(
            icon: Icons.grid_view_rounded,
            label: 'Visualización',
            screen: AppScreen.visualization,
            current: current,
            onTap: () => provider.navigate(AppScreen.visualization),
          ),

          const Spacer(),

          // Stats footer
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Consumer<AppProvider>(
              builder: (_, p, __) {
                final s = p.stats;
                return Column(
                  children: [
                    _StatRow('Secciones', '${s['sections']}'),
                    _StatRow('Materias', '${s['subjects']}'),
                    _StatRow('Maestros', '${s['teachers']}'),
                    _StatRow('Horarios', '${s['schedules']}'),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppScreen screen;
  final AppScreen current;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.screen,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = screen == current;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.8) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.55)),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13.5,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}