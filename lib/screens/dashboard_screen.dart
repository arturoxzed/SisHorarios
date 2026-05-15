import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final stats = provider.stats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Dashboard',
            subtitle: 'Resumen general del sistema de horarios',
          ),
          const SizedBox(height: 24),

          // ── Stats grid ──────────────────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              _StatCard(
                icon: Icons.account_tree_rounded,
                label: 'Niveles',
                value: '${stats['levels']}',
                color: const Color(0xFF3B82F6),
                onTap: () => provider.navigate(AppScreen.levels),
              ),
              _StatCard(
                icon: Icons.layers_rounded,
                label: 'Grados',
                value: '${stats['grades']}',
                color: const Color(0xFF8B5CF6),
                onTap: () => provider.navigate(AppScreen.levels),
              ),
              _StatCard(
                icon: Icons.group_work_rounded,
                label: 'Grupos',
                value: '${stats['sections']}',
                color: const Color(0xFF06B6D4),
                onTap: () => provider.navigate(AppScreen.levels),
              ),
              _StatCard(
                icon: Icons.menu_book_rounded,
                label: 'Materias',
                value: '${stats['subjects']}',
                color: const Color(0xFF10B981),
                onTap: () => provider.navigate(AppScreen.subjects),
              ),
              _StatCard(
                icon: Icons.person_rounded,
                label: 'Maestros',
                value: '${stats['teachers']}',
                color: const Color(0xFFF59E0B),
                onTap: () => provider.navigate(AppScreen.teachers),
              ),
              _StatCard(
                icon: Icons.grid_view_rounded,
                label: 'Horarios',
                value: '${stats['schedules']}',
                color: const Color(0xFFEF4444),
                onTap: () => provider.navigate(AppScreen.visualization),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Setup guide (only shown when data is incomplete) ─────────────
          if (stats['subjects'] == 0 ||
              stats['teachers'] == 0 ||
              stats['sections'] == 0)
            _SetupGuide(stats: stats, provider: provider),

          // ── Conflict summary (only when schedules exist) ─────────────────
          if (stats['schedules']! > 0) ...[
            const SizedBox(height: 8),
            _ConflictsCard(provider: provider),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup guide
// ─────────────────────────────────────────────────────────────────────────────

class _SetupGuide extends StatelessWidget {
  final Map<String, int> stats;
  final AppProvider provider;
  const _SetupGuide({required this.stats, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Guía de configuración',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 14),
            _Step(
              done: stats['sections']! > 0,
              number: '1',
              text: 'Crear niveles, grados y grupos',
              onTap: () => provider.navigate(AppScreen.levels),
            ),
            _Step(
              done: stats['subjects']! > 0,
              number: '2',
              text: 'Registrar materias',
              onTap: () => provider.navigate(AppScreen.subjects),
            ),
            _Step(
              done: stats['teachers']! > 0,
              number: '3',
              text: 'Agregar maestros y asignar materias',
              onTap: () => provider.navigate(AppScreen.teachers),
            ),
            _Step(
              done: stats['schedules']! > 0,
              number: '4',
              text: 'Generar horarios automáticamente',
              onTap: () => provider.navigate(AppScreen.schedules),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final bool done;
  final String number;
  final String text;
  final VoidCallback onTap;

  const _Step({
    required this.done,
    required this.number,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: done ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppTheme.success : AppTheme.primary,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Text(number,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: done ? Colors.grey : Colors.black87,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
            if (!done) ...[
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conflicts card
// ─────────────────────────────────────────────────────────────────────────────

class _ConflictsCard extends StatelessWidget {
  final AppProvider provider;
  const _ConflictsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    // Combine validation issues (cross-schedule teacher conflicts) with any
    // per-section conflict messages stored during generation.
    final validationIssues = provider.validateSchedules();
    final generationIssues = provider.schedules
        .where((s) => s.hasConflicts)
        .expand((s) {
          final section = provider.findSection(s.sectionId);
          return s.conflictMessages
              .map((m) => '[${section?.name ?? s.sectionId}] $m');
        })
        .toList();

    // Deduplicate in case the same message appears in both lists.
    final allIssues = {...validationIssues, ...generationIssues}.toList();

    if (allIssues.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: AppTheme.success),
              SizedBox(width: 8),
              Text(
                'Los horarios generados no tienen conflictos.',
                style: TextStyle(
                    color: AppTheme.success, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    // Excel-style alternating blue / white rows
    const Color rowBlue  = Color(0xFF1E40AF); // sidebar blue
    const Color rowWhite = Colors.white;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: rowBlue,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${allIssues.length} conflicto(s) detectado(s)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          // Alternating rows
          ...allIssues.asMap().entries.map((entry) {
            final isEven = entry.key.isEven;
            return Container(
              color: isEven ? rowWhite : rowBlue.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 8, top: 1),
                    decoration: BoxDecoration(
                      color: isEven ? rowBlue : rowBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isEven ? Colors.white : rowBlue,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1)),
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}