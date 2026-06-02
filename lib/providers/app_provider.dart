import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/schedule_generator.dart';
import '../services/import_export_service.dart';
import '../theme/app_theme.dart';

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

      // Migrate legacy levels that were created before sortOrder existed.
      // If all levels share the same sortOrder value (e.g. all 0), they were
      // never stamped — assign 0..n based on their current list position so
      // allSchedulableUnits can group them correctly from the very first load.
      levels = _migrateLevelSortOrder(levels);
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

      levels = _migrateLevelSortOrder(cfg.levels);
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

  /// Stamps [sortOrder] on levels that were created before the field existed.
  /// Detection: if all levels have the same sortOrder (typically all 0), they
  /// were never properly ordered — assign indices 0..n based on list position
  /// and persist so subsequent loads use the correct order.
  List<EducationalLevel> _migrateLevelSortOrder(List<EducationalLevel> raw) {
    if (raw.isEmpty) return raw;
    final allSame = raw.every((l) => l.sortOrder == raw.first.sortOrder);
    if (!allSame) return raw; // already stamped — nothing to do
    final stamped = [
      for (var i = 0; i < raw.length; i++) raw[i].copyWith(sortOrder: i),
    ];
    _storage.saveLevels(stamped);
    return stamped;
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

  List<Grade> gradesForLevel(String levelId) {
    final result = grades.where((g) => g.levelId == levelId).toList();
    result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result;
  }

  List<Section> get allSections {
    final result = <Section>[];
    // Sort levels first, then grades within each level, then sections within each grade.
    final sortedLevels = [...levels]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final lvl in sortedLevels) {
      final levelGrades = grades.where((g) => g.levelId == lvl.id).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final g in levelGrades) {
        final sorted = [...g.sections]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        result.addAll(sorted);
      }
    }
    return result;
  }

  List<Section> get allSchedulableUnits {
    final result = <Section>[];
    // Sort levels first, then grades within each level, then sections within each grade.
    final sortedLevels = [...levels]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final lvl in sortedLevels) {
      final levelGrades = grades.where((g) => g.levelId == lvl.id).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final g in levelGrades) {
        if (g.sections.isNotEmpty) {
          final sorted = [...g.sections]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          result.addAll(sorted);
        } else {
          result.add(Section(
            id: g.id,
            name: g.name,
            gradeId: g.id,
            levelId: g.levelId,
          ));
        }
      }
    }
    return result;
  }

  List<Section> sectionsForGrade(String gradeId) {
    try {
      final g = grades.firstWhere((g) => g.id == gradeId);
      if (g.sections.isNotEmpty) {
        final sorted = [...g.sections]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return sorted;
      }
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
    // Stamp sortOrder so new levels always go to the end of the list.
    final maxOrder = levels.isEmpty ? -1 : levels.map((l) => l.sortOrder).reduce((a, b) => a > b ? a : b);
    final stamped = level.copyWith(sortOrder: maxOrder + 1);
    levels = [...levels, stamped];
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
    // Stamp sortOrder so new grades always go to the end of their level.
    final existing = grades.where((g) => g.levelId == grade.levelId);
    final maxOrder = existing.isEmpty ? -1 : existing.map((g) => g.sortOrder).reduce((a, b) => a > b ? a : b);
    final stamped = grade.copyWith(sortOrder: maxOrder + 1);
    debugPrint('[GRADE ADD] fridayEarlyDismissal=${stamped.config.fridayEarlyDismissal} '
        'fridayLastSession=${stamped.config.fridayLastSession} '
        'sessionsPerDay=${stamped.config.sessionsPerDay}');
    grades = [...grades, stamped];
    await _storage.saveGrades(grades);
    notifyListeners();
  }

  Future<void> updateGrade(Grade grade) async {
    debugPrint('[GRADE SAVE] fridayEarlyDismissal=\${grade.config.fridayEarlyDismissal} '
        'fridayLastSession=\${grade.config.fridayLastSession} '
        'sessionsPerDay=\${grade.config.sessionsPerDay}');
    grades = grades.map((g) => g.id == grade.id ? grade : g).toList();
    await _storage.saveGrades(grades);
    debugPrint('[GRADE SAVED] Verifying stored: \${grades.firstWhere((g) => g.id == grade.id).config.fridayLastSession}');
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
      // Stamp sortOrder so new sections always go to the end of their grade.
      final maxOrder = g.sections.isEmpty ? -1 : g.sections.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b);
      final stamped = section.copyWith(sortOrder: maxOrder + 1);
      return g.copyWith(sections: [...g.sections, stamped]);
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

  // ─── Drag-and-drop reordering ─────────────────────────────────────────────

  /// Reorders the [EducationalLevel] list. [oldIndex] and [newIndex] are the
  /// indices in the *currently displayed* list (same as [levels]).
  Future<void> reorderLevels(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final list = [...levels]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    // Re-stamp sortOrder values 0..n in new order (same pattern as reorderGrades).
    for (var i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(sortOrder: i);
    }
    levels = list;
    await _storage.saveLevels(levels);
    notifyListeners();
  }

  /// Reorders grades within a level identified by [levelId].
  Future<void> reorderGrades(String levelId, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    // Work on the sorted subset for this level.
    final levelGrades = gradesForLevel(levelId); // already sorted by sortOrder
    final moved = levelGrades.removeAt(oldIndex);
    levelGrades.insert(newIndex, moved);
    // Re-stamp sortOrder values 0..n in new order.
    for (var i = 0; i < levelGrades.length; i++) {
      levelGrades[i] = levelGrades[i].copyWith(sortOrder: i);
    }
    // Merge back into the global grades list, preserving other levels.
    final updated = grades.map((g) {
      if (g.levelId != levelId) return g;
      return levelGrades.firstWhere((lg) => lg.id == g.id);
    }).toList();
    grades = updated;
    await _storage.saveGrades(grades);
    notifyListeners();
  }

  /// Reorders sections within a grade identified by [gradeId].
  Future<void> reorderSections(String gradeId, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    grades = grades.map((g) {
      if (g.id != gradeId) return g;
      final sections = [...g.sections]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final moved = sections.removeAt(oldIndex);
      sections.insert(newIndex, moved);
      // Re-stamp sortOrder values 0..n in new order.
      final reordered = [
        for (var i = 0; i < sections.length; i++)
          sections[i].copyWith(sortOrder: i),
      ];
      return g.copyWith(sections: reordered);
    }).toList();
    await _storage.saveGrades(grades);
    notifyListeners();
  }

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

  /// Returns schedules sorted according to the visual order defined by
  /// [allSchedulableUnits] (which respects [sortOrder] on grades and sections).
  /// Any schedule whose sectionId doesn't appear in [allSchedulableUnits]
  /// is appended at the end in their original insertion order.
  List<SectionSchedule> get sortedSchedules {
    final units = allSchedulableUnits;
    final orderIndex = <String, int>{
      for (var i = 0; i < units.length; i++) units[i].id: i,
    };
    return [...schedules]..sort((a, b) {
        final ia = orderIndex[a.sectionId] ?? double.maxFinite.toInt();
        final ib = orderIndex[b.sectionId] ?? double.maxFinite.toInt();
        return ia.compareTo(ib);
      });
  }

  List<SectionSchedule> get filteredSchedules {
    // Always use sortedSchedules as the base so visual order is consistent.
    final sorted = sortedSchedules;

    if (filterSectionId != null) {
      return sorted.where((s) => s.sectionId == filterSectionId).toList();
    }
    if (filterGradeId != null) {
      final ids = sectionsForGrade(filterGradeId!).map((s) => s.id).toSet();
      ids.add(filterGradeId!);
      return sorted.where((s) => ids.contains(s.sectionId)).toList();
    }
    if (filterLevelId != null) {
      final gradeIds = gradesForLevel(filterLevelId!).map((g) => g.id).toSet();
      final sectionIds = grades
          .where((g) => gradeIds.contains(g.id))
          .expand((g) => g.sections)
          .map((s) => s.id)
          .toSet();
      return sorted
          .where((s) =>
              sectionIds.contains(s.sectionId) ||
              gradeIds.contains(s.sectionId))
          .toList();
    }
    if (filterTeacherId != null) {
      return sorted
          .where((s) => s.slots.any((sl) => sl.teacherId == filterTeacherId))
          .toList();
    }
    return sorted;
  }
} 