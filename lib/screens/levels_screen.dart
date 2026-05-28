import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/entity_dialogs.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  String? _selectedLevelId;
  String? _selectedGradeId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Row(
      children: [
        // ── Left: Levels panel ────────────────────────────────────────────
        SizedBox(
          width: 260,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Secciones',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Nuevo Nivel',
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const LevelDialog(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: provider.levels.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'No hay niveles.\nUsa + para crear uno.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ),
                        )
                      : ListView(
                          children: provider.levels.map((level) {
                            final isSelected = _selectedLevelId == level.id;
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor:
                                  AppTheme.primary.withOpacity(0.08),
                              leading: Icon(Icons.school_rounded,
                                  size: 18,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.grey),
                              title: Text(level.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  )),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${provider.gradesForLevel(level.id).length} grados',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  if (level.scheduledDismissal)
                                    Row(
                                      children: [
                                        const Icon(Icons.exit_to_app_rounded,
                                            size: 11,
                                            color: Color(0xFF2563EB)),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            'Salida: sesión ${level.dismissalSessionIndex + 1}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF2563EB),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                iconSize: 16,
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar')),
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Eliminar',
                                          style: TextStyle(
                                              color: AppTheme.error))),
                                ],
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    showDialog(
                                        context: context,
                                        builder: (_) =>
                                            LevelDialog(existing: level));
                                  } else {
                                    final ok = await _confirmDelete(
                                        context,
                                        'Eliminar Nivel',
                                        '¿Eliminar "${level.name}" y todos sus grados?');
                                    if (ok && context.mounted) {
                                      provider.deleteLevel(level.id);
                                      if (_selectedLevelId == level.id) {
                                        setState(() {
                                          _selectedLevelId = null;
                                          _selectedGradeId = null;
                                        });
                                      }
                                    }
                                  }
                                },
                              ),
                              onTap: () => setState(() {
                                _selectedLevelId = level.id;
                                _selectedGradeId = null;
                              }),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ),

        // ── Center: Grades panel ──────────────────────────────────────────
        if (_selectedLevelId != null)
          SizedBox(
            width: 250,
            child: Card(
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Expanded(
                            child: Text('Grados',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15))),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          tooltip: 'Nuevo Grado',
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) =>
                                GradeDialog(levelId: _selectedLevelId!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: provider
                            .gradesForLevel(_selectedLevelId!)
                            .isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                  'No hay grados.\nUsa + para crear uno.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ),
                          )
                        : ListView(
                            children: provider
                                .gradesForLevel(_selectedLevelId!)
                                .map((grade) {
                              final isSelected =
                                  _selectedGradeId == grade.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor:
                                    AppTheme.primary.withOpacity(0.08),
                                leading: Icon(Icons.layers_rounded,
                                    size: 18,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : Colors.grey),
                                title: Text(grade.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    )),
                                subtitle: Text(
                                  grade.sections.isEmpty
                                      ? 'Sin grupos (grupo único)'
                                      : '${grade.sections.length} grupo(s)',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: SizedBox(
                                  width: 72,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => showDialog(
                                          context: context,
                                          builder: (_) => GradeDialog(
                                              levelId: _selectedLevelId!,
                                              existing: grade),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            size: 16,
                                            color: AppTheme.error),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          final ok = await _confirmDelete(
                                              context,
                                              'Eliminar Grado',
                                              '¿Eliminar "${grade.name}" y todos sus grupos?');
                                          if (ok && context.mounted) {
                                            provider.deleteGrade(grade.id);
                                            if (_selectedGradeId ==
                                                grade.id) {
                                              setState(() =>
                                                  _selectedGradeId = null);
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () => setState(
                                    () => _selectedGradeId = grade.id),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),

        // ── Right: Grade detail + sections ────────────────────────────────
        if (_selectedGradeId != null)
          Expanded(
            child: _GradeDetailPanel(
              gradeId: _selectedGradeId!,
              levelId: _selectedLevelId!,
            ),
          )
        else if (_selectedLevelId != null)
          const Expanded(
            child: Center(
              child: Text('Selecciona un grado para ver sus detalles.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          const Expanded(
            child: Center(
              child: Text('Selecciona un nivel educativo.',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }

  Future<bool> _confirmDelete(
      BuildContext context, String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADE DETAIL PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _GradeDetailPanel extends StatelessWidget {
  final String gradeId;
  final String levelId;

  const _GradeDetailPanel(
      {required this.gradeId, required this.levelId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final grade = provider.findGrade(gradeId);
    if (grade == null) {
      return const Center(child: Text('Grado no encontrado.'));
    }

    final config = grade.config;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Grade name + config summary ───────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(grade.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _ConfigChip(
                                icon: Icons.calendar_today_rounded,
                                label:
                                    '${config.classDays.length} días/sem'),
                            _ConfigChip(
                                icon: Icons.access_time_rounded,
                                label:
                                    '${config.sessionsPerDay} sesiones · ${config.sessionDurationMinutes} min'),
                            _ConfigChip(
                                icon: Icons.play_arrow_rounded,
                                label: 'Inicio: ${config.startTime}'),
                            if (config.hasBreak)
                              _ConfigChip(
                                  icon: Icons.free_breakfast_rounded,
                                  label:
                                      'Receso ${config.breakStart}–${config.breakEnd}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // ── Sections ─────────────────────────────────────────────
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Grupos',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(
                          'Opcional — si la escuela tiene un solo grupo por grado, '
                          'no es necesario crear grupos.',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar Grupo'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => SectionDialog(
                          gradeId: gradeId, levelId: levelId),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (grade.sections.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: AppTheme.primary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Este grado no tiene grupos. El horario se generará '
                          'directamente para el grado completo (grupo único).',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: grade.sections.map((section) {
                    final hasSchedule =
                        provider.scheduleForSection(section.id) != null;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                section.name.isNotEmpty
                                    ? section.name[0]
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Grupo ${section.name}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              Row(
                                children: [
                                  Icon(
                                    hasSchedule
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 12,
                                    color: hasSchedule
                                        ? AppTheme.success
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    hasSchedule
                                        ? 'Con horario'
                                        : 'Sin horario',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: hasSchedule
                                          ? AppTheme.success
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 15),
                            tooltip: 'Editar',
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => SectionDialog(
                                gradeId: gradeId,
                                levelId: levelId,
                                existing: section,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 15, color: AppTheme.error),
                            tooltip: 'Eliminar',
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title:
                                      const Text('Eliminar Grupo'),
                                  content: Text(
                                      '¿Eliminar el grupo "${section.name}"?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(
                                                context, false),
                                        child:
                                            const Text('Cancelar')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.error),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true && context.mounted) {
                                context
                                    .read<AppProvider>()
                                    .deleteSection(gradeId, section.id);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIG CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _ConfigChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  // ignore: unused_element_parameter
  const _ConfigChip({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final bg    = highlight ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9);
    final color = highlight ? const Color(0xFF2563EB) : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: highlight ? Border.all(color: const Color(0xFFBFDBFE)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}