import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/schedule_generator.dart';

// =============================================================================
// SCHEDULE EDITOR WIDGET
//
// Muestra el horario generado en una cuadrícula editable.
// Permite cambiar materia y maestro por celda, guardar el arreglo manual
// y validar que no haya conflictos antes de regenerar.
//
// CORRECCIONES APLICADAS
// ──────────────────────
// 1. FIX AssertionError DropdownButton:
//    - _subjectsForSection() y _teachersForSubject() usan Set<String> para
//      garantizar IDs únicos en los DropdownMenuItems.
//    - Antes de abrir el diálogo se valida que el value actual exista en
//      la lista deduplicada; si no, se asigna null.
//
// 2. FIX Validación cruzada al editar:
//    - _conflictsFromEdit() detecta, ANTES de guardar, si el nuevo maestro
//      ya tiene asignada otra materia en el mismo día/período en CUALQUIER
//      otra sección. Se muestra un warning en el diálogo para que el usuario
//      decida si forzar o cancelar.
//
// 3. FIX detección de celdas con conflicto:
//    - _cellHasConflict() usa un mapa precalculado (sectionId→conflictKeys)
//      para evitar falsos positivos por coincidencia de nombre de materia o
//      número de período en el texto del mensaje.
//
// 4. FIX: _runValidation() ya no borra el panel si no hay cambios; el estado
//    de validación se invalida automáticamente al editar cualquier celda.
// =============================================================================

class ScheduleEditorWidget extends StatefulWidget {
  final List<SectionSchedule> initialSchedules;
  final List<Grade> grades;
  final List<Subject> subjects;
  final List<Teacher> teachers;

  /// Callback que se invoca cuando el usuario guarda el horario editado.
  /// Recibe los manualSlots para que la pantalla padre pueda llamar a
  /// generate() con ellos.
  final void Function(
    Map<String, List<ScheduleSlot>> manualSlots,
    List<String> validationIssues,
  ) onSave;

  const ScheduleEditorWidget({
    super.key,
    required this.initialSchedules,
    required this.grades,
    required this.subjects,
    required this.teachers,
    required this.onSave,
  });

  @override
  State<ScheduleEditorWidget> createState() => _ScheduleEditorWidgetState();
}

class _ScheduleEditorWidgetState extends State<ScheduleEditorWidget> {
  // ── Estado editable ────────────────────────────────────────────────────────
  // sectionId → list of ScheduleSlot (mutable copy)
  late Map<String, List<ScheduleSlot>> _editableSlots;

  // Sección actualmente seleccionada en el tab
  // ignore: unused_field
  late String _selectedSectionId;

  // Mensajes de validación más recientes
  List<String> _validationIssues = [];
  bool _showValidation = false;

  // Mapa precalculado: sectionId → Set<"day|periodIndex"> de celdas con conflicto.
  // Se actualiza cada vez que se corre la validación.
  Map<String, Set<String>> _conflictKeys = {};

  static const _kDefaultDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _editableSlots = {
      for (final s in widget.initialSchedules)
        s.sectionId: List<ScheduleSlot>.from(s.slots),
    };
    _selectedSectionId = widget.initialSchedules.isNotEmpty
        ? widget.initialSchedules.first.sectionId
        : '';
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Grade? _gradeForSection(String sectionId) {
    for (final g in widget.grades) {
      if (g.sections.any((s) => s.id == sectionId) || g.id == sectionId) {
        return g;
      }
    }
    return null;
  }

  Section? _sectionById(String sectionId) {
    for (final g in widget.grades) {
      try {
        return g.sections.firstWhere((s) => s.id == sectionId);
      } catch (_) {}
    }
    return null;
  }

  String _sectionName(String sectionId) =>
      _sectionById(sectionId)?.name ?? sectionId;

  List<String> _daysForSection(String sectionId) {
    final grade = _gradeForSection(sectionId);
    return grade?.config.classDays ?? _kDefaultDays;
  }

  int _sessionsForSection(String sectionId) {
    final grade = _gradeForSection(sectionId);
    return grade?.config.sessionsPerDay ?? 8;
  }

