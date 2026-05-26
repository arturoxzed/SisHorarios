import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────

enum SubjectType { base, special }

extension SubjectTypeExt on SubjectType {
  String get label => this == SubjectType.base ? 'Base' : 'Especial compartida';
}

enum LevelType { preescolar, primaria, secundaria, preparatoria }

extension LevelTypeExt on LevelType {
  String get label {
    switch (this) {
      case LevelType.preescolar:   return 'Preescolar';
      case LevelType.primaria:     return 'Primaria';
      case LevelType.secundaria:   return 'Secundaria';
      case LevelType.preparatoria: return 'Preparatoria';
    }
  }
}

// ─────────────────────────────────────────────
// TEACHER SUBJECT ASSIGNMENT
// ─────────────────────────────────────────────
//
// Represents a teacher's assignment to teach a subject for a grade,
// optionally restricted to a specific section (group).
//
// Rules:
//   • gradeId is always required.
//   • sectionId is optional (null = applies to the entire grade).
//   • If sectionId is set, it must belong to the grade.
//   • A section-level assignment takes priority over a grade-level one
//     when the generator resolves eligible teachers.
//
// Examples:
//   gradeId: "1grado",  sectionId: null   → teaches Math to all of 1st grade
//   gradeId: "1grado",  sectionId: "1A"   → teaches Math only to section 1A

class TeacherSubjectAssignment {
  final String subjectId;
  final String gradeId;

  /// null = all sections of gradeId
  final String? sectionId;

  const TeacherSubjectAssignment({
    required this.subjectId,
    required this.gradeId,
    this.sectionId,
  });

  /// Whether this assignment covers a specific section.
  bool get isSpecific => sectionId != null;

  /// Whether this assignment covers the whole grade.
  bool get isGradeWide => sectionId == null;

  /// True when this assignment is eligible for a given [unitSectionId].
  /// Section-level assignments match only their own section.
  /// Grade-level assignments match any section of the grade.
  bool matchesSection(String unitSectionId, String unitGradeId) {
    if (gradeId != unitGradeId) return false;
    if (sectionId == null) return true;   // grade-wide → matches all sections
    return sectionId == unitSectionId;
  }

  TeacherSubjectAssignment copyWith({
    String? subjectId,
    String? gradeId,
    Object? sectionId = _sentinel,
  }) =>
      TeacherSubjectAssignment(
        subjectId: subjectId ?? this.subjectId,
        gradeId: gradeId ?? this.gradeId,
        sectionId: sectionId == _sentinel ? this.sectionId : sectionId as String?,
      );

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => {
        'subjectId': subjectId,
        'gradeId': gradeId,
        if (sectionId != null) 'sectionId': sectionId,
      };

