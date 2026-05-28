import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/schedule_generator.dart';
import '../services/import_export_service.dart';
import '../theme/app_theme.dart';
import '../services/conflict_resolver.dart';

export '../services/import_export_service.dart'
    show
        ImportExportService,
        SchoolConfig,
        ExportResult,
        ImportResult,
        ImportExportException,
        ImportExportErrorKind;

enum AppScreen {
  dashboard,
  levels,
  subjects,
  teachers,
  schedules,
  visualization,
  conflictResolution,
}

// ─── Structured conflict data ─────────────────────────────────────────────────

/// One side of a teacher double-booking conflict.
class ConflictSlotInfo {
  final String sectionId;
  final String sectionLabel; // e.g. "1ro A"
  final Subject? subject;
  const ConflictSlotInfo({
    required this.sectionId,
    required this.sectionLabel,
    this.subject,
  });
}

/// A single teacher-conflict event (one teacher, one timeslot, two+ sections).
class ConflictInfo {
  final Teacher teacher;
  final String day;
  final int periodIndex;

  /// The clashing slots — always 2 or more entries.
  final List<ConflictSlotInfo> slots;
  const ConflictInfo({
    required this.teacher,
    required this.day,
    required this.periodIndex,
    required this.slots,
  });
}

class AppProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  final StorageService _storage = StorageService();
  final ScheduleGenerator _generator = ScheduleGenerator();
  final ImportExportService _importExport = ImportExportService();

  // ─── State ───────────────────────────────────
  AppScreen currentScreen = AppScreen.dashboard;
  bool isLoading = false;
  String? errorMessage;

  List<EducationalLevel> levels = [];
  List<Grade> grades = [];
  List<Subject> subjects = [];
  List<Teacher> teachers = [];
  List<SectionSchedule> schedules = [];

  final Map<String, List<ScheduleSlot>> manualSlots = {};

  // Filter state
  String? filterLevelId;
  String? filterGradeId;
  String? filterSectionId;
  String? filterTeacherId;

  // ─── Init ────────────────────────────────────
  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    try {
      levels = await _storage.loadLevels();
      grades = await _storage.loadGrades();
      subjects = await _storage.loadSubjects();
      teachers = await _storage.loadTeachers();
      schedules = await _storage.loadSchedules();

      // Migrate legacy teachers that have sectionIds but no assignments.
      teachers = _migrateLegacyTeachers(teachers);
    } catch (e) {
      errorMessage = 'Error al cargar datos: $e';
    }
    isLoading = false;
    notifyListeners();
  }

  /// Reemplaza completamente la lista de horarios (p.ej. después de
  /// que el ConflictResolutionScreen aplica una sugerencia) y persiste.
  Future<void> replaceSchedules(List<SectionSchedule> updated) async {
    schedules = updated;
    await _storage.saveSchedules(updated);
    notifyListeners();
  }

  // ─── Import / Export ─────────────────────────────────────────────────────

  /// Exports the current school configuration to a versioned JSON file.
  ///
  /// Pass [includeSchedules] = false to export only the structural config
  /// (levels, grades, subjects, teachers) without generated timetables.
  Future<ExportResult> exportConfig({
    bool includeSchedules = true,
    String suggestedName = 'school_config',
  }) async {
    final config = SchoolConfig(
      levels: levels,
      grades: grades,
      subjects: subjects,
      teachers: teachers,
      schedules: includeSchedules ? schedules : const [],
    );
    return _importExport.exportConfig(config, suggestedName: suggestedName);
  }

  /// Opens the file picker, reads and validates the selected JSON file, then
  /// — on success — *replaces* the entire in-memory state and persists it.
  ///
  /// Returns an [ImportResult] so the calling widget can show appropriate
  /// feedback without knowing internal details.
  ///
  /// The previous data is only overwritten when the import succeeds, so a
  /// failed import leaves the app in its original state.
  Future<ImportResult> importConfig() async {
    final result = await _importExport.importConfig();
    if (!result.success || result.config == null) return result;

    isLoading = true;
    notifyListeners();

    try {
      final cfg = result.config!;

      levels = cfg.levels;
      grades = cfg.grades;
      subjects = cfg.subjects;
      teachers = _migrateLegacyTeachers(cfg.teachers);
      schedules = cfg.schedules;
      manualSlots.clear();

      // Reset any active filters so the UI reflects the new data cleanly.
      filterLevelId = null;
      filterGradeId = null;
      filterSectionId = null;
      filterTeacherId = null;

      // Persist every entity via SharedPreferences.
      await Future.wait([
        _storage.saveLevels(levels),
        _storage.saveGrades(grades),
        _storage.saveSubjects(subjects),
        _storage.saveTeachers(teachers),
        _storage.saveSchedules(schedules),
      ]);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return ImportResult.fail('Error al aplicar la importación: $e');
    }

    isLoading = false;
    notifyListeners();
    return result;
  }

  // ─── Legacy migration ─────────────────────────
  //
  // Old Teacher records stored a flat List<String> sectionIds.
  // We convert those to TeacherSubjectAssignment entries by resolving each
  // sectionId to its gradeId through the loaded grades list.
  List<Teacher> _migrateLegacyTeachers(List<Teacher> raw) {
    bool anyMigrated = false;
    final migrated = raw.map((t) {
      if (t.legacySectionIds.isEmpty) return t;

      anyMigrated = true;
      final newAssignments = <TeacherSubjectAssignment>[];

      for (final sectionId in t.legacySectionIds) {
        final grade = _findGradeForSection(sectionId);
        if (grade == null) continue;

        for (final subjectId in t.subjectIds) {
          final candidate = TeacherSubjectAssignment(
            subjectId: subjectId,
            gradeId: grade.id,
            sectionId: sectionId == grade.id ? null : sectionId,
          );
          if (!newAssignments.contains(candidate)) {
            newAssignments.add(candidate);
          }
        }
      }

      return t.copyWith(
        assignments: newAssignments,
        legacySectionIds: const [],
        sectionIds: [],
      );
    }).toList();

    if (anyMigrated) {
      _storage.saveTeachers(migrated);
    }

    return migrated;
  }

  Grade? _findGradeForSection(String sectionId) {
    for (final g in grades) {
      if (g.id == sectionId) return g;
      if (g.sections.any((s) => s.id == sectionId)) return g;
    }
    return null;
  }

  void navigate(AppScreen screen) {
    currentScreen = screen;
    notifyListeners();
  }

  // ─── Derived helpers ─────────────────────────

  List<Grade> gradesForLevel(String levelId) =>
      grades.where((g) => g.levelId == levelId).toList();

  List<Section> get allSections => grades.expand((g) => g.sections).toList();

  List<Section> get allSchedulableUnits {
    final result = <Section>[];
    for (final g in grades) {
      if (g.sections.isNotEmpty) {
        result.addAll(g.sections);
      } else {
        result.add(Section(
          id: g.id,
          name: g.name,
          gradeId: g.id,
          levelId: g.levelId,
        ));
      }
    }
    return result;
  }

  List<Section> sectionsForGrade(String gradeId) {
    try {
      final g = grades.firstWhere((g) => g.id == gradeId);
      if (g.sections.isNotEmpty) return g.sections;
      return [
        Section(id: g.id, name: g.name, gradeId: g.id, levelId: g.levelId)
      ];
    } catch (_) {
      return [];
    }
  }

  Grade? gradeForSection(String sectionId) {
    try {
      return grades.firstWhere(
          (g) => g.sections.any((s) => s.id == sectionId) || g.id == sectionId);
    } catch (_) {
      return null;
    }
  }

  Section? findSection(String sectionId) {
    for (final g in grades) {
      try {
        return g.sections.firstWhere((s) => s.id == sectionId);
      } catch (_) {}
    }
    try {
      final g = grades.firstWhere((g) => g.id == sectionId);
      return Section(id: g.id, name: g.name, gradeId: g.id, levelId: g.levelId);
    } catch (_) {}
    return null;
  }

  Subject? findSubject(String id) {
    try {
      return subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Teacher? findTeacher(String id) {
    try {
      return teachers.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  EducationalLevel? findLevel(String id) {
    try {
      return levels.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  Grade? findGrade(String id) {
    try {
      return grades.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  SectionSchedule? scheduleForSection(String sectionId) {
    try {
      return schedules.firstWhere((s) => s.sectionId == sectionId);
    } catch (_) {
      return null;
    }
  }

  int get totalStudentGroups => allSchedulableUnits.length;
  int get scheduledSections => schedules.length;

  // ─── Dashboard stats ─────────────────────────

  Map<String, int> get stats => {
        'levels': levels.length,
        'grades': grades.length,
        'sections': allSections.length,
        'subjects': subjects.length,
        'teachers': teachers.length,
        'schedules': schedules.length,
      };

  // ─── Educational Levels ──────────────────────

  Future<void> addLevel(EducationalLevel level) async {
    levels = [...levels, level];
    await _storage.saveLevels(levels);
    notifyListeners();
  }

  Future<void> updateLevel(EducationalLevel level) async {
    levels = levels.map((l) => l.id == level.id ? level : l).toList();

    grades = grades.map((g) {
      if (g.levelId != level.id) return g;
      return g.copyWith(
        config: g.config.copyWith(
          fridayEarlyDismissal: level.scheduledDismissal,
          fridayLastSession:
              level.scheduledDismissal ? level.dismissalSessionIndex : -1,
        ),
      );
    }).toList();

    await _storage.saveLevels(levels);
    await _storage.saveGrades(grades);
    notifyListeners();
  }

  Future<void> deleteLevel(String id) async {
    final gradesToDelete = grades.where((g) => g.levelId == id).toList();
    final sectionIds =
        gradesToDelete.expand((g) => g.sections).map((s) => s.id).toSet();
    final gradeIds = gradesToDelete.map((g) => g.id).toSet();

    grades = grades.where((g) => g.levelId != id).toList();
    subjects = subjects
        .map((s) => s.copyWith(
              levelConfigs:
                  s.levelConfigs.where((c) => c.levelId != id).toList(),
            ))
        .where((s) => s.levelIds.isNotEmpty)
        .toList();
    schedules = schedules
        .where((s) =>
            !sectionIds.contains(s.sectionId) &&
            !gradeIds.contains(s.sectionId))
        .toList();
    for (final sid in {...sectionIds, ...gradeIds}) manualSlots.remove(sid);

    teachers = teachers
        .map((t) => t.copyWith(
              assignments: t.assignments
                  .where((a) =>
                      !gradeIds.contains(a.gradeId) &&
                      (a.sectionId == null ||
                          !sectionIds.contains(a.sectionId)))
                  .toList(),
              sectionIds: [],
            ))
        .toList();

    levels = levels.where((l) => l.id != id).toList();

    await _storage.saveLevels(levels);
    await _storage.saveGrades(grades);
    await _storage.saveSubjects(subjects);
    await _storage.saveTeachers(teachers);
    await _storage.saveSchedules(schedules);
    notifyListeners();
  }

  // ─── Grades ──────────────────────────────────

  Future<void> addGrade(Grade grade) async {
    grades = [...grades, grade];
    await _storage.saveGrades(grades);
    notifyListeners();
  }

  Future<void> updateGrade(Grade grade) async {
    grades = grades.map((g) => g.id == grade.id ? grade : g).toList();
    await _storage.saveGrades(grades);
    notifyListeners();
  }

  Future<void> deleteGrade(String id) async {
    final sectionIds = grades
        .where((g) => g.id == id)
        .expand((g) => g.sections)
        .map((s) => s.id)
        .toSet();

    schedules = schedules
        .where((s) => !sectionIds.contains(s.sectionId) && s.sectionId != id)
        .toList();
    for (final sid in {...sectionIds, id}) manualSlots.remove(sid);

    teachers = teachers
        .map((t) => t.copyWith(
              assignments: t.assignments
                  .where((a) =>
                      a.gradeId != id &&
                      (a.sectionId == null ||
                          !sectionIds.contains(a.sectionId)))
                  .toList(),
              sectionIds: [],
            ))
        .toList();

    grades = grades.where((g) => g.id != id).toList();
    await _storage.saveGrades(grades);
    await _storage.saveSchedules(schedules);
    await _storage.saveTeachers(teachers);
    notifyListeners();
  }

  Future<void> addSectionToGrade(String gradeId, Section section) async {
    grades = grades.map((g) {
      if (g.id != gradeId) return g;
      return g.copyWith(sections: [...g.sections, section]);
    }).toList();
    await _storage.saveGrades(grades);
    notifyListeners();
  }

  Future<void> updateSection(String gradeId, Section section) async {
    grades = grades.map((g) {
      if (g.id != gradeId) return g;
      return g.copyWith(
          sections:
              g.sections.map((s) => s.id == section.id ? section : s).toList());
    }).toList();
    await _storage.saveGrades(grades);
    notifyListeners();
  }

  Future<void> deleteSection(String gradeId, String sectionId) async {
    grades = grades.map((g) {
      if (g.id != gradeId) return g;
      return g.copyWith(
          sections: g.sections.where((s) => s.id != sectionId).toList());
    }).toList();
    schedules = schedules.where((s) => s.sectionId != sectionId).toList();
    manualSlots.remove(sectionId);

    teachers = teachers
        .map((t) => t.copyWith(
              assignments:
                  t.assignments.where((a) => a.sectionId != sectionId).toList(),
              sectionIds: [],
            ))
        .toList();

    await _storage.saveGrades(grades);
    await _storage.saveSchedules(schedules);
    await _storage.saveTeachers(teachers);
    notifyListeners();
  }

  String generateId() => _uuid.v4();

  // ─── Subjects ────────────────────────────────

  Future<void> addSubject(Subject subject) async {
    subjects = [...subjects, subject];
    await _storage.saveSubjects(subjects);
    notifyListeners();
  }

  Future<void> updateSubject(Subject subject) async {
    subjects = subjects.map((s) => s.id == subject.id ? subject : s).toList();
    await _storage.saveSubjects(subjects);
    notifyListeners();
  }

  Future<void> deleteSubject(String id) async {
    teachers = teachers
        .map((t) => t.copyWith(
              subjectIds: t.subjectIds.where((sid) => sid != id).toList(),
              assignments:
                  t.assignments.where((a) => a.subjectId != id).toList(),
              sectionIds: [],
            ))
        .toList();

    schedules = schedules
        .map((s) => s.copyWith(
              slots: s.slots.where((sl) => sl.subjectId != id).toList(),
            ))
        .toList();
    for (final entry in manualSlots.entries) {
      manualSlots[entry.key] =
          entry.value.where((sl) => sl.subjectId != id).toList();
    }
    subjects = subjects.where((s) => s.id != id).toList();
    await _storage.saveSubjects(subjects);
    await _storage.saveTeachers(teachers);
    await _storage.saveSchedules(schedules);
    notifyListeners();
  }

  int get nextSubjectColorIndex =>
      subjects.length % AppTheme.subjectColors.length;

  // ─── Teachers ────────────────────────────────

  Future<void> addTeacher(Teacher teacher) async {
    teachers = [...teachers, teacher];
    await _storage.saveTeachers(teachers);
    notifyListeners();
  }

  Future<void> updateTeacher(Teacher teacher) async {
    teachers = teachers.map((t) => t.id == teacher.id ? teacher : t).toList();
    await _storage.saveTeachers(teachers);
    notifyListeners();
  }

  Future<void> deleteTeacher(String id) async {
    schedules = schedules
        .map((s) => s.copyWith(
              slots: s.slots.where((sl) => sl.teacherId != id).toList(),
            ))
        .toList();
    for (final entry in manualSlots.entries) {
      manualSlots[entry.key] =
          entry.value.where((sl) => sl.teacherId != id).toList();
    }
    teachers = teachers.where((t) => t.id != id).toList();
    await _storage.saveTeachers(teachers);
    await _storage.saveSchedules(schedules);
    notifyListeners();
  }

  // ─── Manual Slot Editing ─────────────────────

  Future<void> updateSlot({
    required String sectionId,
    required String day,
    required int periodIndex,
    String? subjectId,
    String? teacherId,
  }) async {
    schedules = schedules.map((s) {
      if (s.sectionId != sectionId) return s;
      final updatedSlots = s.slots
          .where((sl) => !(sl.day == day && sl.periodIndex == periodIndex))
          .toList();
      if (subjectId != null && teacherId != null) {
        updatedSlots.add(ScheduleSlot(
          day: day,
          periodIndex: periodIndex,
          subjectId: subjectId,
          teacherId: teacherId,
        ));
      }
      return s.copyWith(slots: updatedSlots);
    }).toList();
    await _storage.saveSchedules(schedules);
    notifyListeners();
  }

  // ─── Schedule Generation ─────────────────────

  Future<GenerationResult> generateSchedules() async {
    isLoading = true;
    notifyListeners();

    final result = _generator.generate(
      grades: grades,
      subjects: subjects,
      teachers: teachers,
      manualSlots: manualSlots,
    );

    schedules = result.schedules;
    await _storage.saveSchedules(schedules);

    isLoading = false;
    notifyListeners();
    return result;
  }

  Future<void> clearSchedules() async {
    schedules = [];
    await _storage.saveSchedules(schedules);
    notifyListeners();
  }

  /// Borra absolutamente toda la información ingresada en la app:
  /// niveles, grados, secciones, materias, maestros, horarios y slots manuales.
  /// También limpia SharedPreferences por completo.
  Future<void> clearAllData() async {
    levels = [];
    grades = [];
    subjects = [];
    teachers = [];
    schedules = [];
    manualSlots.clear();
    filterLevelId = null;
    filterGradeId = null;
    filterSectionId = null;
    filterTeacherId = null;
    currentScreen = AppScreen.dashboard;
    await _storage.clearAll();
    notifyListeners();
  }

  // ─── Validation ──────────────────────────────

  List<String> validateSchedules() {
    return _generator.validate(
      schedules: schedules,
      grades: grades,
      subjects: subjects,
      teachers: teachers,
    );
  }

  /// Returns a structured list of teacher double-booking conflicts so the UI
  /// can display them interactively and let the user resolve each one.
  List<ConflictInfo> get conflictDetails {
    final Set<String> legitimateSharedKeys = {};
    for (final subj in subjects) {
      for (final cfg in subj.levelConfigs) {
        for (final block in cfg.sharedBlocks) {
          if (block.sectionIds.length < 2) continue;
          final sorted = List<String>.from(block.sectionIds)..sort();
          legitimateSharedKeys.add('${sorted.join(",")}|${subj.id}');
        }
      }
    }

    final teacherSlots = <String, Map<String, List<String>>>{};

    for (final sched in schedules) {
      for (final slot in sched.slots) {
        teacherSlots
            .putIfAbsent(slot.teacherId, () => {})
            .putIfAbsent('${slot.day}|||${slot.periodIndex}', () => [])
            .add(sched.sectionId);
      }
    }

    final result = <ConflictInfo>[];

    for (final teacherEntry in teacherSlots.entries) {
      final teacher = findTeacher(teacherEntry.key);
      if (teacher == null) continue;

      for (final slotEntry in teacherEntry.value.entries) {
        final sectionIds = slotEntry.value.toSet().toList();
        if (sectionIds.length <= 1) continue;

        final parts = slotEntry.key.split('|||');
        final day = parts[0];
        final period = int.tryParse(parts[1]) ?? -1;

        final subjectIds = sectionIds
            .map((sId) {
              try {
                final sched = schedules.firstWhere((s) => s.sectionId == sId);
                return sched.getSlot(day, period)?.subjectId;
              } catch (_) {
                return null;
              }
            })
            .whereType<String>()
            .toSet();

        if (subjectIds.length <= 1) {
          final sortedSections = sectionIds.toList()..sort();
          final key =
              '${sortedSections.join(",")}|${subjectIds.firstOrNull ?? ""}';
          if (legitimateSharedKeys.contains(key)) continue;
        }

        final conflictSlots = sectionIds.map((sId) {
          Subject? subj;
          try {
            final sched = schedules.firstWhere((s) => s.sectionId == sId);
            final sid = sched.getSlot(day, period)?.subjectId;
            if (sid != null) subj = findSubject(sid);
          } catch (_) {}

          final section = findSection(sId);
          String label = sId;
          if (section != null) {
            final grade = findGrade(section.gradeId);
            label = grade != null
                ? '${grade.name} – ${section.name}'
                : section.name;
          }
          return ConflictSlotInfo(
              sectionId: sId, sectionLabel: label, subject: subj);
        }).toList();

        result.add(ConflictInfo(
          teacher: teacher,
          day: day,
          periodIndex: period,
          slots: conflictSlots,
        ));
      }
    }

    result.sort((a, b) => a.teacher.fullName.compareTo(b.teacher.fullName));
    return result;
  }

  // ─── Filters ─────────────────────────────────

  void setFilter({
    String? levelId,
    String? gradeId,
    String? sectionId,
    String? teacherId,
    bool clearAll = false,
  }) {
    if (clearAll) {
      filterLevelId = null;
      filterGradeId = null;
      filterSectionId = null;
      filterTeacherId = null;
    } else {
      filterLevelId = levelId;
      filterGradeId = gradeId;
      filterSectionId = sectionId;
      filterTeacherId = teacherId;
    }
    notifyListeners();
  }

  List<SectionSchedule> get filteredSchedules {
    if (filterSectionId != null) {
      return schedules.where((s) => s.sectionId == filterSectionId).toList();
    }
    if (filterGradeId != null) {
      final ids = sectionsForGrade(filterGradeId!).map((s) => s.id).toSet();
      ids.add(filterGradeId!);
      return schedules.where((s) => ids.contains(s.sectionId)).toList();
    }
    if (filterLevelId != null) {
      final gradeIds = gradesForLevel(filterLevelId!).map((g) => g.id).toSet();
      final sectionIds = grades
          .where((g) => gradeIds.contains(g.id))
          .expand((g) => g.sections)
          .map((s) => s.id)
          .toSet();
      return schedules
          .where((s) =>
              sectionIds.contains(s.sectionId) ||
              gradeIds.contains(s.sectionId))
          .toList();
    }
    if (filterTeacherId != null) {
      return schedules
          .where((s) => s.slots.any((sl) => sl.teacherId == filterTeacherId))
          .toList();
    }
    return schedules;
  }
}