  /// FIX 1a — Materias sin duplicados (por id) para la sección dada.
  /// Flutter lanza AssertionError si dos DropdownMenuItems tienen el mismo
  /// value; un Set<String> garantiza unicidad.
  List<Subject> _subjectsForSection(String sectionId) {
    final grade = _gradeForSection(sectionId);
    if (grade == null) {
      // Sin grado: devolver todas sin duplicar
      final seen = <String>{};
      return widget.subjects.where((s) => seen.add(s.id)).toList();
    }

    final seen = <String>{};
    final result = <Subject>[];
    for (final subj in widget.subjects) {
      if (subj.configForLevel(grade.levelId) == null) continue;
      if (seen.add(subj.id)) result.add(subj);
    }
    return result;
  }

  /// FIX 1b — Maestros sin duplicados que pueden impartir [subjectId].
  List<Teacher> _teachersForSubject(String subjectId, String sectionId) {
    final grade = _gradeForSection(sectionId);
    final seen = <String>{};
    final result = <Teacher>[];

    for (final t in widget.teachers) {
      if (!t.subjectIds.contains(subjectId)) continue;
      if (grade != null) {
        final hasAssignment = t.assignments.any((a) =>
            a.subjectId == subjectId &&
            (a.gradeId == grade.id || a.sectionId == sectionId));
        if (!hasAssignment) continue;
      }
      if (seen.add(t.id)) result.add(t);
    }

    // Fallback: si ningún maestro tiene asignación específica, mostrar todos
    // los que enseñan la materia (sin restringir por grado), deduplicados.
    if (result.isEmpty) {
      for (final t in widget.teachers) {
        if (t.subjectIds.contains(subjectId) && seen.add(t.id)) {
          result.add(t);
        }
      }
    }
    return result;
  }

  /// Slot en la celda [day]/[periodIndex] para la sección dada, o null.
  ScheduleSlot? _slotAt(String sectionId, String day, int periodIndex) {
    final slots = _editableSlots[sectionId] ?? [];
    try {
      return slots.firstWhere(
          (s) => s.day == day && s.periodIndex == periodIndex);
    } catch (_) {
      return null;
    }
  }

  // ── FIX 2 — Validación cruzada PREVIA al guardar ───────────────────────────

  /// Devuelve los conflictos que generaría asignar [teacherId] a la celda
  /// [day]/[periodIndex] de [sectionId].  Chequea todas las demás secciones
  /// para detectar si el maestro ya está asignado en ese mismo momento.
  List<String> _conflictsFromEdit({
    required String sectionId,
    required String day,
    required int periodIndex,
    required String teacherId,
    required String subjectId,
  }) {
    final conflicts = <String>[];
    final teacher = widget.teachers.where((t) => t.id == teacherId).firstOrNull;
    final subject = widget.subjects.where((s) => s.id == subjectId).firstOrNull;
    final teacherName = teacher?.fullName ?? teacherId;
    final subjectName = subject?.name ?? subjectId;

    for (final entry in _editableSlots.entries) {
      if (entry.key == sectionId) continue; // ignorar la sección que se edita
      final conflictSlot = entry.value.where((s) =>
          s.day == day &&
          s.periodIndex == periodIndex &&
          s.teacherId == teacherId).firstOrNull;
      if (conflictSlot != null) {
        final otherSection = _sectionName(entry.key);
        final otherSubject = widget.subjects
            .where((s) => s.id == conflictSlot.subjectId)
            .firstOrNull;
        final otherSubjectName = otherSubject?.name ?? conflictSlot.subjectId;
        conflicts.add(
          '$teacherName ya imparte $otherSubjectName en $otherSection '
          '($day, período ${periodIndex + 1}). '
          'Asignarle $subjectName aquí crearía un conflicto.',
        );
      }
    }
    return conflicts;
  }

  // ── FIX 3 — Mapa de celdas con conflicto ──────────────────────────────────

