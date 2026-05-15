import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/schedule_table_widget.dart';
import '../services/pdf_export_service.dart';

class VisualizationScreen extends StatefulWidget {
  const VisualizationScreen({super.key});

  @override
  State<VisualizationScreen> createState() => _VisualizationScreenState();
}

class _VisualizationScreenState extends State<VisualizationScreen>
    with SingleTickerProviderStateMixin {
  final _pdfService = PdfExportService();
  bool _viewByTeacher = false;
  String? _selectedTeacherId;
  bool _exporting = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.schedules.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view_rounded, size: 64, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text('No hay horarios generados aún.',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 4),
            Text('Ve a "Generación" para crear horarios primero.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    final conflictCount = provider.conflictDetails.length +
        provider.schedules
            .where((s) => s.hasConflicts)
            .fold(0, (sum, s) => sum + s.conflictMessages.length);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tab bar ─────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    tabs: [
                      const Tab(
                        icon: Icon(Icons.layers_rounded, size: 15),
                        text: 'Por Grupo',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                      const Tab(
                        icon: Icon(Icons.person_rounded, size: 15),
                        text: 'Por Maestro',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                      Tab(
                        iconMargin: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_rounded, size: 15),
                            const SizedBox(width: 6),
                            const Text('Conflictos',
                                style: TextStyle(fontSize: 13)),
                            if (conflictCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$conflictCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Export button (only shown on group/teacher tabs)
                  if (_exporting)
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    PopupMenuButton<String>(
                      tooltip: 'Exportar PDF',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.save_alt_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('Guardar PDF',  
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down,
                                color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'section',
                            child: Text('Horario de este grupo')),
                        const PopupMenuItem(
                            value: 'teacher',
                            child: Text('Horario de este maestro')),
                        const PopupMenuItem(
                            value: 'all',
                            child: Text('Todos los horarios')),
                      ],
                      onSelected: (v) => _export(v, context),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Filters row (only for group/teacher tabs) ──────────────────
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) {
              if (_tabController.index == 2) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_tabController.index == 0) ...[
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<String?>(
                          value: provider.filterLevelId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              hintText: 'Nivel', isDense: true),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('Todos')),
                            ...provider.levels.map((l) => DropdownMenuItem(
                                value: l.id, child: Text(l.name))),
                          ],
                          onChanged: (v) => provider.setFilter(levelId: v),
                        ),
                      ),
                      if (provider.filterLevelId != null)
                        SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<String?>(
                            value: provider.filterGradeId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                hintText: 'Grado', isDense: true),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Todos')),
                              ...provider
                                  .gradesForLevel(provider.filterLevelId!)
                                  .map((g) => DropdownMenuItem(
                                      value: g.id, child: Text(g.name))),
                            ],
                            onChanged: (v) => provider.setFilter(
                              levelId: provider.filterLevelId,
                              gradeId: v,
                            ),
                          ),
                        ),
                    ] else
                      SizedBox(
                        width: 210,
                        child: DropdownButtonFormField<String?>(
                          value: _selectedTeacherId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              hintText: 'Seleccionar maestro', isDense: true),
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('Todos los maestros')),
                            ...provider.teachers.map((t) => DropdownMenuItem(
                                value: t.id, child: Text(t.fullName))),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedTeacherId = v),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // ── Tab content ─────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _SectionView(),
                _TeacherView(teacherId: _selectedTeacherId),
                _ConflictResolutionView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(String type, BuildContext context) async {
    final provider = context.read<AppProvider>();
    setState(() => _exporting = true);
    String? savedPath;
    try {
      if (type == 'all') {
        for (final sched in provider.schedules) {
          final section = provider.findSection(sched.sectionId);
          final grade =
              section != null ? provider.findGrade(section.gradeId) : null;
          if (section != null && grade != null) {
            savedPath = await _pdfService.exportSectionSchedule(
              schedule: sched,
              section: section,
              grade: grade,
              subjects: provider.subjects,
              teachers: provider.teachers,
            );
          }
        }
      } else if (type == 'teacher' && _selectedTeacherId != null) {
        final teacher = provider.findTeacher(_selectedTeacherId!);
        if (teacher != null) {
          savedPath = await _pdfService.exportTeacherSchedule(
            teacher: teacher,
            allSchedules: provider.schedules,
            grades: provider.grades,
            sections: provider.allSections,
            subjects: provider.subjects,
          );
        }
      } else {
        final visible = provider.filteredSchedules;
        if (visible.isNotEmpty) {
          final sched = visible.first;
          final section = provider.findSection(sched.sectionId);
          final grade =
              section != null ? provider.findGrade(section.gradeId) : null;
          if (section != null && grade != null) {
            savedPath = await _pdfService.exportSectionSchedule(
              schedule: sched,
              section: section,
              grade: grade,
              subjects: provider.subjects,
              teachers: provider.teachers,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: AppTheme.error));
      }
    }
    if (mounted) {
      setState(() => _exporting = false);
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF guardado en: $savedPath'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _SectionView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final schedules = provider.filteredSchedules;

    if (schedules.isEmpty) {
      return const Center(
        child: Text('No hay horarios para los filtros seleccionados.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount: schedules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, i) {
        final sched = schedules[i];
        final section = provider.findSection(sched.sectionId);
        final grade =
            section != null ? provider.findGrade(section.gradeId) : null;

        if (section == null || grade == null) return const SizedBox();

        final headerLabel = grade.sections.isEmpty
            ? grade.name
            : '${grade.name} — Sección ${section.name}';
        final levelName = provider.findLevel(grade.levelId)?.name ?? '';

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(section.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$headerLabel — $levelName',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sched.hasConflicts)
                      const Chip(
                        label: Text('⚠ Con conflictos',
                            style: TextStyle(
                                fontSize: 11, color: Colors.white)),
                        backgroundColor: AppTheme.warning,
                        visualDensity: VisualDensity.compact,
                      ),
                    const SizedBox(width: 8),
                    const Tooltip(
                      message: 'Toca una celda para editar manualmente',
                      child: Icon(Icons.touch_app_rounded,
                          size: 16, color: Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    Text('${sched.slots.length} clases',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScheduleTableWidget(
                      schedule: sched,
                      grade: grade,
                      subjects: provider.subjects,
                      teachers: provider.teachers,
                      onSlotTap: (day, sessionIndex, current) =>
                          _showSlotEditor(
                        context,
                        provider: provider,
                        sectionId: section.id,
                        grade: grade,
                        day: day,
                        sessionIndex: sessionIndex,
                        current: current,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SubjectLegend(
                      subjects: provider.subjects
                          .where((s) =>
                              sched.slots.any((sl) => sl.subjectId == s.id))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSlotEditor(
    BuildContext context, {
    required AppProvider provider,
    required String sectionId,
    required Grade grade,
    required String day,
    required int sessionIndex,
    required ScheduleSlot? current,
  }) async {
    final levelSubjects = provider.subjects
        .where((s) => s.levelIds.contains(grade.levelId))
        .toList();
    final eligibleTeachers = provider.teachers
        .where((t) =>
            t.subjectIds.any((sid) => levelSubjects.any((s) => s.id == sid)))
        .toList();

    String? selectedSubjectId = current?.subjectId;
    String? selectedTeacherId = current?.teacherId;
    final label = grade.config.sessionLabels[sessionIndex];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Editar — $day  S${sessionIndex + 1}  $label'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Materia',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String?>(
                  value: selectedSubjectId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(hintText: 'Sin materia'),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('— Limpiar celda —')),
                    ...levelSubjects.map((s) =>
                        DropdownMenuItem(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) => setState(() {
                    selectedSubjectId = v;
                    if (v == null) selectedTeacherId = null;
                  }),
                ),
                const SizedBox(height: 16),
                const Text('Maestro',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String?>(
                  value: selectedTeacherId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      hintText: 'Seleccionar maestro'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('— Sin maestro —')),
                    ...eligibleTeachers
                        .where((t) =>
                            selectedSubjectId == null ||
                            t.subjectIds.contains(selectedSubjectId))
                        .map((t) => DropdownMenuItem(
                            value: t.id, child: Text(t.fullName))),
                  ],
                  onChanged: (v) =>
                      setState(() => selectedTeacherId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await provider.updateSlot(
                  sectionId: sectionId,
                  day: day,
                  periodIndex: sessionIndex,
                  subjectId: selectedSubjectId,
                  teacherId: selectedTeacherId,
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEACHER VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherView extends StatelessWidget {
  final String? teacherId;
  const _TeacherView({this.teacherId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    final teachers = teacherId != null
        ? provider.teachers.where((t) => t.id == teacherId).toList()
        : provider.teachers;

    if (teachers.isEmpty) {
      return const Center(
          child:
              Text('No hay maestros.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      itemCount: teachers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, i) {
        final teacher = teachers[i];

        final teacherSlots = <ScheduleSlot>[];
        final seenSlots = <String>{};
        // Collect ALL section labels per (day, period) so shared blocks show
        // every group the teacher is with at that time.
        final Map<String, List<String>> slotSectionLabels = {};
        for (final sched in provider.schedules) {
          for (final slot in sched.slots) {
            if (slot.teacherId != teacher.id) continue;
            final key = '${slot.day}-${slot.periodIndex}';
            // Build section label for this schedule entry.
            final sec = provider.findSection(sched.sectionId);
            final gr  = sec != null ? provider.findGrade(sec.gradeId) : null;
            final label = sec != null
                ? (gr != null ? '${gr.name} ${sec.name}' : sec.name)
                : null;
            if (label != null) {
              slotSectionLabels.putIfAbsent(key, () => []);
              if (!slotSectionLabels[key]!.contains(label)) {
                slotSectionLabels[key]!.add(label);
              }
            }
            // Only add the first occurrence of (day, period) to teacherSlots
            // so the schedule table doesn't have duplicate slots.
            if (seenSlots.add(key)) {
              teacherSlots.add(slot);
            }
          }
        }
        // Flatten label lists to a single display string per slot key.
        final Map<String, String> slotSectionMap = {
          for (final e in slotSectionLabels.entries)
            e.key: e.value.join(' / '),
        };

        Grade? grade;
        if (teacher.sectionIds.isNotEmpty) {
          final section = provider.findSection(teacher.sectionIds.first);
          if (section != null) grade = provider.findGrade(section.gradeId);
        }
        grade ??= provider.grades.isNotEmpty ? provider.grades.first : null;

        if (grade == null || teacherSlots.isEmpty) {
          return Card(
            child: ListTile(
              title: Text(teacher.fullName),
              subtitle:
                  const Text('Sin clases asignadas esta semana.'),
            ),
          );
        }

        final teacherSched = SectionSchedule(
          id: 'teacher-${teacher.id}',
          sectionId: '',
          slots: teacherSlots,
          generatedAt: DateTime.now(),
        );

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.secondary,
                      child: Text(
                        teacher.name.isNotEmpty
                            ? teacher.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(teacher.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    Text('${teacherSlots.length} clases/sem',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ScheduleTableWidget(
                  schedule: teacherSched,
                  grade: grade,
                  subjects: provider.subjects,
                  teachers: provider.teachers,
                  compact: true,
                  slotSectionLabel: (day, period) =>
                      slotSectionMap['$day-$period'],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFLICT RESOLUTION VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _ConflictResolutionView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final conflicts = provider.conflictDetails;

    // Also collect generation-time conflict messages stored per schedule.
    final generationMessages = <({String sectionLabel, String message})>[];
    for (final sched in provider.schedules) {
      if (!sched.hasConflicts) continue;
      final section = provider.findSection(sched.sectionId);
      final grade = section != null ? provider.findGrade(section.gradeId) : null;
      final label = (grade != null)
          ? '${grade.name} — ${section!.name}'
          : (section?.name ?? sched.sectionId);
      for (final msg in sched.conflictMessages) {
        generationMessages.add((sectionLabel: label, message: msg));
      }
    }

    final hasAny = conflicts.isNotEmpty || generationMessages.isNotEmpty;

    if (!hasAny) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('¡Sin conflictos detectados!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success)),
            const SizedBox(height: 6),
            const Text('Todos los maestros tienen horarios sin solapamientos.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final total = conflicts.length + generationMessages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header banner ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded,
                  color: AppTheme.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$total conflicto(s) de horario detectados. '
                  'Para cada conflicto de doble asignación, selecciona uno '
                  'de los grupos y cambia el maestro o la materia.',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Conflict cards ─────────────────────────────────────────────────
        Expanded(
          child: ListView(
            children: [
              // Generation conflicts (unresolved slots from the generator)
              if (generationMessages.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_fix_off_rounded,
                                size: 13, color: AppTheme.error),
                            const SizedBox(width: 5),
                            Text(
                              'Slots sin asignar (${generationMessages.length})',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ...generationMessages.map((m) => _GenerationConflictCard(
                      sectionLabel: m.sectionLabel,
                      message: m.message,
                    )),
                if (conflicts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppTheme.warning.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_horiz_rounded,
                                  size: 13, color: AppTheme.warning),
                              const SizedBox(width: 5),
                              Text(
                                'Doble asignación de maestro (${conflicts.length})',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              // Teacher double-booking conflicts
              ...conflicts.asMap().entries.map((e) =>
                  _ConflictCard(conflict: e.value, index: e.key + 1)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Generation conflict card (unresolved slot) ───────────────────────────────

class _GenerationConflictCard extends StatelessWidget {
  final String sectionLabel;
  final String message;
  const _GenerationConflictCard(
      {required this.sectionLabel, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppTheme.error, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          sectionLabel,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'Slot no asignado',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(message,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  const Text(
                    'Ve a "Por Grupo", selecciona esta sección y toca la celda vacía para asignar manualmente.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single conflict card ─────────────────────────────────────────────────────

class _ConflictCard extends StatelessWidget {
  final ConflictInfo conflict;
  final int index;
  const _ConflictCard({required this.conflict, required this.index});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final teacher = conflict.teacher;

    // Look up the grade for the first section to get session labels
    final firstSection =
        provider.findSection(conflict.slots.first.sectionId);
    final grade = firstSection != null
        ? provider.findGrade(firstSection.gradeId)
        : null;
    final sessionLabel = (grade != null &&
            conflict.periodIndex < grade.config.sessionLabels.length)
        ? grade.config.sessionLabels[conflict.periodIndex]
        : 'S${conflict.periodIndex + 1}';

    final avatarColor = AppTheme.subjectColors[
        teacher.name.codeUnitAt(0) % AppTheme.subjectColors.length];
    final initials = teacher.name.isNotEmpty && teacher.lastName.isNotEmpty
        ? '${teacher.name[0]}${teacher.lastName[0]}'.toUpperCase()
        : teacher.name.substring(0, teacher.name.length > 1 ? 2 : 1)
            .toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ──────────────────────────────────────────────
            Row(
              children: [
                // Index badge
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Teacher avatar + name
                CircleAvatar(
                  radius: 14,
                  backgroundColor: avatarColor,
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teacher.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(
                        '${conflict.day}  •  Sesión ${conflict.periodIndex + 1}  •  $sessionLabel',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Conflict type chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Doble asignación',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Explanation ───────────────────────────────────────────────
            const Text(
              'Este maestro está asignado a dos grupos distintos al mismo tiempo con materias diferentes. '
              'Para resolverlo, toca "Editar slot" en uno de los grupos y cambia el maestro o la materia.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            // ── Conflicting slot cards ─────────────────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: conflict.slots.map((slotInfo) {
                final subj = slotInfo.subject;
                final color = subj?.color ?? const Color(0xFF94A3B8);
                return _SlotChip(
                  slotInfo: slotInfo,
                  conflict: conflict,
                  color: color,
                  grade: grade,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Slot chip with edit button ───────────────────────────────────────────────

class _SlotChip extends StatelessWidget {
  final ConflictSlotInfo slotInfo;
  final ConflictInfo conflict;
  final Color color;
  final Grade? grade;
  const _SlotChip({
    required this.slotInfo,
    required this.conflict,
    required this.color,
    required this.grade,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        color.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;

    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Row(
            children: [
              Icon(Icons.group_rounded, size: 13, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  slotInfo.sectionLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: color.withOpacity(0.9)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Subject chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              slotInfo.subject?.name ?? 'Sin materia',
              style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          // Edit button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_rounded, size: 13),
              label: const Text('Editar slot', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 6),
                minimumSize: Size.zero,
              ),
              onPressed: () => _editSlot(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSlot(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final section = provider.findSection(slotInfo.sectionId);
    if (section == null || grade == null) return;

    final levelSubjects = provider.subjects
        .where((s) => s.levelIds.contains(grade!.levelId))
        .toList();
    final eligibleTeachers = provider.teachers
        .where((t) =>
            t.subjectIds.any((sid) => levelSubjects.any((s) => s.id == sid)))
        .toList();

    // Get the current slot
    SectionSchedule? sched;
    try {
      sched = provider.schedules
          .firstWhere((s) => s.sectionId == slotInfo.sectionId);
    } catch (_) {}
    final current = sched?.getSlot(conflict.day, conflict.periodIndex);

    String? selectedSubjectId = current?.subjectId;
    String? selectedTeacherId = current?.teacherId;

    final sessionLabel = (conflict.periodIndex <
            grade!.config.sessionLabels.length)
        ? grade!.config.sessionLabels[conflict.periodIndex]
        : 'S${conflict.periodIndex + 1}';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            'Resolver conflicto\n${conflict.day}  •  S${conflict.periodIndex + 1}  •  $sessionLabel',
            style: const TextStyle(fontSize: 15),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Context info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_rounded,
                          color: AppTheme.warning, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Grupo: ${slotInfo.sectionLabel}\n'
                          'Maestro actual: ${conflict.teacher.fullName}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF78350F)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Materia',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String?>(
                  value: selectedSubjectId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(hintText: 'Sin materia'),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('— Limpiar celda —')),
                    ...levelSubjects.map((s) => DropdownMenuItem(
                        value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) => setState(() {
                    selectedSubjectId = v;
                    if (v == null) selectedTeacherId = null;
                  }),
                ),
                const SizedBox(height: 16),
                const Text('Maestro',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String?>(
                  value: selectedTeacherId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      hintText: 'Seleccionar maestro'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('— Sin maestro —')),
                    ...eligibleTeachers
                        .where((t) =>
                            selectedSubjectId == null ||
                            t.subjectIds.contains(selectedSubjectId))
                        .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Row(
                              children: [
                                if (t.id == conflict.teacher.id)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.warning_rounded,
                                        size: 13, color: AppTheme.warning),
                                  ),
                                Text(t.fullName +
                                    (t.id == conflict.teacher.id
                                        ? ' (conflicto actual)'
                                        : '')),
                              ],
                            ))),
                  ],
                  onChanged: (v) =>
                      setState(() => selectedTeacherId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await provider.updateSlot(
                  sectionId: slotInfo.sectionId,
                  day: conflict.day,
                  periodIndex: conflict.periodIndex,
                  subjectId: selectedSubjectId,
                  teacherId: selectedTeacherId,
                );
              },
              child: const Text('Guardar y verificar'),
            ),
          ],
        ),
      ),
    );
  }
}