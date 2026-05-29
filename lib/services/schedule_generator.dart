import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

// =============================================================================
// RESULT
// =============================================================================

class GenerationResult {
  final List<SectionSchedule> schedules;
  final List<String> globalConflicts;

  const GenerationResult(
      {required this.schedules, required this.globalConflicts});

  bool get hasConflicts =>
      globalConflicts.isNotEmpty || schedules.any((s) => s.hasConflicts);
}

// =============================================================================
// INTERNAL STRUCTURES
// =============================================================================

class _TimeSlot {
  final String day;
  final int period;
  const _TimeSlot(this.day, this.period);

  @override
  bool operator ==(Object other) =>
      other is _TimeSlot && other.day == day && other.period == period;

  @override
  int get hashCode => Object.hash(day, period);

  @override
  String toString() => '$day-P$period';
}

// ignore: unused_element
class _Requirement {
  final String sectionId;
  final String subjectId;
  final String teacherId;
  final int count;

  const _Requirement({
    required this.sectionId,
    required this.subjectId,
    required this.teacherId,
    required this.count,
  });
}

// ignore: unused_element
class _SharedRequirement {
  final List<String> sectionIds;
  final String subjectId;
  final String teacherId;
  final int count;

  const _SharedRequirement({
    required this.sectionIds,
    required this.subjectId,
    required this.teacherId,
    required this.count,
  });
}

// =============================================================================
// SCHEDULE GENERATOR
// =============================================================================
//
// Algorithm overview
// ──────────────────
//
//  Step 1 — Teacher assignment
//    For every (section, subject) pair decide WHICH teacher will cover it.
//    Uses lightest-load-first heuristic.
//
//  Step 2 — Sort requirements (MRV: most-constrained first)
//    Shared blocks always go first.
//
//  Step 3 — Place shared requirements (greedy)
//
//  Step 4 — Place solo requirements (greedy)
//
//  Step 4.5 — REPAIR PHASE  ← NEW
//    For every requirement that couldn't be fully placed, attempt a 1-swap
//    displacement: find a slot where the teacher is busy with another session
//    that can be moved somewhere else, freeing space for the failed session.
//    Also tries switching to an alternative teacher if one is available.
//    Runs up to [_kMaxRepairPasses] times until no more progress is made.
//
//  Step 5 — Build SectionSchedule results

class ScheduleGenerator {
  static const _uuid = Uuid();

  // Maximum number of repair passes over the failed-requirements list.
  // 3 passes covers virtually all real-world cases without being slow.
  static const int _kMaxRepairPasses = 3;

  // ---------------------------------------------------------------------------
  // PUBLIC ENTRY POINT
  // ---------------------------------------------------------------------------