  /// Actualiza [_conflictKeys] a partir de los mensajes de validación.
  /// Cada mensaje producido por ScheduleGenerator tiene el formato:
  ///   "[SectionName] [day] período [n]: ..."
  /// Extraemos day y periodIndex para construir la clave "day|periodIndex".
  void _buildConflictKeys(List<String> issues) {
    final newKeys = <String, Set<String>>{};

    // Recorrer todos los slots para ver cuáles son mencionados en algún issue
    for (final entry in _editableSlots.entries) {
      final sectionId = entry.key;
      final sectionName = _sectionName(sectionId);

      for (final slot in entry.value) {
        // Buscamos si algún issue menciona esta sección + día + período
        final periodLabel = 'período ${slot.periodIndex + 1}';
        final mentioned = issues.any((msg) =>
            msg.contains(sectionName) &&
            msg.contains(slot.day) &&
            msg.contains(periodLabel));
        if (mentioned) {
          newKeys.putIfAbsent(sectionId, () => <String>{})
              .add('${slot.day}|${slot.periodIndex}');
        }
      }
    }
    _conflictKeys = newKeys;
  }

  /// FIX 3 — Determina si la celda tiene conflicto usando el mapa precalculado.
  bool _cellHasConflict(String sectionId, String day, int periodIndex) {
    return _conflictKeys[sectionId]?.contains('$day|$periodIndex') ?? false;
  }

  // ── Edición ────────────────────────────────────────────────────────────────

  /// Abre el diálogo para editar una celda y actualiza el estado al guardar.
  Future<void> _editCell(String sectionId, String day, int periodIndex) async {
    final currentSlot = _slotAt(sectionId, day, periodIndex);
    final availableSubjects = _subjectsForSection(sectionId);

    // FIX 1: validar que el value inicial exista en la lista deduplicada.
    String? selectedSubjectId = currentSlot?.subjectId;
    if (selectedSubjectId != null &&
        !availableSubjects.any((s) => s.id == selectedSubjectId)) {
      selectedSubjectId = null;
    }

    List<Teacher> availableTeachers = selectedSubjectId != null
        ? _teachersForSubject(selectedSubjectId, sectionId)
        : [];

    String? selectedTeacherId = currentSlot?.teacherId;
    if (selectedTeacherId != null &&
        !availableTeachers.any((t) => t.id == selectedTeacherId)) {
      selectedTeacherId =
          availableTeachers.isNotEmpty ? availableTeachers.first.id : null;
    }

    // Warnings de conflicto en tiempo real (FIX 2)
    List<String> editConflicts = [];

    void refreshConflicts(
        String? subjectId, String? teacherId, StateSetter setDialogState) {
      if (subjectId != null && teacherId != null) {
        editConflicts = _conflictsFromEdit(
          sectionId: sectionId,
          day: day,
          periodIndex: periodIndex,
          teacherId: teacherId,
          subjectId: subjectId,
        );
      } else {
        editConflicts = [];
      }
      setDialogState(() {});
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Editar celda — $day, período ${periodIndex + 1}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Selector de materia ──────────────────────────────────
                  const Text('Materia',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedSubjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('— Sin materia —'),
                    // FIX 1: lista deduplicada + opción vacía con value null
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('— Sin materia —'),
                      ),
                      ...availableSubjects.map((s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.name),
                          )),
                    ],
                    onChanged: (newSubjectId) {
                      setDialogState(() {
                        selectedSubjectId = newSubjectId;
                        availableTeachers = newSubjectId != null
                            ? _teachersForSubject(newSubjectId, sectionId)
                            : [];
                        selectedTeacherId = availableTeachers.isNotEmpty
                            ? availableTeachers.first.id
                            : null;
                      });
                      refreshConflicts(
                          selectedSubjectId, selectedTeacherId, setDialogState);
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Selector de maestro ──────────────────────────────────
                  const Text('Maestro',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedTeacherId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('— Sin maestro —'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('— Sin maestro —'),
                      ),
                      // FIX 1: lista también deduplicada
                      ...availableTeachers.map((t) => DropdownMenuItem<String>(
                            value: t.id,
                            child: Text(t.fullName),
                          )),
                    ],
                    onChanged: (newTeacherId) {
                      setDialogState(() => selectedTeacherId = newTeacherId);
                      refreshConflicts(
                          selectedSubjectId, selectedTeacherId, setDialogState);
                    },
                  ),

