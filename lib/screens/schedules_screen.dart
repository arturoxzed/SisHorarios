import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/schedule_generator.dart';
import '../theme/app_theme.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  GenerationResult? _lastResult;
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // canGenerate: grades exist (sections optional), subjects exist, teachers exist
    final canGenerate = provider.allSchedulableUnits.isNotEmpty &&
        provider.subjects.isNotEmpty &&
        provider.teachers.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Generación de Horarios',
              style:
                  TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const Text(
              'Genera horarios automáticos respetando todas las restricciones',
              style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 24),

          // ── Prerequisite cards ──────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ReqCard(
                icon: Icons.layers_rounded,
                label: 'Grupos',
                value:
                    '${provider.allSchedulableUnits.length}',
                ok: provider.allSchedulableUnits.isNotEmpty,
              ),
              _ReqCard(
                icon: Icons.menu_book_rounded,
                label: 'Materias',
                value: '${provider.subjects.length}',
                ok: provider.subjects.isNotEmpty,
              ),
              _ReqCard(
                icon: Icons.person_rounded,
                label: 'Maestros',
                value: '${provider.teachers.length}',
                ok: provider.teachers.isNotEmpty,
              ),
              _ReqCard(
                icon: Icons.grid_view_rounded,
                label: 'Horarios generados',
                value: '${provider.schedules.length}',
                ok: true,
                isInfo: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Action buttons ──────────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: Text(
                    _generating ? 'Generando...' : 'Generar Horarios'),
                onPressed:
                    canGenerate && !_generating ? _generate : null,
              ),
              if (provider.schedules.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Regenerar'),
                  onPressed: !_generating ? _generate : null,
                ),
              if (provider.schedules.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('Ver Horarios'),
                  onPressed: () =>
                      provider.navigate(AppScreen.visualization),
                ),
              if (provider.schedules.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_rounded,
                      size: 18, color: AppTheme.error),
                  label: const Text('Limpiar',
                      style: TextStyle(color: AppTheme.error)),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Limpiar horarios'),
                        content: const Text(
                            '¿Eliminar todos los horarios generados?'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Cancelar')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.error),
                            onPressed: () =>
                                Navigator.pop(context, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      provider.clearSchedules();
                      setState(() => _lastResult = null);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Result display ──────────────────────────────────────────────
          if (_lastResult != null)
            Expanded(child: _ResultPanel(result: _lastResult!))
          else if (provider.schedules.isNotEmpty)
            Expanded(child: _ExistingSchedulesSummary())
          else if (!canGenerate)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_rounded,
                        size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      'Completa la configuración antes de generar horarios:\n'
                      '• Registra materias\n'
                      '• Agrega maestros con materias asignadas',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _lastResult = null;
    });
    final provider = context.read<AppProvider>();
    final result = await provider.generateSchedules();
    if (mounted) {
      setState(() {
        _generating = false;
        _lastResult = result;
      });
    }
  }
}

class _ReqCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  final bool isInfo;

  const _ReqCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    this.isInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isInfo ? AppTheme.primary : (ok ? AppTheme.success : AppTheme.error);
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (!isInfo)
                Icon(
                  ok
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: color,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final GenerationResult result;
  const _ResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final success      = !result.hasConflicts;
    final successCount =
        result.schedules.where((s) => !s.hasConflicts).length;
    final conflictCount =
        result.schedules.where((s) => s.hasConflicts).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: success
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: success
                    ? AppTheme.success.withOpacity(0.3)
                    : AppTheme.warning.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  success
                      ? Icons.check_circle_rounded
                      : Icons.warning_rounded,
                  color:
                      success ? AppTheme.success : AppTheme.warning,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        success
                            ? '¡Horarios generados exitosamente!'
                            : 'Horarios generados con advertencias',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: success
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                      ),
                      Text(
                        '$successCount grupo(s) sin conflictos'
                        '${conflictCount > 0 ? ' · $conflictCount con problemas' : ''}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...result.schedules.map((sched) {
            final provider = context.read<AppProvider>();
            final section  = provider.findSection(sched.sectionId);
            final grade    = section != null
                ? provider.findGrade(section.gradeId)
                : null;
            final label = section != null && grade != null
                ? (grade.sections.isEmpty
                    ? grade.name
                    : '${grade.name} – Sección ${section.name}')
                : sched.sectionId;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  sched.hasConflicts
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded,
                  color: sched.hasConflicts
                      ? AppTheme.warning
                      : AppTheme.success,
                ),
                title: Text(label,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: sched.hasConflicts
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sched.conflictMessages
                            .map((m) => Text('• $m',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.warning)))
                            .toList(),
                      )
                    : Text('${sched.slots.length} clases asignadas'),
                trailing: Text('${sched.slots.length} clases',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
              ),
            );
          }),
          if (result.globalConflicts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: AppTheme.error.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_rounded,
                            color: AppTheme.error, size: 18),
                        SizedBox(width: 6),
                        Text('Conflictos Globales',
                            style: TextStyle(
                                color: AppTheme.error,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...result.globalConflicts.map((c) => Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $c',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.error)),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExistingSchedulesSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horarios existentes (${provider.schedules.length} grupos)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: provider.schedules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final sched   = provider.schedules[i];
              final section = provider.findSection(sched.sectionId);
              final grade   = section != null
                  ? provider.findGrade(section.gradeId)
                  : null;
              final label = section != null && grade != null
                  ? (grade.sections.isEmpty
                      ? grade.name
                      : '${grade.name} – Sección ${section.name}')
                  : sched.sectionId;

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.grid_view_rounded),
                  title: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${sched.slots.length} clases · '
                    'Generado: ${sched.generatedAt.toString().substring(0, 16)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: sched.hasConflicts
                      ? const Chip(
                          label: Text('Con conflictos',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white)),
                          backgroundColor: AppTheme.warning,
                        )
                      : const Chip(
                          label: Text('OK',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white)),
                          backgroundColor: AppTheme.success,
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}