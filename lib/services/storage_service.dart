import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static const _levelsKey = 'educational_levels';
  static const _gradesKey = 'grades';
  static const _subjectsKey = 'subjects';
  static const _teachersKey = 'teachers';
  static const _schedulesKey = 'section_schedules';

  // ─── Levels ─────────────────────────────────

  Future<List<EducationalLevel>> loadLevels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_levelsKey);
    if (raw == null) return _defaultLevels();
    final list = jsonDecode(raw) as List;
    return list.map((e) => EducationalLevel.fromJson(e)).toList();
  }

  Future<void> saveLevels(List<EducationalLevel> levels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_levelsKey, jsonEncode(levels.map((e) => e.toJson()).toList()));
  }

  List<EducationalLevel> _defaultLevels() => [
        const EducationalLevel(id: 'preschool', name: 'Preescolar', type: LevelType.preescolar),
        const EducationalLevel(id: 'primary', name: 'Primaria', type: LevelType.primaria),
        const EducationalLevel(id: 'secondary', name: 'Secundaria', type: LevelType.secundaria),
        const EducationalLevel(id: 'highschool', name: 'Preparatoria', type: LevelType.preparatoria),
      ];

  // ─── Grades ─────────────────────────────────

  Future<List<Grade>> loadGrades() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_gradesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Grade.fromJson(e)).toList();
  }

  Future<void> saveGrades(List<Grade> grades) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gradesKey, jsonEncode(grades.map((e) => e.toJson()).toList()));
  }

  // ─── Subjects ───────────────────────────────

  Future<List<Subject>> loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_subjectsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Subject.fromJson(e)).toList();
  }

  Future<void> saveSubjects(List<Subject> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subjectsKey, jsonEncode(subjects.map((e) => e.toJson()).toList()));
  }

  // ─── Teachers ───────────────────────────────

  Future<List<Teacher>> loadTeachers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_teachersKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Teacher.fromJson(e)).toList();
  }

  Future<void> saveTeachers(List<Teacher> teachers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_teachersKey, jsonEncode(teachers.map((e) => e.toJson()).toList()));
  }

  // ─── Schedules ──────────────────────────────

  Future<List<SectionSchedule>> loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_schedulesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => SectionSchedule.fromJson(e)).toList();
  }

  Future<void> saveSchedules(List<SectionSchedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _schedulesKey, jsonEncode(schedules.map((e) => e.toJson()).toList()));
  }

  // ─── Clear All ──────────────────────────────

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}