  factory TeacherSubjectAssignment.fromJson(Map<String, dynamic> j) =>
      TeacherSubjectAssignment(
        subjectId: j['subjectId'] as String,
        gradeId: j['gradeId'] as String,
        sectionId: j['sectionId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is TeacherSubjectAssignment &&
      other.subjectId == subjectId &&
      other.gradeId == gradeId &&
      other.sectionId == sectionId;

  @override
  int get hashCode => Object.hash(subjectId, gradeId, sectionId);
}

// ─────────────────────────────────────────────
// EDUCATIONAL LEVEL
// ─────────────────────────────────────────────

class EducationalLevel {
  final String id;
  final String name;
  final LevelType type;

  // ── Salida programada igual para todos los grupos ────────────────────────
  /// Si true, todos los grados y grupos de este nivel salen a la misma hora
  /// todos los días de la semana.
  final bool scheduledDismissal;

  /// Índice 0-based de la última sesión del día (default 6 = sesión 7).
  final int dismissalSessionIndex;

  const EducationalLevel({
    required this.id,
    required this.name,
    required this.type,
    this.scheduledDismissal = false,
    this.dismissalSessionIndex = 6,
  });

  EducationalLevel copyWith({
    String? id,
    String? name,
    LevelType? type,
    bool? scheduledDismissal,
    int? dismissalSessionIndex,
  }) =>
      EducationalLevel(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        scheduledDismissal: scheduledDismissal ?? this.scheduledDismissal,
        dismissalSessionIndex: dismissalSessionIndex ?? this.dismissalSessionIndex,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'scheduledDismissal': scheduledDismissal,
        'dismissalSessionIndex': dismissalSessionIndex,
      };

  factory EducationalLevel.fromJson(Map<String, dynamic> j) => EducationalLevel(
        id: j['id'],
        name: j['name'],
        type: LevelType.values[j['type'] as int],
        scheduledDismissal: j['scheduledDismissal'] ?? false,
        dismissalSessionIndex: j['dismissalSessionIndex'] ?? 6,
      );
}

// ─────────────────────────────────────────────
// SUBJECT SECTION CONFIG
// ─────────────────────────────────────────────

class SubjectSectionConfig {
  final String sectionId;

  /// Total hours per week for this section (individual + shared combined).
  final int hoursPerWeek;

  final int sessionPeriods;

  /// Hours taught individually to this section only.
  /// Invariant: individualHoursPerWeek <= hoursPerWeek.
  /// Shared hours = hoursPerWeek - individualHoursPerWeek,
  /// which must match the sum of any SharedHoursBlocks covering this section.
  ///
  /// Defaults to [hoursPerWeek] when omitted (no shared hours — pure solo).
  final int individualHoursPerWeek;

  const SubjectSectionConfig({
    required this.sectionId,
    required this.hoursPerWeek,
    this.sessionPeriods = 1,
    int? individualHoursPerWeek,
  }) : individualHoursPerWeek = individualHoursPerWeek ?? hoursPerWeek;

  SubjectSectionConfig copyWith({
    String? sectionId,
    int? hoursPerWeek,
    int? sessionPeriods,
    int? individualHoursPerWeek,
  }) =>
      SubjectSectionConfig(
        sectionId: sectionId ?? this.sectionId,
        hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
        sessionPeriods: sessionPeriods ?? this.sessionPeriods,
        individualHoursPerWeek: individualHoursPerWeek ?? this.individualHoursPerWeek,
      );

  Map<String, dynamic> toJson() => {
        'sectionId': sectionId,
        'hoursPerWeek': hoursPerWeek,
        'sessionPeriods': sessionPeriods,
        'individualHoursPerWeek': individualHoursPerWeek,
      };

  factory SubjectSectionConfig.fromJson(Map<String, dynamic> j) {
    final total = (j['hoursPerWeek'] ?? 5) as int;
    return SubjectSectionConfig(
      sectionId: j['sectionId'],
      hoursPerWeek: total,
      sessionPeriods: (j['sessionPeriods'] ?? 1) as int,
      individualHoursPerWeek: (j['individualHoursPerWeek'] ?? total) as int,
    );
  }
}

// ─────────────────────────────────────────────
// SHARED HOURS BLOCK
// ─────────────────────────────────────────────

class SharedHoursBlock {
  final String id;
  final List<String> sectionIds;
  final int hoursPerWeek;

  const SharedHoursBlock({
    required this.id,
    required this.sectionIds,
    required this.hoursPerWeek,
  });

  SharedHoursBlock copyWith({
    String? id,
    List<String>? sectionIds,
    int? hoursPerWeek,
  }) =>
      SharedHoursBlock(
        id: id ?? this.id,
        sectionIds: sectionIds ?? this.sectionIds,
        hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sectionIds': sectionIds,
        'hoursPerWeek': hoursPerWeek,
      };

  factory SharedHoursBlock.fromJson(Map<String, dynamic> j) => SharedHoursBlock(
        id: j['id'] as String,
        sectionIds: List<String>.from(j['sectionIds'] ?? []),
        hoursPerWeek: (j['hoursPerWeek'] ?? 1) as int,
      );
}

// ─────────────────────────────────────────────
// SUBJECT LEVEL CONFIG
// ─────────────────────────────────────────────

class SubjectLevelConfig {
  final String levelId;
  final int hoursPerWeek;
  final int sessionPeriods;
  final List<SubjectSectionConfig> sectionConfigs;
  final List<SharedHoursBlock> sharedBlocks;

  const SubjectLevelConfig({
    required this.levelId,
    required this.hoursPerWeek,
    this.sessionPeriods = 1,
    this.sectionConfigs = const [],
    this.sharedBlocks = const [],
  });

  int hoursForSection(String sectionId) {
    try {
      return sectionConfigs.firstWhere((c) => c.sectionId == sectionId).hoursPerWeek;
    } catch (_) {
      return hoursPerWeek;
    }
  }

  /// Returns the number of hours per week that must be scheduled
  /// individually for [sectionId] (i.e. NOT as part of a shared block).
  ///
  /// If a [SubjectSectionConfig] exists for this section its explicit
  /// [individualHoursPerWeek] field is used.
  ///
  /// Otherwise the value is derived as:
  ///   individual = total - shared
  /// where [shared] is the sum of every [SharedHoursBlock] that covers
  /// [sectionId].  This guarantees individual + shared == total regardless
  /// of whether the caller filled in the optional SubjectSectionConfig.
  int individualHoursForSection(String sectionId) {
    try {
      final sc = sectionConfigs.firstWhere((c) => c.sectionId == sectionId);
      return sc.individualHoursPerWeek.clamp(0, sc.hoursPerWeek);
    } catch (_) {
      final total  = hoursForSection(sectionId);
      final shared = sharedHoursForSection(sectionId);
      return (total - shared).clamp(0, total);
    }
  }

  /// Sum of hours per week covered by [SharedHoursBlock]s for [sectionId].
  int sharedHoursForSection(String sectionId) {
    return sharedBlocks
        .where((b) => b.sectionIds.contains(sectionId))
        .fold(0, (sum, b) => sum + b.hoursPerWeek);
  }

  int periodsForSection(String sectionId) {
    try {
      return sectionConfigs.firstWhere((c) => c.sectionId == sectionId).sessionPeriods;
    } catch (_) {
      return sessionPeriods;
    }
  }

  bool get hasSectionOverrides => sectionConfigs.isNotEmpty;

  SubjectLevelConfig copyWith({
    String? levelId,
    int? hoursPerWeek,
    int? sessionPeriods,
    List<SubjectSectionConfig>? sectionConfigs,
    List<SharedHoursBlock>? sharedBlocks,
  }) =>
      SubjectLevelConfig(
        levelId: levelId ?? this.levelId,
        hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
        sessionPeriods: sessionPeriods ?? this.sessionPeriods,
        sectionConfigs: sectionConfigs ?? this.sectionConfigs,
        sharedBlocks: sharedBlocks ?? this.sharedBlocks,
      );

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'hoursPerWeek': hoursPerWeek,
        'sessionPeriods': sessionPeriods,
        'sectionConfigs': sectionConfigs.map((c) => c.toJson()).toList(),
        'sharedBlocks': sharedBlocks.map((b) => b.toJson()).toList(),
      };

  factory SubjectLevelConfig.fromJson(Map<String, dynamic> j) =>
      SubjectLevelConfig(
        levelId: j['levelId'],
        hoursPerWeek: (j['hoursPerWeek'] ?? 5) as int,
        sessionPeriods: (j['sessionPeriods'] ?? 1) as int,
        sectionConfigs: (j['sectionConfigs'] as List? ?? [])
            .map((c) => SubjectSectionConfig.fromJson(c as Map<String, dynamic>))
            .toList(),
        sharedBlocks: (j['sharedBlocks'] as List? ?? [])
            .map((b) => SharedHoursBlock.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
}

// ─────────────────────────────────────────────
// GRADE CONFIGURATION
// ─────────────────────────────────────────────

class GradeConfig {
  final List<String> classDays;
  final int sessionsPerDay;
  final int sessionDurationMinutes;
  final String startTime;
  final String? breakStart;
  final String? breakEnd;

  // ── Friday early-dismissal ───────────────────────────────────────────────
  /// Whether Fridays end earlier than regular days.
  final bool fridayEarlyDismissal;

  /// Clock time when Friday classes end (display only, e.g. '14:20').
  final String fridayDismissalTime;

  /// 0-based index of the *last* session taught on Fridays.
  /// -1 means "no override" (same as every other day).
  final int fridayLastSession;

  const GradeConfig({
    this.classDays = const ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'],
    this.sessionsPerDay = 7,
    this.sessionDurationMinutes = 50,
    this.startTime = '07:00',
    this.breakStart,
    this.breakEnd,
    this.fridayEarlyDismissal = false,
    this.fridayDismissalTime = '14:20',
    this.fridayLastSession = -1,
  });

  bool get hasBreak => breakStart != null && breakEnd != null;

  /// Returns how many sessions are taught on [day].
  /// On Fridays (when early dismissal is enabled), this is limited to
  /// [fridayLastSession] + 1.  All other days return [sessionsPerDay].
  int sessionsForDay(String day) {
    if (fridayEarlyDismissal &&
        day == 'Viernes' &&
        fridayLastSession >= 0 &&
        fridayLastSession < sessionsPerDay) {
      return fridayLastSession + 1;
    }
    return sessionsPerDay;
  }

  int get breakAfterSession {
    if (!hasBreak) return -1;
    final breakStartMin = _timeToMinutes(breakStart!);
    final startParts = startTime.split(':');
    final originMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    int last = -1;
    for (int i = 0; i < sessionsPerDay; i++) {
      final slotEnd = originMin + (i + 1) * sessionDurationMinutes;
      if (slotEnd <= breakStartMin) last = i;
    }
    return last;
  }

  static int _timeToMinutes(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  Set<int> get breakSessionIndices => {};

  GradeConfig copyWith({
    List<String>? classDays,
    int? sessionsPerDay,
    int? sessionDurationMinutes,
    String? startTime,
    Object? breakStart = _sentinel,
    Object? breakEnd   = _sentinel,
    bool? fridayEarlyDismissal,
    String? fridayDismissalTime,
    int? fridayLastSession,
  }) =>
      GradeConfig(
        classDays: classDays ?? this.classDays,
        sessionsPerDay: sessionsPerDay ?? this.sessionsPerDay,
        sessionDurationMinutes: sessionDurationMinutes ?? this.sessionDurationMinutes,
        startTime: startTime ?? this.startTime,
        breakStart: breakStart == _sentinel ? this.breakStart : breakStart as String?,
        breakEnd:   breakEnd   == _sentinel ? this.breakEnd   : breakEnd   as String?,
        fridayEarlyDismissal: fridayEarlyDismissal ?? this.fridayEarlyDismissal,
        fridayDismissalTime: fridayDismissalTime ?? this.fridayDismissalTime,
        fridayLastSession: fridayLastSession ?? this.fridayLastSession,
      );

  static const Object _sentinel = Object();

  List<String> get sessionLabels {
    final parts = startTime.split(':');
    final originMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);

    final breakDuration = hasBreak
        ? _timeToMinutes(breakEnd!) - _timeToMinutes(breakStart!)
        : 0;

    final insertAfter = hasBreak ? breakAfterSession : -1;

    return List.generate(sessionsPerDay, (i) {
      int startMin = originMin + i * sessionDurationMinutes;
      if (i > insertAfter) startMin += breakDuration;
      final endMin = startMin + sessionDurationMinutes;
      return '${_pad(startMin ~/ 60)}:${_pad(startMin % 60)} – '
             '${_pad(endMin ~/ 60)}:${_pad(endMin % 60)}';
    });
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Map<String, dynamic> toJson() => {
        'classDays': classDays,
        'sessionsPerDay': sessionsPerDay,
        'sessionDurationMinutes': sessionDurationMinutes,
        'startTime': startTime,
        if (breakStart != null) 'breakStart': breakStart,
        if (breakEnd   != null) 'breakEnd':   breakEnd,
        'fridayEarlyDismissal': fridayEarlyDismissal,
        'fridayDismissalTime': fridayDismissalTime,
        'fridayLastSession': fridayLastSession,
      };

  factory GradeConfig.fromJson(Map<String, dynamic> j) => GradeConfig(
        classDays: List<String>.from(
            j['classDays'] ?? ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes']),
        sessionsPerDay:
            (j['sessionsPerDay'] ?? j['periodsPerDay'] ?? 7) as int,
        sessionDurationMinutes:
            (j['sessionDurationMinutes'] ?? j['periodDurationMinutes'] ?? 50) as int,
        startTime: j['startTime'] ?? '07:00',
        breakStart: j['breakStart'] as String?,
        breakEnd:   j['breakEnd']   as String?,
        fridayEarlyDismissal: j['fridayEarlyDismissal'] ?? false,
        fridayDismissalTime: j['fridayDismissalTime'] ?? '14:20',
        fridayLastSession: j['fridayLastSession'] ?? -1,
      );
}

// ─────────────────────────────────────────────
// GRADE
// ─────────────────────────────────────────────

class Grade {
  final String id;
  final String name;
  final String levelId;
  final GradeConfig config;
  final List<Section> sections;

  const Grade({
    required this.id,
    required this.name,
    required this.levelId,
    this.config = const GradeConfig(),
    this.sections = const [],
  });

  Grade copyWith({
    String? id,
    String? name,
    String? levelId,
    GradeConfig? config,
    List<Section>? sections,
  }) =>
      Grade(
        id: id ?? this.id,
        name: name ?? this.name,
        levelId: levelId ?? this.levelId,
        config: config ?? this.config,
        sections: sections ?? this.sections,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'levelId': levelId,
        'config': config.toJson(),
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory Grade.fromJson(Map<String, dynamic> j) => Grade(
        id: j['id'],
        name: j['name'],
        levelId: j['levelId'],
        config: GradeConfig.fromJson(j['config'] ?? {}),
        sections: (j['sections'] as List? ?? []).map((s) => Section.fromJson(s)).toList(),
      );
}

// ─────────────────────────────────────────────
// SECTION
// ─────────────────────────────────────────────

class Section {
  final String id;
  final String name;
  final String gradeId;
  final String levelId;

  const Section({
    required this.id,
    required this.name,
    required this.gradeId,
    required this.levelId,
  });

  Section copyWith({String? id, String? name, String? gradeId, String? levelId}) =>
      Section(
        id: id ?? this.id,
        name: name ?? this.name,
        gradeId: gradeId ?? this.gradeId,
        levelId: levelId ?? this.levelId,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'gradeId': gradeId, 'levelId': levelId};

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        id: j['id'],
        name: j['name'],
        gradeId: j['gradeId'],
        levelId: j['levelId'],
      );
}

// ─────────────────────────────────────────────
// SUBJECT
// ─────────────────────────────────────────────

class Subject {
  final String id;
  final String name;
  final List<SubjectLevelConfig> levelConfigs;

  List<String> get levelIds => levelConfigs.map((c) => c.levelId).toList();
  String get levelId => levelIds.isNotEmpty ? levelIds.first : '';

  int hoursForLevel(String levelId) {
    try {
      return levelConfigs.firstWhere((c) => c.levelId == levelId).hoursPerWeek;
    } catch (_) {
      return 0;
    }
  }

  int periodsForLevel(String levelId) {
    try {
      return levelConfigs.firstWhere((c) => c.levelId == levelId).sessionPeriods;
    } catch (_) {
      return 1;
    }
  }

  int hoursForSection(String levelId, String sectionId) {
    try {
      final cfg = levelConfigs.firstWhere((c) => c.levelId == levelId);
      return cfg.hoursForSection(sectionId);
    } catch (_) {
      return 0;
    }
  }

  int periodsForSection(String levelId, String sectionId) {
    try {
      final cfg = levelConfigs.firstWhere((c) => c.levelId == levelId);
      return cfg.periodsForSection(sectionId);
    } catch (_) {
      return 1;
    }
  }

  SubjectLevelConfig? configForLevel(String levelId) {
    try {
      return levelConfigs.firstWhere((c) => c.levelId == levelId);
    } catch (_) {
      return null;
    }
  }

  int get hoursPerWeek =>
      levelConfigs.isNotEmpty ? levelConfigs.first.hoursPerWeek : 0;

  int get sessionPeriods =>
      levelConfigs.isNotEmpty ? levelConfigs.first.sessionPeriods : 1;

  final SubjectType type;
  final bool multipleTeachers;
  final int colorValue;

  const Subject({
    required this.id,
    required this.name,
    required this.levelConfigs,
    this.type = SubjectType.base,
    this.multipleTeachers = false,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  Subject copyWith({
    String? id,
    String? name,
    List<SubjectLevelConfig>? levelConfigs,
    SubjectType? type,
    bool? multipleTeachers,
    int? colorValue,
    List<String>? levelIds, // ignored — kept for call-site compatibility
  }) =>
      Subject(
        id: id ?? this.id,
        name: name ?? this.name,
        levelConfigs: levelConfigs ?? this.levelConfigs,
        type: type ?? this.type,
        multipleTeachers: multipleTeachers ?? this.multipleTeachers,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'levelConfigs': levelConfigs.map((c) => c.toJson()).toList(),
        'type': type.index,
        'multipleTeachers': multipleTeachers,
        'colorValue': colorValue,
      };

  factory Subject.fromJson(Map<String, dynamic> j) {
    if (j['levelConfigs'] != null) {
      return Subject(
        id: j['id'],
        name: j['name'],
        levelConfigs: (j['levelConfigs'] as List)
            .map((c) => SubjectLevelConfig.fromJson(c as Map<String, dynamic>))
            .toList(),
        type: SubjectType.values[j['type'] ?? 0],
        multipleTeachers: j['multipleTeachers'] ?? false,
        colorValue: j['colorValue'] ?? 0xFF3B82F6,
      );
    }

    List<String> ids;
    if (j['levelIds'] != null) {
      ids = List<String>.from(j['levelIds']);
    } else if (j['levelId'] != null) {
      ids = [j['levelId'] as String];
    } else {
      ids = [];
    }
    final oldHours   = (j['hoursPerWeek'] ?? 5) as int;
    final oldPeriods = (j['sessionPeriods'] ?? 1) as int;

    return Subject(
      id: j['id'],
      name: j['name'],
      levelConfigs: ids
          .map((lid) => SubjectLevelConfig(
                levelId: lid,
                hoursPerWeek: oldHours,
                sessionPeriods: oldPeriods,
              ))
          .toList(),
      type: SubjectType.values[j['type'] ?? 0],
      multipleTeachers: j['multipleTeachers'] ?? false,
      colorValue: j['colorValue'] ?? 0xFF3B82F6,
    );
  }
}

// ─────────────────────────────────────────────
// TEACHER AVAILABILITY
// ─────────────────────────────────────────────

class DayAvailability {
  final String day;
  final List<int> availablePeriods;

  const DayAvailability({required this.day, required this.availablePeriods});

  DayAvailability copyWith({String? day, List<int>? availablePeriods}) =>
      DayAvailability(
        day: day ?? this.day,
        availablePeriods: availablePeriods ?? this.availablePeriods,
      );

  Map<String, dynamic> toJson() => {'day': day, 'availablePeriods': availablePeriods};

  factory DayAvailability.fromJson(Map<String, dynamic> j) => DayAvailability(
        day: j['day'],
        availablePeriods: List<int>.from(j['availablePeriods'] ?? []),
      );
}

// ─────────────────────────────────────────────
// TEACHER
// ─────────────────────────────────────────────
//
// The [assignments] list replaces the old flat [sectionIds] field.
// Each assignment links a (subjectId, gradeId, sectionId?) tuple.
//
// Backward compatibility:
//   Old records that stored a flat `sectionIds` list are migrated on load
//   by building grade-wide assignments for every subject × grade pair
//   that matches the teacher's subjects.  The migration is best-effort
//   because the old format had no gradeId; we resolve gradeId by looking
//   up sections from grades at runtime in app_provider instead.
//   To keep models.dart self-contained, fromJson stores raw sectionIds in
//   a special `_legacySectionIds` field that AppProvider cleans up.

class Teacher {
  final String id;
  final String name;
  final String lastName;
  final List<String> subjectIds;

  /// New structured assignments (subject + grade, optionally section).
  final List<TeacherSubjectAssignment> assignments;

  /// Legacy field kept for migration — do NOT use in new code.
  /// Populated only when loading old JSON that lacks the `assignments` key.
  final List<String> legacySectionIds;

  final List<DayAvailability> availability;

  const Teacher({
    required this.id,
    required this.name,
    required this.lastName,
    this.subjectIds = const [],
    this.assignments = const [],
    this.legacySectionIds = const [],
    this.availability = const [], required List<String> sectionIds,
  });

  String get fullName => '$name $lastName'.trim();

  // ── Convenience helpers ──────────────────────────────────────────────────

  /// All unique section IDs referenced in assignments (specific ones only).
  List<String> get sectionIds =>
      assignments.map((a) => a.sectionId).whereType<String>().toSet().toList();

  /// All unique grade IDs referenced in assignments.
  List<String> get gradeIds =>
      assignments.map((a) => a.gradeId).toSet().toList();

  /// Returns true if this teacher has any assignment that covers [sectionId]
  /// for [subjectId], considering grade-wide assignments as a fallback.
  ///
  /// Priority: section-specific > grade-wide.
  bool canTeach({required String subjectId, required String sectionId, required String gradeId}) {
    if (!subjectIds.contains(subjectId)) return false;
    if (assignments.isEmpty) return true; // unrestricted teacher

    // Check for a specific section assignment first.
    final hasSpecific = assignments.any((a) =>
        a.subjectId == subjectId &&
        a.gradeId == gradeId &&
        a.sectionId == sectionId);
    if (hasSpecific) return true;

    // Check if there is a grade-wide assignment for this subject.
    final hasGradeWide = assignments.any((a) =>
        a.subjectId == subjectId &&
        a.gradeId == gradeId &&
        a.sectionId == null);
    if (hasGradeWide) return true;

    // If the teacher has no assignments for this subject at all, they are
    // unrestricted for that subject (assignments only restrict, not grant).
    final hasAnyForSubject = assignments.any((a) => a.subjectId == subjectId);
    return !hasAnyForSubject;
  }

  Teacher copyWith({
    String? id,
    String? name,
    String? lastName,
    List<String>? subjectIds,
    List<TeacherSubjectAssignment>? assignments,
    List<String>? legacySectionIds,
    List<DayAvailability>? availability, required List<String> sectionIds,
  }) =>
      Teacher(
        id: id ?? this.id,
        name: name ?? this.name,
        lastName: lastName ?? this.lastName,
        subjectIds: subjectIds ?? this.subjectIds,
        assignments: assignments ?? this.assignments,
        legacySectionIds: legacySectionIds ?? this.legacySectionIds,
        availability: availability ?? this.availability, sectionIds: [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lastName': lastName,
        'subjectIds': subjectIds,
        'assignments': assignments.map((a) => a.toJson()).toList(),
        'availability': availability.map((a) => a.toJson()).toList(),
      };

  factory Teacher.fromJson(Map<String, dynamic> j) {
    // New format: has 'assignments' key.
    if (j['assignments'] != null) {
      return Teacher(
        id: j['id'],
        name: j['name'],
        lastName: j['lastName'] ?? '',
        subjectIds: List<String>.from(j['subjectIds'] ?? []),
        assignments: (j['assignments'] as List)
            .map((a) => TeacherSubjectAssignment.fromJson(a as Map<String, dynamic>))
            .toList(),
        availability: (j['availability'] as List? ?? [])
            .map((a) => DayAvailability.fromJson(a))
            .toList(), sectionIds: [],
      );
    }

    // Legacy format: flat sectionIds list — store for migration.
    return Teacher(
      id: j['id'],
      name: j['name'],
      lastName: j['lastName'] ?? '',
      subjectIds: List<String>.from(j['subjectIds'] ?? []),
      assignments: const [],
      legacySectionIds: List<String>.from(j['sectionIds'] ?? []),
      availability: (j['availability'] as List? ?? [])
          .map((a) => DayAvailability.fromJson(a))
          .toList(), sectionIds: [],
    );
  }
}

// ─────────────────────────────────────────────
// SCHEDULE SLOT
// ─────────────────────────────────────────────

class ScheduleSlot {
  final String day;
  final int periodIndex;
  final String subjectId;
  final String teacherId;

  const ScheduleSlot({
    required this.day,
    required this.periodIndex,
    required this.subjectId,
    required this.teacherId,
  });

  ScheduleSlot copyWith({String? day, int? periodIndex, String? subjectId, String? teacherId}) =>
      ScheduleSlot(
        day: day ?? this.day,
        periodIndex: periodIndex ?? this.periodIndex,
        subjectId: subjectId ?? this.subjectId,
        teacherId: teacherId ?? this.teacherId,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'periodIndex': periodIndex,
        'subjectId': subjectId,
        'teacherId': teacherId,
      };

  factory ScheduleSlot.fromJson(Map<String, dynamic> j) => ScheduleSlot(
        day: j['day'],
        periodIndex: j['periodIndex'],
        subjectId: j['subjectId'],
        teacherId: j['teacherId'],
      );
}

// ─────────────────────────────────────────────
// SECTION SCHEDULE
// ─────────────────────────────────────────────

class SectionSchedule {
  final String id;
  final String sectionId;
  final List<ScheduleSlot> slots;
  final DateTime generatedAt;
  final bool hasConflicts;
  final List<String> conflictMessages;

  const SectionSchedule({
    required this.id,
    required this.sectionId,
    required this.slots,
    required this.generatedAt,
    this.hasConflicts = false,
    this.conflictMessages = const [],
  });

  SectionSchedule copyWith({
    String? id,
    String? sectionId,
    List<ScheduleSlot>? slots,
    DateTime? generatedAt,
    bool? hasConflicts,
    List<String>? conflictMessages,
  }) =>
      SectionSchedule(
        id: id ?? this.id,
        sectionId: sectionId ?? this.sectionId,
        slots: slots ?? this.slots,
        generatedAt: generatedAt ?? this.generatedAt,
        hasConflicts: hasConflicts ?? this.hasConflicts,
        conflictMessages: conflictMessages ?? this.conflictMessages,
      );

  ScheduleSlot? getSlot(String day, int period) {
    try {
      return slots.firstWhere((s) => s.day == day && s.periodIndex == period);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sectionId': sectionId,
        'slots': slots.map((s) => s.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
        'hasConflicts': hasConflicts,
        'conflictMessages': conflictMessages,
      };

  factory SectionSchedule.fromJson(Map<String, dynamic> j) => SectionSchedule(
        id: j['id'],
        sectionId: j['sectionId'],
        slots: (j['slots'] as List? ?? []).map((s) => ScheduleSlot.fromJson(s)).toList(),
        generatedAt: DateTime.parse(j['generatedAt']),
        hasConflicts: j['hasConflicts'] ?? false,
        conflictMessages: List<String>.from(j['conflictMessages'] ?? []),
      );
}