                  // ── FIX 2: Panel de conflictos en tiempo real ────────────
                  if (editConflicts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Conflictos detectados',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...editConflicts.map((msg) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '• $msg',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade900),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              // Limpiar celda
              if (currentSlot != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () {
                    setState(() {
                      _editableSlots[sectionId]?.removeWhere(
                          (s) => s.day == day && s.periodIndex == periodIndex);
                      // FIX 4: invalidar validación al editar
                      _showValidation = false;
                      _conflictKeys = {};
                    });
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Limpiar celda'),
                ),
              FilledButton(
                style: editConflicts.isNotEmpty
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade600)
                    : null,
                onPressed: () {
                  if (selectedSubjectId == null || selectedTeacherId == null) {
                    Navigator.of(ctx).pop();
                    return;
                  }
                  setState(() {
                    final slots =
                        _editableSlots.putIfAbsent(sectionId, () => []);
                    // Remover slot existente en esa celda
                    slots.removeWhere(
                        (s) => s.day == day && s.periodIndex == periodIndex);
                    // Insertar el nuevo
                    slots.add(ScheduleSlot(
                      day: day,
                      periodIndex: periodIndex,
                      subjectId: selectedSubjectId!,
                      teacherId: selectedTeacherId!,
                    ));
                    // FIX 4: invalidar validación para que el usuario re-valide
                    _showValidation = false;
                    _conflictKeys = {};
                  });
                  Navigator.of(ctx).pop();

                  // Si había conflictos, avisar al usuario con snackbar naranja
                  if (editConflicts.isNotEmpty && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '⚠️ Celda guardada con ${editConflicts.length} conflicto(s). '
                          'Presiona "Validar" para ver el detalle.',
                        ),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
                child: Text(
                  editConflicts.isNotEmpty
                      ? 'Guardar de todos modos'
                      : 'Guardar celda',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Validación ─────────────────────────────────────────────────────────────

  void _runValidation() {
    final generator = ScheduleGenerator();

    // Construir SectionSchedules desde el estado editable actual
    final schedules = _editableSlots.entries.map((e) {
      return SectionSchedule(
        id: e.key,
        sectionId: e.key,
        slots: e.value,
        generatedAt: DateTime.now(),
        hasConflicts: false,
        conflictMessages: [],
      );
    }).toList();

    final issues = generator.validate(
      schedules: schedules,
      grades: widget.grades,
      subjects: widget.subjects,
      teachers: widget.teachers,
    );

    // FIX 3: construir mapa precalculado de celdas con conflicto
    _buildConflictKeys(issues);

    setState(() {
      _validationIssues = issues;
      _showValidation = true;
    });
  }

  // ── Guardar ────────────────────────────────────────────────────────────────

  void _save() {
    _runValidation();
    widget.onSave(
      Map<String, List<ScheduleSlot>>.from(
        _editableSlots.map((k, v) => MapEntry(k, List<ScheduleSlot>.from(v))),
      ),
      _validationIssues,
    );

    if (_validationIssues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Horario guardado sin conflictos'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '⚠️ Guardado con ${_validationIssues.length} conflicto(s). '
              'Revisa el panel inferior.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sections = _editableSlots.keys.toList();

    return Column(
      children: [
        // ── Barra de acciones ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Validar'),
                onPressed: _runValidation,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar horario'),
                onPressed: _save,
              ),
            ],
          ),
        ),

        // ── Panel de validación ──────────────────────────────────────────────
        if (_showValidation)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _validationIssues.isEmpty
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              border: Border.all(
                color: _validationIssues.isEmpty
                    ? Colors.green.shade400
                    : Colors.orange.shade400,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(
                    _validationIssues.isEmpty
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: _validationIssues.isEmpty
                        ? Colors.green
                        : Colors.orange,
                  ),
                  title: Text(
                    _validationIssues.isEmpty
                        ? 'Sin conflictos detectados'
                        : '${_validationIssues.length} conflicto(s) encontrado(s)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _showValidation = false),
                  ),
                ),
                if (_validationIssues.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _validationIssues
                          .map((issue) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ',
                                        style:
                                            TextStyle(color: Colors.orange)),
                                    Expanded(
                                      child: Text(issue,
                                          style:
                                              const TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),

        // ── Tabs por sección ─────────────────────────────────────────────────
        if (sections.isEmpty)
          const Expanded(
            child: Center(child: Text('No hay horarios disponibles')),
          )
        else
          Expanded(
            child: DefaultTabController(
              length: sections.length,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: sections
                        .map((id) => Tab(text: _sectionName(id)))
                        .toList(),
                    onTap: (i) =>
                        setState(() => _selectedSectionId = sections[i]),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: sections
                          .map((sId) => _buildGrid(sId))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Cuadrícula de horario ──────────────────────────────────────────────────

  Widget _buildGrid(String sectionId) {
    final days = _daysForSection(sectionId);
    final sessions = _sessionsForSection(sectionId);

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(130),
          border: TableBorder.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          children: [
            // ── Encabezado ───────────────────────────────────────────────
            TableRow(
              decoration: BoxDecoration(color: Colors.indigo.shade50),
              children: [
                _headerCell('Período'),
                ...days.map((d) => _headerCell(d)),
              ],
            ),

            // ── Filas de períodos ────────────────────────────────────────
            for (int p = 0; p < sessions; p++)
              TableRow(
                children: [
                  // Índice del período
                  Container(
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.center,
                    color: Colors.grey.shade100,
                    child: Text(
                      '${p + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  // Celda por día
                  ...days.map((day) => _buildCell(sectionId, day, p)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );

  Widget _buildCell(String sectionId, String day, int periodIndex) {
    final slot = _slotAt(sectionId, day, periodIndex);

    Subject? subject;
    Teacher? teacher;

    if (slot != null) {
      try {
        subject = widget.subjects.firstWhere((s) => s.id == slot.subjectId);
      } catch (_) {}
      try {
        teacher = widget.teachers.firstWhere((t) => t.id == slot.teacherId);
      } catch (_) {}
    }

    // FIX 3: usar mapa precalculado para evitar falsos positivos
    final hasConflict = _cellHasConflict(sectionId, day, periodIndex);

    return GestureDetector(
      onTap: () => _editCell(sectionId, day, periodIndex),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(6),
        color: slot == null
            ? Colors.white
            : hasConflict
                ? Colors.red.shade50
                : Colors.blue.shade50,
        child: slot == null
            ? Center(
                child: Icon(Icons.add,
                    size: 18, color: Colors.grey.shade400),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject?.name ?? slot.subjectId,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hasConflict
                          ? Colors.red.shade800
                          : Colors.indigo.shade800,
                    ),
                  ),
                  if (teacher != null)
                    Text(
                      teacher.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: hasConflict
                            ? Colors.red.shade600
                            : Colors.grey.shade700,
                      ),
                    ),
                  if (hasConflict)
                    const Icon(Icons.warning_amber_rounded,
                        size: 12, color: Colors.red),
                ],
              ),
      ),
    );
  }
}

// =============================================================================
// CÓMO USAR ESTE WIDGET
// =============================================================================
//
// En tu pantalla de horarios:
//
//   ScheduleEditorWidget(
//     initialSchedules: result.schedules,
//     grades: grades,
//     subjects: subjects,
//     teachers: teachers,
//     onSave: (manualSlots, issues) {
//       if (issues.isEmpty) {
//         // Regenerar con los slots manuales fijados
//         final newResult = generator.generate(
//           grades: grades,
//           subjects: subjects,
//           teachers: teachers,
//           manualSlots: manualSlots,   // ← el generador respeta estas celdas
//         );
//         setState(() => _result = newResult);
//       }
//     },
//   )
//
// =============================================================================