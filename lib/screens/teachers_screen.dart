import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/entity_dialogs.dart';

class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  String _search = '';
  String? _filterLevelId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final teachers = provider.teachers
        .where((t) => t.fullName.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Maestros',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                  Text('Administra el personal docente y sus asignaciones',
                      style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
              // Level filter
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String?>(
                  value: _filterLevelId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Todos los niveles',
                    prefixIcon: Icon(Icons.filter_list, size: 18),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Todos los niveles')),
                    ...provider.levels.map((l) =>
                        DropdownMenuItem(value: l.id, child: Text(l.name))),
                  ],
                  onChanged: (v) => setState(() => _filterLevelId = v),
                ),
              ),
              SizedBox(
                width: 210,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar maestro...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Maestro'),
                onPressed: provider.subjects.isEmpty
                    ? null
                    : () => showDialog(
                          context: context,
                          builder: (_) => const TeacherDialog(),
                        ),
              ),
            ],
          ),

          if (provider.subjects.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.orange, size: 40),
                    SizedBox(height: 8),
                    Text('Registra materias primero antes de crear maestros.',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (teachers.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No hay maestros registrados.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: teachers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _TeacherCard(
                  teacher: teachers[i],
                  filterLevelId: _filterLevelId,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  final Teacher teacher;
  final String? filterLevelId;
  const _TeacherCard({required this.teacher, this.filterLevelId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    // Filter subjects by level if a level filter is active.
    // Since subjects now use levelConfigs (not a single levelId), we check
    // the levelIds list produced by Subject.levelIds.
    final teacherSubjects = teacher.subjectIds
        .map((id) => provider.findSubject(id))
        .whereType<Subject>()
        .where((s) =>
            filterLevelId == null || s.levelIds.contains(filterLevelId))
        .toList();

    final initials = teacher.name.isNotEmpty && teacher.lastName.isNotEmpty
        ? '${teacher.name[0]}${teacher.lastName[0]}'.toUpperCase()
        : teacher.name
            .substring(0, teacher.name.length > 1 ? 2 : 1)
            .toUpperCase();

    final avatarColor = AppTheme.subjectColors[
        teacher.name.codeUnitAt(0) % AppTheme.subjectColors.length];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(teacher.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),

                  // Subjects
                  if (teacherSubjects.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text('Materias:',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey)),
                        if (filterLevelId != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              provider.findLevel(filterLevelId!)?.name ?? '',
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: teacherSubjects.map((s) {
                        // Show level-specific hours when a filter is active.
                        final hoursLabel = filterLevelId != null
                            ? ' ${s.hoursForLevel(filterLevelId!)}h'
                            : '';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: s.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: s.color.withOpacity(0.3)),
                          ),
                          child: Text(
                            '${s.name}$hoursLabel',
                            style: TextStyle(
                                fontSize: 11,
                                color: s.color.withOpacity(0.8),
                                fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        filterLevelId != null
                            ? 'Sin materias en este nivel.'
                            : 'Sin materias asignadas.',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orange),
                      ),
                    ),

                  // Assignments
                  if (teacher.assignments.isNotEmpty) ...[
                    const Text('Asignaciones:',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: teacher.assignments.map((a) {
                        final subj  = provider.findSubject(a.subjectId);
                        final grade = provider.findGrade(a.gradeId);
                        final level = grade != null ? provider.findLevel(grade.levelId) : null;
                        final scopeLabel = a.sectionId == null
                            ? 'Grado completo'
                            : (provider.findSection(a.sectionId!)?.name ?? a.sectionId!);
                        final color = subj?.color ?? AppTheme.primary;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Text(
                            '${subj?.name ?? '?'} · ${level?.name ?? ''} ${grade?.name ?? ''} · $scopeLabel',
                            style: TextStyle(
                                fontSize: 10,
                                color: color.withOpacity(0.85),
                                fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                  ] else
                    const Text(
                      'Sin asignaciones — disponible para todos los grupos',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),

                  // Availability summary
                  if (teacher.availability.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Disponibilidad: ${teacher.availability.map((a) => a.day.substring(0, 3)).join(', ')}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  tooltip: 'Editar',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => TeacherDialog(existing: teacher),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded,
                      size: 18, color: AppTheme.error),
                  tooltip: 'Eliminar',
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Eliminar Maestro'),
                        content:
                            Text('¿Eliminar a "${teacher.fullName}"?'),
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
                      context.read<AppProvider>().deleteTeacher(teacher.id);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}