  GenerationResult generate({
    required List<Grade> grades,
    required List<Subject> subjects,
    required List<Teacher> teachers,
    Map<String, List<ScheduleSlot>> manualSlots = const {},
  }) {
    final List<String> globalConflicts = [];
    final Map<String, List<String>> sectionConflicts = {};

    final Map<String, bool> teacherBusy = {};
    final Map<String, bool> sectionBusy = {};
    final Map<String, List<ScheduleSlot>> placed = {};

    for (final grade in grades) {
      for (final sec in _sectionsOf(grade)) {
        placed[sec.id] = [];
        sectionConflicts[sec.id] = [];
      }
    }

    // Pre-fill manual slots
    for (final entry in manualSlots.entries) {
      final sId = entry.key;
      placed.putIfAbsent(sId, () => []);
      for (final s in entry.value) {
        placed[sId]!.add(s);
        teacherBusy['${s.teacherId}-${s.day}-${s.periodIndex}'] = true;
        sectionBusy['$sId-${s.day}-${s.periodIndex}'] = true;
      }
    }

    final Map<String, int> teacherLoad = {};

    // Build available time slots per grade
    final Map<String, List<_TimeSlot>> gradeSlots = {};
    for (final grade in grades) {
      final slots = <_TimeSlot>[];
      for (final day in grade.config.classDays) {
        final sessions = grade.config.sessionsForDay(day);
        for (int p = 0; p < sessions; p++) {
          slots.add(_TimeSlot(day, p));
        }
      }
      gradeSlots[grade.id] = slots;
    }

    // ── Helper: teacher availability filter ─────────────────────────────────
    bool teacherAllowed(Teacher t, String day, int period) {
      if (t.availability.isEmpty) return true;
      try {
        final da = t.availability.firstWhere((a) => a.day == day);
        return da.availablePeriods.contains(period);
      } catch (_) {
        return false;
      }
    }

    // ── Helper: get Teacher object by id ─────────────────────────────────────
    Teacher? teacherById(String id) {
      try { return teachers.firstWhere((t) => t.id == id); } catch (_) { return null; }
    }

    // ── Helper: pick best teacher for a solo requirement ────────────────────
    Teacher? pickTeacher({
      required Subject subject,
      required Grade grade,
      required Section section,
      required List<Teacher> pool,
    }) {
      final specific = <Teacher>[];
      final gradeWide = <Teacher>[];
      final unrestricted = <Teacher>[];

      for (final t in pool) {
        if (!t.subjectIds.contains(subject.id)) continue;
        if (t.assignments.isEmpty) {
          unrestricted.add(t);
          continue;
        }
        if (t.assignments.any((a) =>
            a.subjectId == subject.id &&
            a.gradeId == grade.id &&
            a.sectionId == section.id)) {
          specific.add(t);
          continue;
        }
        if (t.assignments.any((a) =>
            a.subjectId == subject.id &&
            a.gradeId == grade.id &&
            a.sectionId == null)) {
          gradeWide.add(t);
          continue;
        }
        if (!t.assignments.any((a) => a.subjectId == subject.id)) {
          unrestricted.add(t);
        }
      }

      final tiers = [specific, gradeWide, unrestricted];
      for (final tier in tiers) {
        if (tier.isEmpty) continue;
        tier.sort((a, b) =>
            (teacherLoad[a.id] ?? 0).compareTo(teacherLoad[b.id] ?? 0));
        return tier.first;
      }
      return null;
    }

    // ── Helper: pick best teacher for a shared block ─────────────────────────
    Teacher? pickTeacherForShared({
      required Subject subject,
      required Grade grade,
      required List<String> sectionIds,
      required List<Grade> allGrades,
      required List<Teacher> pool,
    }) {
      final Map<String, String> secGrade = {};
      for (final g in allGrades) {
        for (final s in _sectionsOf(g)) {
          secGrade[s.id] = g.id;
        }
      }

      final eligible = pool.where((t) {
        if (!t.subjectIds.contains(subject.id)) return false;
        return sectionIds.every((sId) =>
            t.canTeach(
              subjectId: subject.id,
              sectionId: sId,
              gradeId: secGrade[sId] ?? grade.id,
            ));
      }).toList()
        ..sort((a, b) =>
            (teacherLoad[a.id] ?? 0).compareTo(teacherLoad[b.id] ?? 0));

      return eligible.isEmpty ? null : eligible.first;
    }

    // ── Helper: place sessions for a requirement (greedy, 2 passes) ──────────
    //
    // Returns number of sessions successfully placed.
    int placeRequirement({
      required List<String> sectionIds,
      required String subjectId,
      required String teacherId,
      required int count,
      required List<_TimeSlot> availSlots,
      required bool isSingleSection,
    }) {
      int remaining = count;
      final Map<String, int> dayUsage = {};

      for (int pass = 0; pass < 2 && remaining > 0; pass++) {
        for (final ts in availSlots) {
          if (remaining <= 0) break;
          if (pass == 0 && (dayUsage[ts.day] ?? 0) > 0) continue;
          if (teacherBusy['$teacherId-${ts.day}-${ts.period}'] == true) continue;

          final teacher = teacherById(teacherId);
          if (teacher != null && !teacherAllowed(teacher, ts.day, ts.period)) continue;

          bool allFree = true;
          for (final sId in sectionIds) {
            if (sectionBusy['$sId-${ts.day}-${ts.period}'] == true) {
              allFree = false;
              break;
            }
          }
          if (!allFree) continue;

          // Commit
          teacherBusy['$teacherId-${ts.day}-${ts.period}'] = true;
          for (final sId in sectionIds) {
            sectionBusy['$sId-${ts.day}-${ts.period}'] = true;
            placed.putIfAbsent(sId, () => []).add(ScheduleSlot(
                  day: ts.day,
                  periodIndex: ts.period,
                  subjectId: subjectId,
                  teacherId: teacherId,
                ));
          }
          teacherLoad[teacherId] = (teacherLoad[teacherId] ?? 0) + 1;
          dayUsage[ts.day] = (dayUsage[ts.day] ?? 0) + 1;
          remaining--;
        }
      }

      return count - remaining;
    }

    // ── NEW: Repair a single missing session via 1-swap displacement ─────────
    //
    // Strategy A — swap teacher's blocking session to another free slot.
    // Strategy B — use an alternative eligible teacher if available.
    //
    // Returns 1 if a session was successfully placed, 0 otherwise.
    int repairOneSession({
      required String sectionId,
      required String subjectId,
      required String teacherId,
      required List<_TimeSlot> availSlots,
      required List<Teacher> allTeachers,
      // Extra context needed to find alternative teachers
      required Grade grade,
      required Section section,
      required Subject subject,
    }) {
      // ── Strategy A: displacement swap ──────────────────────────────────────
      for (final ts in availSlots) {
        // Section must be free at this slot.
        if (sectionBusy['$sectionId-${ts.day}-${ts.period}'] == true) continue;

        // If teacher is free here too, just place it (shouldn't happen after
        // pass 2 of placeRequirement, but handles availability edge-cases).
        if (teacherBusy['$teacherId-${ts.day}-${ts.period}'] != true) {
          final teacher = teacherById(teacherId);
          if (teacher != null && teacherAllowed(teacher, ts.day, ts.period)) {
            teacherBusy['$teacherId-${ts.day}-${ts.period}'] = true;
            sectionBusy['$sectionId-${ts.day}-${ts.period}'] = true;
            placed.putIfAbsent(sectionId, () => []).add(ScheduleSlot(
                  day: ts.day,
                  periodIndex: ts.period,
                  subjectId: subjectId,
                  teacherId: teacherId,
                ));
            teacherLoad[teacherId] = (teacherLoad[teacherId] ?? 0) + 1;
            return 1;
          }
          continue;
        }

        // Teacher is busy at ts. Find which section is blocking them.
        String? blockingSectionId;
        ScheduleSlot? blockingSlot;
        for (final entry in placed.entries) {
          final hit = entry.value.where((s) =>
              s.teacherId == teacherId &&
              s.day == ts.day &&
              s.periodIndex == ts.period).firstOrNull;
          if (hit != null) {
            blockingSectionId = entry.key;
            blockingSlot = hit;
            break;
          }
        }
        if (blockingSectionId == null || blockingSlot == null) continue;

        // Can the blocking session be moved to an alternative slot?
        for (final alt in availSlots) {
          if (alt == ts) continue;
          if (teacherBusy['$teacherId-${alt.day}-${alt.period}'] == true) continue;
          if (sectionBusy['$blockingSectionId-${alt.day}-${alt.period}'] == true) continue;
          final teacher = teacherById(teacherId);
          if (teacher != null && !teacherAllowed(teacher, alt.day, alt.period)) continue;

          // Move blocking session → alt
          teacherBusy.remove('$teacherId-${ts.day}-${ts.period}');
          sectionBusy.remove('$blockingSectionId-${ts.day}-${ts.period}');

          final idx = placed[blockingSectionId]!.indexWhere((s) =>
              s.teacherId == teacherId &&
              s.day == ts.day &&
              s.periodIndex == ts.period);
          if (idx >= 0) {
            placed[blockingSectionId]![idx] = ScheduleSlot(
              day: alt.day,
              periodIndex: alt.period,
              subjectId: blockingSlot.subjectId,
              teacherId: blockingSlot.teacherId,
            );
          }
          teacherBusy['$teacherId-${alt.day}-${alt.period}'] = true;
          sectionBusy['$blockingSectionId-${alt.day}-${alt.period}'] = true;

          // Now place the failed session at the freed slot
          teacherBusy['$teacherId-${ts.day}-${ts.period}'] = true;
          sectionBusy['$sectionId-${ts.day}-${ts.period}'] = true;
          placed.putIfAbsent(sectionId, () => []).add(ScheduleSlot(
                day: ts.day,
                periodIndex: ts.period,
                subjectId: subjectId,
                teacherId: teacherId,
              ));
          teacherLoad[teacherId] = (teacherLoad[teacherId] ?? 0) + 1;
          return 1;
        }
      }

      // ── Strategy B: alternative teacher ────────────────────────────────────
      //
      // Try every other eligible teacher for this subject/section. If one has
      // a free slot that the section also has free, use them for just this session.
      final altTeachers = allTeachers.where((t) {
        if (t.id == teacherId) return false;
        if (!t.subjectIds.contains(subject.id)) return false;
        return t.canTeach(
          subjectId: subject.id,
          sectionId: sectionId,
          gradeId: grade.id,
        );
      }).toList()
        ..sort((a, b) =>
            (teacherLoad[a.id] ?? 0).compareTo(teacherLoad[b.id] ?? 0));

      for (final alt in altTeachers) {
        for (final ts in availSlots) {
          if (sectionBusy['$sectionId-${ts.day}-${ts.period}'] == true) continue;
          if (teacherBusy['${alt.id}-${ts.day}-${ts.period}'] == true) continue;
          if (!teacherAllowed(alt, ts.day, ts.period)) continue;

          // Place with alternate teacher
          teacherBusy['${alt.id}-${ts.day}-${ts.period}'] = true;
          sectionBusy['$sectionId-${ts.day}-${ts.period}'] = true;
          placed.putIfAbsent(sectionId, () => []).add(ScheduleSlot(
                day: ts.day,
                periodIndex: ts.period,
                subjectId: subjectId,
                teacherId: alt.id,
              ));
          teacherLoad[alt.id] = (teacherLoad[alt.id] ?? 0) + 1;
          return 1;
        }
      }

      return 0; // Could not place this session
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 1 — Build all requirements (decide teachers up-front)
    // ─────────────────────────────────────────────────────────────────────────

    final List<(List<String>, String, String, int, Grade)> sharedReqs = [];
    final List<(String, String, String, int, Grade)> soloReqs = [];
    // Parallel info needed for repair: (section, subject, grade, section object)
    final List<(String, String, String, int, Grade, Section, Subject)> soloReqsFull = [];

    final Set<String> processedSharedBlocks = {};

    for (final grade in grades) {
      final sections = _sectionsOf(grade);

      for (final subject in subjects) {
        final cfg = subject.configForLevel(grade.levelId);
        if (cfg == null) continue;

        // Shared blocks
        for (final block in cfg.sharedBlocks) {
          if (block.hoursPerWeek <= 0) continue;
          final blockKey = '${subject.id}|${block.id}';
          if (!processedSharedBlocks.add(blockKey)) continue;
          if (block.sectionIds.isEmpty) continue;

          bool valid = true;
          for (final sId in block.sectionIds) {
            final secTotal = cfg.hoursForSection(sId);
            if (block.hoursPerWeek > secTotal) {
              globalConflicts.add(
                'CONFIG: "${subject.name}" — bloque compartido tiene '
                '${block.hoursPerWeek} h pero la sección $sId solo tiene '
                '$secTotal h en total. Reduce el bloque a máx $secTotal h.',
              );
              valid = false;
            }
          }
          if (!valid) continue;

          final blockGrade = grades.firstWhere(
            (g) => _sectionsOf(g).any((s) => s.id == block.sectionIds.first),
            orElse: () => grade,
          );

          final teacher = pickTeacherForShared(
            subject: subject,
            grade: blockGrade,
            sectionIds: block.sectionIds,
            allGrades: grades,
            pool: teachers,
          );

          if (teacher == null) {
            globalConflicts.add(
              'SIN MAESTRO: bloque compartido de "${subject.name}" '
              '[${block.sectionIds.join(", ")}]. '
              'Asigna la materia a un maestro que cubra todos esos grupos.',
            );
            for (final sId in block.sectionIds) {
              sectionConflicts.putIfAbsent(sId, () => []).add(
                'Sin maestro para bloque compartido de "${subject.name}".',
              );
            }
            continue;
          }

          sharedReqs.add((
            block.sectionIds,
            subject.id,
            teacher.id,
            block.hoursPerWeek,
            blockGrade,
          ));
        }

        // Solo hours
        for (final section in sections) {
          final indHrs = cfg.individualHoursForSection(section.id);
          if (indHrs <= 0) continue;

          final teacher = pickTeacher(
            subject: subject,
            grade: grade,
            section: section,
            pool: teachers,
          );

          if (teacher == null) {
            final msg =
                'SIN MAESTRO: "${subject.name}" para ${section.name}. '
                'Ve a Maestros y asigna esta materia a un maestro.';
            sectionConflicts.putIfAbsent(section.id, () => []).add(msg);
            continue;
          }

          soloReqs.add((section.id, subject.id, teacher.id, indHrs, grade));
          soloReqsFull.add((section.id, subject.id, teacher.id, indHrs, grade, section, subject));
        }
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 2 — Sort requirements by difficulty (MRV)
    // ─────────────────────────────────────────────────────────────────────────

    int availSlotCount(Grade g, String teacherId) {
      final t = teachers.where((x) => x.id == teacherId).firstOrNull;
      if (t == null) return 1;
      if (t.availability.isEmpty) {
        return g.config.classDays
            .fold(0, (s, d) => s + g.config.sessionsForDay(d));
      }
      return t.availability.fold(0, (s, a) => s + a.availablePeriods.length);
    }

    sharedReqs.sort((a, b) {
      final slotsA = availSlotCount(a.$5, a.$3);
      final slotsB = availSlotCount(b.$5, b.$3);
      final scoreA = a.$4 * 1000 ~/ (slotsA == 0 ? 1 : slotsA);
      final scoreB = b.$4 * 1000 ~/ (slotsB == 0 ? 1 : slotsB);
      return scoreB.compareTo(scoreA);
    });

    soloReqs.sort((a, b) {
      final slotsA = availSlotCount(a.$5, a.$3);
      final slotsB = availSlotCount(b.$5, b.$3);
      final scoreA = a.$4 * 1000 ~/ (slotsA == 0 ? 1 : slotsA);
      final scoreB = b.$4 * 1000 ~/ (slotsB == 0 ? 1 : slotsB);
      return scoreB.compareTo(scoreA);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 3 — Place shared requirements
    // ─────────────────────────────────────────────────────────────────────────

    for (final req in sharedReqs) {
      final (sectionIds, subjectId, teacherId, count, grade) = req;
      final availSlots = gradeSlots[grade.id] ?? [];

      final placed_ = placeRequirement(
        sectionIds: sectionIds,
        subjectId: subjectId,
        teacherId: teacherId,
        count: count,
        availSlots: availSlots,
        isSingleSection: false,
      );

      if (placed_ < count) {
        final missing = count - placed_;
        final subjName =
            subjects.where((s) => s.id == subjectId).firstOrNull?.name ??
                subjectId;
        final tName =
            teachers.where((t) => t.id == teacherId).firstOrNull?.fullName ??
                teacherId;
        final msg =
            'CONFLICTO BLOQUE COMPARTIDO: No se pudieron ubicar $missing '
            'sesión(es) de "$subjName" [${sectionIds.join(", ")}] con el '
            'maestro $tName. El maestro o los grupos no tienen suficientes '
            'huecos libres en común.';
        globalConflicts.add(msg);
        for (final sId in sectionIds) {
          sectionConflicts.putIfAbsent(sId, () => []).add(msg);
        }
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 4 — Place solo requirements
    // ─────────────────────────────────────────────────────────────────────────

    // Track how many sessions are still missing after the greedy pass so we
    // can feed them into the repair phase.
    // List of (sectionId, subjectId, teacherId, missingSessions, grade, section, subject)
    final List<(String, String, String, int, Grade, Section, Subject)> failedSolo = [];

    for (int i = 0; i < soloReqs.length; i++) {
      final (sectionId, subjectId, teacherId, count, grade) = soloReqs[i];
      final (_, _, _, _, _, section, subject) = soloReqsFull[i];
      final availSlots = gradeSlots[grade.id] ?? [];

      final placed_ = placeRequirement(
        sectionIds: [sectionId],
        subjectId: subjectId,
        teacherId: teacherId,
        count: count,
        availSlots: availSlots,
        isSingleSection: true,
      );

      final missing = count - placed_;
      if (missing > 0) {
        failedSolo.add((sectionId, subjectId, teacherId, missing, grade, section, subject));
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 4.5 — REPAIR PHASE
    // ─────────────────────────────────────────────────────────────────────────
    //
    // For each failed session, attempt:
    //   A) 1-swap displacement: move a blocking teacher session to free a slot.
    //   B) Alternative teacher: use another eligible teacher with free time.
    //
    // Repeat up to _kMaxRepairPasses times (each pass may free slots for the next).

    for (int pass = 0; pass < _kMaxRepairPasses; pass++) {
      bool madeProgress = false;

      // Iterate over a copy; update the list as we fix sessions.
      final toRepair = List.of(failedSolo);
      failedSolo.clear();

      for (final failed in toRepair) {
        final (sectionId, subjectId, teacherId, missing, grade, section, subject) = failed;
        final availSlots = gradeSlots[grade.id] ?? [];

        int stillMissing = missing;
        for (int s = 0; s < missing; s++) {
          final fixed = repairOneSession(
            sectionId: sectionId,
            subjectId: subjectId,
            teacherId: teacherId,
            availSlots: availSlots,
            allTeachers: teachers,
            grade: grade,
            section: section,
            subject: subject,
          );
          if (fixed == 1) {
            stillMissing--;
            madeProgress = true;
          } else {
            break; // No point trying more for this requirement this pass
          }
        }

        if (stillMissing > 0) {
          failedSolo.add((sectionId, subjectId, teacherId, stillMissing, grade, section, subject));
        }
      }

      if (!madeProgress) break; // No improvement in this pass; stop early
    }

    // Convert remaining failures to conflict messages
    for (final failed in failedSolo) {
      final (sectionId, subjectId, teacherId, missing, _, section, _) = failed;
      final subjName =
          subjects.where((s) => s.id == subjectId).firstOrNull?.name ?? subjectId;
      final tName =
          teachers.where((t) => t.id == teacherId).firstOrNull?.fullName ?? teacherId;
      final msg =
          'CONFLICTO: No se pudieron ubicar $missing sesión(es) de '
          '"$subjName" en ${section.name} con el maestro $tName. '
          'Revisa la disponibilidad del maestro o reduce las horas.';
      sectionConflicts.putIfAbsent(sectionId, () => []).add(msg);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 5 — Build SectionSchedule results
    // ─────────────────────────────────────────────────────────────────────────

    final List<SectionSchedule> schedules = [];

    for (final grade in grades) {
      for (final section in _sectionsOf(grade)) {
        final conflicts = sectionConflicts[section.id] ?? [];
        final slots = placed[section.id] ?? [];

        schedules.add(SectionSchedule(
          id: _uuid.v4(),
          sectionId: section.id,
          slots: slots,
          generatedAt: DateTime.now(),
          hasConflicts: conflicts.isNotEmpty,
          conflictMessages: conflicts,
        ));
      }
    }

    return GenerationResult(
        schedules: schedules, globalConflicts: globalConflicts);
  }

  // ---------------------------------------------------------------------------
  // VALIDATION  (cross-schedule teacher conflict check)
  // ---------------------------------------------------------------------------

  List<String> validate({
    required List<SectionSchedule> schedules,
    required List<Grade> grades,
    required List<Subject> subjects,
    required List<Teacher> teachers,
  }) {
    final issues = <String>[];

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

    const kSep = '\x00';
    final Map<String, Map<String, List<String>>> teacherSlots = {};
    final Map<String, Map<String, String>> sectionOccupancy = {};

    for (final sched in schedules) {
      for (final slot in sched.slots) {
        final dp = '${slot.day}$kSep${slot.periodIndex}';

        final prev = sectionOccupancy
            .putIfAbsent(sched.sectionId, () => {})[dp];
        if (prev != null && prev != slot.subjectId) {
          final sec = _findSectionById(grades, sched.sectionId);
          final sA = _findSubjectById(subjects, prev);
          final sB = _findSubjectById(subjects, slot.subjectId);
          issues.add(
            'CONFLICTO GRUPO: ${sec?.name ?? sched.sectionId} tiene '
            '"${sA?.name ?? prev}" y "${sB?.name ?? slot.subjectId}" '
            'al mismo tiempo (${slot.day}, sesión ${slot.periodIndex + 1}).',
          );
        } else {
          sectionOccupancy
              .putIfAbsent(sched.sectionId, () => {})[dp] = slot.subjectId;
        }

        teacherSlots
            .putIfAbsent(slot.teacherId, () => {})
            .putIfAbsent(dp, () => [])
            .add(sched.sectionId);
      }
    }

    for (final tEntry in teacherSlots.entries) {
      for (final slotEntry in tEntry.value.entries) {
        final sections = slotEntry.value.toSet();
        if (sections.length <= 1) continue;

        final parts = slotEntry.key.split(kSep);
        final day = parts[0];
        final period = int.tryParse(parts[1]) ?? -1;

        final involved =
            schedules.where((s) => sections.contains(s.sectionId)).toList();

        final subjectIds = involved
            .map((s) => s.getSlot(day, period)?.subjectId)
            .whereType<String>()
            .toSet();

        if (subjectIds.length == 1) {
          final sortedSecs = sections.toList()..sort();
          final key = '${sortedSecs.join(",")}|${subjectIds.first}';
          if (legitimateSharedKeys.contains(key)) continue;
        }

        final teacher = _findTeacherById(teachers, tEntry.key);
        final sectionNames = involved
            .map((s) => _findSectionById(grades, s.sectionId)?.name ?? s.sectionId)
            .join(', ');
        final subjectNames = subjectIds
            .map((id) => _findSubjectById(subjects, id)?.name ?? id)
            .join(', ');
        issues.add(
          'CONFLICTO MAESTRO: ${teacher?.fullName ?? tEntry.key} '
          'asignado simultáneamente a [$sectionNames] '
          'el $day sesión ${period + 1} '
          '(${subjectIds.length == 1 ? '"$subjectNames" sin bloque compartido declarado' : 'materias: $subjectNames'}).',
        );
      }
    }

    return issues;
  }

  // ---------------------------------------------------------------------------
  // UTILITY
  // ---------------------------------------------------------------------------

  List<Section> _sectionsOf(Grade grade) {
    if (grade.sections.isNotEmpty) return grade.sections;
    return [
      Section(
        id: grade.id,
        name: grade.name,
        gradeId: grade.id,
        levelId: grade.levelId,
      )
    ];
  }

  Teacher? _findTeacherById(List<Teacher> teachers, String id) {
    try {
      return teachers.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Subject? _findSubjectById(List<Subject> subjects, String id) {
    try {
      return subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Section? _findSectionById(List<Grade> grades, String sectionId) {
    for (final g in grades) {
      try {
        return g.sections.firstWhere((s) => s.id == sectionId);
      } catch (_) {}
    }
    return null;
  }
}