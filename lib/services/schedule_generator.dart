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
// INTERNAL DATA STRUCTURES
// =============================================================================

/// A single placement decision committed to the schedule state.
class _Decision {
  final String teacherId;
  final String day;
  final int start;
  final int blockSize;
  final List<String> sectionIds; // 1 for solo, N for shared
  final String subjectId;

  const _Decision({
    required this.teacherId,
    required this.day,
    required this.start,
    required this.blockSize,
    required this.sectionIds,
    required this.subjectId,
  });
}

/// One (subject, sharedBlock) pair that must be placed simultaneously across
/// all sections in the block.
class _SharedPlacementUnit {
  final Subject subject;
  final SharedHoursBlock block;
  final Grade grade;

  const _SharedPlacementUnit({
    required this.subject,
    required this.block,
    required this.grade,
  });

  int get hoursPerWeek => block.hoursPerWeek;
}

/// One subject for one section (non-shared).
class _SoloPlacementUnit {
  final Subject subject;
  final Section section;
  final Grade grade;
  final int hoursPerWeek;
  final int blockSize;

  const _SoloPlacementUnit({
    required this.subject,
    required this.section,
    required this.grade,
    required this.hoursPerWeek,
    required this.blockSize,
  });
}

// =============================================================================
// PLACEMENT TASKS
// =============================================================================

abstract class _PlacementTask {
  /// Which session (0-based) within the unit this task represents.
  final int sessionIndex;
  const _PlacementTask({required this.sessionIndex});
}

class _SoloTask extends _PlacementTask {
  final _SoloPlacementUnit unit;
  const _SoloTask({required this.unit, required super.sessionIndex});
}

class _SharedTask extends _PlacementTask {
  final _SharedPlacementUnit unit;
  const _SharedTask({required this.unit, required super.sessionIndex});
}

// =============================================================================
// BACKTRACKING FRAME  (one level of the explicit stack)
// =============================================================================

/// Holds the state for one depth-level of the iterative backtracking search.
///
/// [taskIndex]  – which task this level is responsible for placing.
/// [candidates] – all valid decisions for this task (generated once on entry).
/// [tryNext]    – index of the candidate that will be tried next.
/// [active]     – the candidate currently committed to state (null = none).
class _BtFrame {
  final int taskIndex;
  final List<_Decision> candidates;
  int tryNext = 0;
  _Decision? active;

  _BtFrame({required this.taskIndex, required this.candidates});

  bool get exhausted => tryNext >= candidates.length;
}

// =============================================================================
// SCHEDULE STATE  (mutable, supports undo)
// =============================================================================

/// Centralises all mutable timetable state so backtracking can push / pop
/// entire decision stacks cleanly.
class _ScheduleState {
  /// teacher-busy: '$teacherId-$day-$period' → first owning sectionId
  final Map<String, String> teacherBusy = {};

  /// section-busy: '$sectionId-$day-$period'
  final Set<String> sectionBusy = {};

  /// Accumulated slots per sectionId.
  final Map<String, List<ScheduleSlot>> sectionSlots = {};

  /// '$sectionId|$subjectId|$day' → sorted list of period indices
  final Map<String, List<int>> subjectDayPeriods = {};

  /// Teacher load counter: teacherId → total slots committed so far.
  /// Used to balance load across equally-eligible teachers.
  final Map<String, int> teacherLoad = {};

  /// Tracks slots placed by a *shared* decision (sectionIds.length > 1).
  /// Key: '$sectionId-$day-$periodIndex'.
  /// Used by [_countPlacedSlots] so the greedy fallback can distinguish
  /// shared-placed slots from solo-placed slots and never skip a solo task
  /// just because shared hours already filled the subject's slot count.
  final Set<String> _sharedSlotKeys = {};

  // ── Commit ─────────────────────────────────────────────────────────────────

  void commit(_Decision d) {
    final isShared = d.sectionIds.length > 1;
    teacherLoad[d.teacherId] = (teacherLoad[d.teacherId] ?? 0) + d.blockSize;
    for (int b = 0; b < d.blockSize; b++) {
      final idx = d.start + b;
      teacherBusy['${d.teacherId}-${d.day}-$idx'] = d.sectionIds.first;
      for (final sId in d.sectionIds) {
        sectionBusy.add('$sId-${d.day}-$idx');
        // ── Track shared-placed slots so _countPlacedSlots can tell them
        //    apart from solo-placed slots in the greedy fallback.
        if (isShared) _sharedSlotKeys.add('$sId-${d.day}-$idx');
        sectionSlots.putIfAbsent(sId, () => []).add(ScheduleSlot(
              day: d.day,
              periodIndex: idx,
              subjectId: d.subjectId,
              teacherId: d.teacherId,
            ));
        _recordSubjectDay(sId, d.subjectId, d.day, idx);
      }
    }
  }

  // ── Undo ───────────────────────────────────────────────────────────────────

  void undo(_Decision d) {
    final isShared = d.sectionIds.length > 1;
    teacherLoad[d.teacherId] = ((teacherLoad[d.teacherId] ?? 0) - d.blockSize).clamp(0, 99999);
    for (int b = 0; b < d.blockSize; b++) {
      final idx = d.start + b;
      teacherBusy.remove('${d.teacherId}-${d.day}-$idx');
      for (final sId in d.sectionIds) {
        sectionBusy.remove('$sId-${d.day}-$idx');
        if (isShared) _sharedSlotKeys.remove('$sId-${d.day}-$idx');
        sectionSlots[sId]?.removeWhere((s) =>
            s.day == d.day &&
            s.periodIndex == idx &&
            s.subjectId == d.subjectId &&
            s.teacherId == d.teacherId);
        final key = '$sId|${d.subjectId}|${d.day}';
        subjectDayPeriods[key]?.remove(idx);
        if (subjectDayPeriods[key]?.isEmpty ?? false) {
          subjectDayPeriods.remove(key);
        }
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _recordSubjectDay(
      String sectionId, String subjectId, String day, int periodIdx) {
    final key = '$sectionId|$subjectId|$day';
    final list = subjectDayPeriods.putIfAbsent(key, () => []);
    if (!list.contains(periodIdx)) {
      list
        ..add(periodIdx)
        ..sort();
    }
  }

  /// Returns true when the slot at [sectionId]/[day]/[periodIdx] was placed
  /// as part of a shared-block decision (not a solo one).
  bool isSharedSlot(String sectionId, String day, int periodIdx) =>
      _sharedSlotKeys.contains('$sectionId-$day-$periodIdx');

  bool teacherFree(String teacherId, String day, int start, int blockSize) {
    for (int b = 0; b < blockSize; b++) {
      if (teacherBusy.containsKey('$teacherId-$day-${start + b}')) return false;
    }
    return true;
  }

  bool sectionFree(String sectionId, String day, int start, int blockSize) {
    for (int b = 0; b < blockSize; b++) {
      if (sectionBusy.contains('$sectionId-$day-${start + b}')) return false;
    }
    return true;
  }

  bool allSectionsFree(
      List<String> sectionIds, String day, int start, int blockSize) {
    for (final sId in sectionIds) {
      if (!sectionFree(sId, day, start, blockSize)) return false;
    }
    return true;
  }

  List<int> subjectPeriodsOnDay(
      String sectionId, String subjectId, String day) {
    return subjectDayPeriods['$sectionId|$subjectId|$day'] ?? [];
  }
}

// =============================================================================
// GENERATOR
// =============================================================================

class ScheduleGenerator {
  static const _uuid = Uuid();

  /// Hard time limit for the backtracking phase (milliseconds).
  /// After this deadline the algorithm keeps whatever partial solution it has
  /// and hands off to the greedy fallback.
  static const _backtrackLimitMs = 20000;

  // ---------------------------------------------------------------------------
  // Public entry point
  // ---------------------------------------------------------------------------

  GenerationResult generate({
    required List<Grade> grades,
    required List<Subject> subjects,
    required List<Teacher> teachers,
    Map<String, List<ScheduleSlot>> manualSlots = const {},
  }) {
    final List<String> globalConflicts = [];

    // ── Validate hour budgets before generating ───────────────────────────
    for (final grade in grades) {
      for (final unit in _sectionsOf(grade)) {
        for (final subject in subjects) {
          final cfg = subject.configForLevel(grade.levelId);
          if (cfg == null) continue;
          final total = cfg.hoursForSection(unit.id);
          final shared = cfg.sharedHoursForSection(unit.id);
          if (shared > total) {
            globalConflicts.add(
              'CONFIGURACIÓN: "${subject.name}" en grupo ${unit.name} — '
              'horas compartidas ($shared) superan el total ($total). '
              'Solución: reduce las horas del bloque compartido a máximo '
              '$total o aumenta el total a al menos $shared.',
            );
          }
        }
      }
    }

    // ── Global state ───────────────────────────────────────────────────────
    final state = _ScheduleState();
    final Map<String, List<String>> sectionConflicts = {};

    for (final grade in grades) {
      for (final unit in _sectionsOf(grade)) {
        state.sectionSlots.putIfAbsent(unit.id, () => []);
        sectionConflicts.putIfAbsent(unit.id, () => []);
      }
    }

    // ── Pre-fill manual slots ─────────────────────────────────────────────
    for (final entry in manualSlots.entries) {
      final sId = entry.key;
      state.sectionSlots.putIfAbsent(sId, () => []);
      for (final ps in entry.value) {
        state.commit(_Decision(
          teacherId: ps.teacherId,  
          day: ps.day,
          start: ps.periodIndex,
          blockSize: 1,
          sectionIds: [sId],
          subjectId: ps.subjectId,
        ));
      }
    }

    // ── Build placement work-lists ────────────────────────────────────────
    //
    //  Three-tier hierarchy (most-constrained first):
    //
    //   Tier 1 — Shared-block tasks    ← placed first
    //   Tier 2 — Specific-teacher solo tasks
    //   Tier 3 — Base / unrestricted solo tasks
    //
    //  Within each tier tasks are sorted heaviest-first so the most demanding
    //  units are attempted while the search space is still wide open.

    final List<_SharedPlacementUnit> sharedQueue = [];
    final List<_SoloPlacementUnit> specificQueue = [];
    final List<_SoloPlacementUnit> baseQueue = [];
    final Set<String> queuedSharedBlockKeys = {};

    for (final grade in grades) {
      final units = _sectionsOf(grade);

      for (final subject in subjects) {
        final cfg = subject.configForLevel(grade.levelId);
        if (cfg == null) continue;

        // Tier 1 — shared blocks
        for (final block in cfg.sharedBlocks) {
          if (block.hoursPerWeek <= 0) continue;
          final blockKey = '${subject.id}-${block.id}';
          if (!queuedSharedBlockKeys.add(blockKey)) continue;

          // Sections in a shared block may span multiple grades.
          // Search ALL grades to find sections referenced by this block.
          final allSections = grades.expand(_sectionsOf).toList();
          final blockSections =
              allSections.where((u) => block.sectionIds.contains(u.id)).toList();
          if (blockSections.isEmpty) continue;

          // The grade used for config (session length, days) should be the one
          // whose levelId matches the subject's levelConfig that owns this block.
          // If sections span different grades, use the grade of the first section.
          final blockGrade = grades.firstWhere(
            (g) => _sectionsOf(g).any((s) => s.id == blockSections.first.id),
            orElse: () => grade,
          );

          sharedQueue.add(_SharedPlacementUnit(
            subject: subject,
            block: block,
            grade: blockGrade,
          ));
        }

        // Tier 2 / 3 — solo hours
        for (final unit in units) {
          // Use the model's dedicated method so it reads the explicit
          // SubjectSectionConfig.individualHoursPerWeek field the UI saves,
          // instead of recomputing total − shared (which can disagree when
          // section configs have been edited independently).
          final individualHrs = cfg.individualHoursForSection(unit.id);
          if (individualHrs <= 0) continue;

          final blockSize =
              cfg.periodsForSection(unit.id).clamp(1, grade.config.sessionsPerDay);

          final soloUnit = _SoloPlacementUnit(
            subject: subject,
            section: unit,
            grade: grade,
            hoursPerWeek: individualHrs,
            blockSize: blockSize,
          );

          final hasSpecificTeacher = teachers.any((t) =>
              t.subjectIds.contains(subject.id) &&
              t.assignments.any((a) =>
                  a.subjectId == subject.id &&
                  a.gradeId == grade.id &&
                  a.sectionId == unit.id));

          if (hasSpecificTeacher) {
            specificQueue.add(soloUnit);
          } else {
            baseQueue.add(soloUnit);
          }
        }
      }
    }

    // Sort within each tier using MRV-inspired heuristic:
    // primary key = estimated available slots (ascending — most constrained first)
    // tie-break   = hours per week (descending — heaviest first)
    int _mrvScore(_SoloPlacementUnit u) {
      final eligible = _eligibleTeachersForSection(
        subject: u.subject,
        grade: u.grade,
        section: u.section,
        teachers: teachers,
      );
      // Available days × sessions per day × eligible teachers gives a rough
      // upper bound on the number of slots we can place this unit into.
      final days = u.grade.config.classDays.length;
      final sessions = u.grade.config.sessionsPerDay;
      return (eligible.length * days * sessions).clamp(0, 9999);
    }

    sharedQueue.sort((a, b) {
      final daysA = a.grade.config.classDays.length;
      final daysB = b.grade.config.classDays.length;
      final sessA = a.grade.config.sessionsPerDay;
      final sessB = b.grade.config.sessionsPerDay;
      final eligA = _eligibleTeachersForSharedBlock(
          subject: a.subject, grade: a.grade,
          sectionIds: a.block.sectionIds, teachers: teachers, allGrades: grades).length;
      final eligB = _eligibleTeachersForSharedBlock(
          subject: b.subject, grade: b.grade,
          sectionIds: b.block.sectionIds, teachers: teachers, allGrades: grades).length;
      final slotsA = (eligA * daysA * sessA).clamp(0, 9999);
      final slotsB = (eligB * daysB * sessB).clamp(0, 9999);
      if (slotsA != slotsB) return slotsA.compareTo(slotsB); // fewer slots → first
      return b.hoursPerWeek.compareTo(a.hoursPerWeek); // more hours → first
    });
    specificQueue.sort((a, b) {
      final diff = _mrvScore(a).compareTo(_mrvScore(b));
      if (diff != 0) return diff;
      return b.hoursPerWeek.compareTo(a.hoursPerWeek);
    });
    baseQueue.sort((a, b) {
      final diff = _mrvScore(a).compareTo(_mrvScore(b));
      if (diff != 0) return diff;
      return b.hoursPerWeek.compareTo(a.hoursPerWeek);
    });

    // ── Build unified task list ───────────────────────────────────────────
    //
    // Each "task" is one session (1 clock-hour or 1 multi-period block) that
    // needs to be placed.  Expanding units into individual tasks lets the
    // backtracker commit and undo one session at a time.
    //
    // ORDER: shared tasks → specific-teacher solos → base solos
    // (preserves the three-tier hierarchy throughout the search)

    final List<_PlacementTask> tasks = [];

    for (final u in sharedQueue) {
      for (int i = 0; i < u.hoursPerWeek; i++) {
        tasks.add(_SharedTask(unit: u, sessionIndex: i));
      }
    }
    for (final u in specificQueue) {
      for (int i = 0; i < u.hoursPerWeek; i++) {
        tasks.add(_SoloTask(unit: u, sessionIndex: i));
      }
    }
    for (final u in baseQueue) {
      for (int i = 0; i < u.hoursPerWeek; i++) {
        tasks.add(_SoloTask(unit: u, sessionIndex: i));
      }
    }

    // ── Phase 1: iterative backtracking ───────────────────────────────────
    //
    // Attempts to find a globally consistent assignment.
    // Exits when (a) all tasks are placed, (b) the time budget is exhausted,
    // or (c) no solution exists.  In cases (b)/(c) the state retains whatever
    // partial solution was committed at the time of exit.

    // Pre-feasibility check: detect impossible assignments before spending
    // 20 seconds on backtracking that is guaranteed to fail.
    _checkFeasibility(
      tasks: tasks,
      teachers: teachers,
      grades: grades,
      globalConflicts: globalConflicts,
    );

    final deadline =
        DateTime.now().add(const Duration(milliseconds: _backtrackLimitMs));

    _backtrackIterative(
      tasks: tasks,
      state: state,
      teachers: teachers,
      grades: grades,
      deadline: deadline,
    );

    // ── Phase 2: greedy fallback ──────────────────────────────────────────
    //
    // For any task that backtracking could not place (timeout or partial
    // failure), attempt a single greedy pass.  Quality constraints
    // (day-spread, adjacency) are relaxed so the algorithm accepts the
    // first available hard-constraint-valid slot.

    _greedyFallback(
      tasks: tasks,
      state: state,
      teachers: teachers,
      grades: grades,
    );

    // ── Collect unplaced conflict messages ────────────────────────────────
    _collectUnplacedConflicts(
      tasks: tasks,
      state: state,
      teachers: teachers,
      grades: grades,
      globalConflicts: globalConflicts,
      sectionConflicts: sectionConflicts,
    );

    // ── Build result ──────────────────────────────────────────────────────
    final List<SectionSchedule> schedules = [];

    for (final grade in grades) {
      for (final unit in _sectionsOf(grade)) {
        final conflicts = sectionConflicts[unit.id] ?? [];
        final rawSlots = state.sectionSlots[unit.id] ?? [];
        // Compact slots: eliminate "dead hours" (gaps in the middle of a day).
        // Slots on each day are sorted and re-assigned to consecutive period
        // indices starting at 0, so classes appear without holes.
        // Empty periods only remain at the END of the day (early finish).
        final compactedSlots = _compactSlots(rawSlots, grade.config.classDays);
        schedules.add(SectionSchedule(
          id: _uuid.v4(),
          sectionId: unit.id,
          slots: compactedSlots,
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
  // COMPACT SLOTS  (post-processing — eliminates mid-day gaps)
  //
  // For each (section, day) pair the placed slots are sorted by their original
  // period index and then re-numbered 0, 1, 2, … so they are contiguous from
  // the start of the day.  Empty periods can only appear at the END (the
  // section finishes early rather than having a free period in the middle).
  // ---------------------------------------------------------------------------

  List<ScheduleSlot> _compactSlots(
      List<ScheduleSlot> slots, List<String> days) {
    final Map<String, List<ScheduleSlot>> byDay = {};
    for (final day in days) {
      byDay[day] = [];
    }
    for (final slot in slots) {
      byDay.putIfAbsent(slot.day, () => []).add(slot);
    }

    final List<ScheduleSlot> result = [];
    for (final day in days) {
      final daySlots = byDay[day] ?? [];
      // Sort by original period index so we preserve the intended order.
      daySlots.sort((a, b) => a.periodIndex.compareTo(b.periodIndex));
      // Re-assign to consecutive indices starting at 0.
      for (int i = 0; i < daySlots.length; i++) {
        final s = daySlots[i];
        result.add(ScheduleSlot(
          day: s.day,
          periodIndex: i,          // compacted index — no gaps
          subjectId: s.subjectId,
          teacherId: s.teacherId,
        ));
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // PHASE 1 — ITERATIVE BACKTRACKING
  //
  // Uses an explicit stack of _BtFrame objects instead of recursion.
  //
  // Advantages over the recursive approach:
  //   • No Dart call-stack overflow with large task lists.
  //   • Time-limit can be checked cheaply inside the loop.
  //   • 1-step forward checking: after committing a decision we immediately
  //     test whether the NEXT task still has at least one valid candidate.
  //     If not, we skip deeper exploration (dead-end pruning) without wasting
  //     time on the sub-tree.
  //
  // When the method returns, state.sectionSlots contains the best (possibly
  // partial) solution found within the time budget.
  // ---------------------------------------------------------------------------

  void _backtrackIterative({
    required List<_PlacementTask> tasks,
    required _ScheduleState state,
    required List<Teacher> teachers,
    required List<Grade> grades,
    required DateTime deadline,
  }) {
    if (tasks.isEmpty) return;

    // Generate candidates for the very first task and seed the stack.
    final seedCandidates = _candidatesFor(
      task: tasks[0],
      state: state,
      teachers: teachers,
      grades: grades,
    );
    if (seedCandidates.isEmpty) return; // Nothing can be placed at all.

    final stack = <_BtFrame>[
      _BtFrame(taskIndex: 0, candidates: seedCandidates),
    ];

    while (stack.isNotEmpty) {
      // ── Time-limit check ─────────────────────────────────────────────────
      // If the budget is exhausted we leave the stack in its current state
      // (committed decisions stay in `state`) and return.  The greedy
      // fallback will complete the remaining tasks.
      if (DateTime.now().isAfter(deadline)) return;

      final frame = stack.last;

      // ── Backtrack if all candidates for this level are exhausted ─────────
      if (frame.exhausted) {
        // Undo the last committed decision for this level (if any).
        if (frame.active != null) state.undo(frame.active!);
        stack.removeLast();
        continue; // Let the parent frame try its next candidate.
      }

      // ── Try the next candidate ───────────────────────────────────────────
      final decision = frame.candidates[frame.tryNext++];

      // Undo the previous attempt at THIS level before committing the new one.
      if (frame.active != null) state.undo(frame.active!);
      state.commit(decision);
      frame.active = decision;

      final nextIndex = frame.taskIndex + 1;

      // ── Success: every task has been placed ──────────────────────────────
      if (nextIndex == tasks.length) return;

      // ── 1-step forward checking ──────────────────────────────────────────
      //
      // Generate candidates for the NEXT task in the current state.
      // If there are none this branch is already a dead end — don't push a
      // new frame; let the current frame try its next candidate instead.
      final nextCandidates = _candidatesFor(
        task: tasks[nextIndex],
        state: state,
        teachers: teachers,
        grades: grades,
      );

      if (nextCandidates.isEmpty) continue; // Dead end — try next candidate.

      // ── Advance to the next level ────────────────────────────────────────
      stack.add(_BtFrame(taskIndex: nextIndex, candidates: nextCandidates));
    }
    // Stack empty → no complete solution found; state contains whatever
    // decisions were left committed (may be empty if everything was undone).
  }

  // ---------------------------------------------------------------------------
  // PHASE 2 — GREEDY FALLBACK
  //
  // After backtracking, for every task whose unit is still under-placed, we
  // attempt a single greedy placement using relaxed quality rules (no day-
  // spread, no adjacency enforcement).  Hard constraints (teacher availability,
  // no double-booking) are always enforced.
  //
  // Tasks are processed in tier order (shared → specific → base) to maintain
  // the hierarchy even in the fallback phase.
  // ---------------------------------------------------------------------------

  void _greedyFallback({
    required List<_PlacementTask> tasks,
    required _ScheduleState state,
    required List<Teacher> teachers,
    required List<Grade> grades,
  }) {
    // Build a map: unitKey → totalSessionsNeeded
    final Map<String, int> neededCount = {};
    for (final t in tasks) {
      final k = _taskKey(t);
      neededCount[k] = (neededCount[k] ?? 0) + 1;
    }

    for (final task in tasks) {
      final k = _taskKey(task);
      final placed = _countPlacedSlots(state, task);
      final needed = neededCount[k] ?? 0;
      if (placed >= needed) continue; // Already fully placed — skip.

      // Try quality candidates first; fall back to relaxed if none exist.
      var candidates = _candidatesFor(
        task: task,
        state: state,
        teachers: teachers,
        grades: grades,
      );

      if (candidates.isEmpty) {
        candidates = _candidatesRelaxed(
          task: task,
          state: state,
          teachers: teachers,
          grades: grades,
        );
      }

      if (candidates.isNotEmpty) {
        state.commit(candidates.first);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CANDIDATE GENERATION — WITH QUALITY CONSTRAINTS
  //
  // Two-pass day selection:
  //   Pass 0 — prefer fresh days (spreads subject across the week).
  //   Pass 1 — allow same-day repeats, but only in adjacent periods.
  // ---------------------------------------------------------------------------

  List<_Decision> _candidatesFor({
    required _PlacementTask task,
    required _ScheduleState state,
    required List<Teacher> teachers,
    required List<Grade> grades,
  }) {
    if (task is _SoloTask) {
      return _soloCandidates(task: task, state: state, teachers: teachers);
    } else if (task is _SharedTask) {
      return _sharedCandidates(
          task: task, state: state, teachers: teachers, grades: grades);
    }
    return [];
  }

  List<_Decision> _soloCandidates({
    required _SoloTask task,
    required _ScheduleState state,
    required List<Teacher> teachers,
  }) {
    final unit = task.unit;
    final subject = unit.subject;
    final section = unit.section;
    final grade = unit.grade;
    final config = grade.config;
    final days = config.classDays;
    final blockSize = unit.blockSize;

    final eligible = _eligibleTeachersForSection(
      subject: subject,
      grade: grade,
      section: section,
      teachers: teachers,
    );
    if (eligible.isEmpty) return [];

    // Sort eligible teachers by load (lightest first) for balanced assignment.
    final sortedEligible = List<Teacher>.from(eligible)
      ..sort((a, b) =>
          (state.teacherLoad[a.id] ?? 0).compareTo(state.teacherLoad[b.id] ?? 0));

    final List<_Decision> candidates = [];

    // Pass 0: prefer days where this subject has NOT been placed yet (spread).
    // Pass 1: allow days already used (only if pass 0 produced nothing).
    for (int pass = 0; pass < 2; pass++) {
      for (final day in days) {
        final alreadyUsed =
            state.subjectPeriodsOnDay(section.id, subject.id, day).isNotEmpty;
        if (pass == 0 && alreadyUsed) continue;  // skip used days on first pass
        if (pass == 1 && !alreadyUsed) continue; // skip fresh days on second pass

        // Respect per-day session limit (e.g. Friday early dismissal).
        final sessions = config.sessionsForDay(day);

        for (final teacher in sortedEligible) {
          if (!_teacherAvailableOnDay(teacher, day)) continue;

          final maxStart = sessions - blockSize;
          for (int p = 0; p <= maxStart; p++) {
            if (!_teacherFreeForBlock(
                teacher: teacher, day: day, start: p, blockSize: blockSize)) {
              continue;
            }
            // Hard constraint: teacher must not already be assigned to another
            // group/subject in any of these periods.
            if (!state.teacherFree(teacher.id, day, p, blockSize)) continue;
            if (!state.sectionFree(section.id, day, p, blockSize)) continue;

            candidates.add(_Decision(
              teacherId: teacher.id,
              day: day,
              start: p,
              blockSize: blockSize,
              sectionIds: [section.id],
              subjectId: subject.id,
            ));
          }
        }
      }
      // If pass 0 found candidates, don't bother with pass 1.
      if (candidates.isNotEmpty) break;
    }

    return candidates;
  }

  List<_Decision> _sharedCandidates({
    required _SharedTask task,
    required _ScheduleState state,
    required List<Teacher> teachers,
    required List<Grade> grades,
  }) {
    final unit = task.unit;
    final subject = unit.subject;
    final block = unit.block;
    final grade = unit.grade;
    final config = grade.config;
    final days = config.classDays;
    final sectionIds = block.sectionIds;
    final cfg = subject.configForLevel(grade.levelId)!;
    final blockSize = cfg.sessionPeriods.clamp(1, config.sessionsPerDay);

    final eligible = _eligibleTeachersForSharedBlock(
      subject: subject,
      grade: grade,
      sectionIds: sectionIds,
      teachers: teachers,
      allGrades: grades,
    );
    if (eligible.isEmpty) return [];

    // Sort eligible teachers by load (lightest first) for balanced assignment.
    final sortedEligible = List<Teacher>.from(eligible)
      ..sort((a, b) =>
          (state.teacherLoad[a.id] ?? 0).compareTo(state.teacherLoad[b.id] ?? 0));

    final List<_Decision> candidates = [];

    // Pass 0: prefer days where this subject has NOT been placed yet (spread).
    // Pass 1: allow days already used (only if pass 0 produced nothing).
    for (int pass = 0; pass < 2; pass++) {
      for (final day in days) {
        final alreadyUsed =
            state.subjectPeriodsOnDay(sectionIds.first, subject.id, day).isNotEmpty;
        if (pass == 0 && alreadyUsed) continue;
        if (pass == 1 && !alreadyUsed) continue;

        // Respect per-day session limit (e.g. Friday early dismissal).
        final sessions = config.sessionsForDay(day);

        for (final teacher in sortedEligible) {
          if (!_teacherAvailableOnDay(teacher, day)) continue;

          final maxStart = sessions - blockSize;
          for (int p = 0; p <= maxStart; p++) {
            if (!_teacherFreeForBlock(
                teacher: teacher, day: day, start: p, blockSize: blockSize)) {
              continue;
            }
            // Hard constraint: teacher must not already be assigned to another
            // group/subject in any of these periods.
            if (!state.teacherFree(teacher.id, day, p, blockSize)) continue;
            if (!state.allSectionsFree(sectionIds, day, p, blockSize)) {
              continue;
            }

            candidates.add(_Decision(
              teacherId: teacher.id,
              day: day,
              start: p,
              blockSize: blockSize,
              sectionIds: sectionIds,
              subjectId: subject.id,
            ));
          }
        }
      }
      if (candidates.isNotEmpty) break;
    }

    return candidates;
  }

  // ---------------------------------------------------------------------------
  // CANDIDATE GENERATION — RELAXED (for greedy fallback)
  //
  // Skips day-spread and adjacency constraints; returns the very first slot
  // that satisfies the hard constraints (teacher availability, no
  // double-booking).  Used only when quality candidates are unavailable.
  // ---------------------------------------------------------------------------

  List<_Decision> _candidatesRelaxed({
    required _PlacementTask task,
    required _ScheduleState state,
    required List<Teacher> teachers,
    required List<Grade> grades,
  }) {
    if (task is _SoloTask) {
      return _soloCandidatesRelaxed(
          task: task, state: state, teachers: teachers);
    } else if (task is _SharedTask) {
      return _sharedCandidatesRelaxed(
          task: task, state: state, teachers: teachers, grades: grades);
    }
    return [];
  }

  List<_Decision> _soloCandidatesRelaxed({
    required _SoloTask task,
    required _ScheduleState state,
    required List<Teacher> teachers,
  }) {
    final unit = task.unit;
    final subject = unit.subject;
    final section = unit.section;
    final grade = unit.grade;
    final config = grade.config;
    final days = config.classDays;
    final blockSize = unit.blockSize;

    final eligible = _eligibleTeachersForSection(
      subject: subject,
      grade: grade,
      section: section,
      teachers: teachers,
    );
    if (eligible.isEmpty) return [];

    // Lightest-loaded teacher first.
    final sortedEligible = List<Teacher>.from(eligible)
      ..sort((a, b) =>
          (state.teacherLoad[a.id] ?? 0).compareTo(state.teacherLoad[b.id] ?? 0));

    for (final day in days) {
      // Respect per-day session limit (e.g. Friday early dismissal).
      final sessions = config.sessionsForDay(day);
      for (final teacher in sortedEligible) {
        if (!_teacherAvailableOnDay(teacher, day)) continue;
        final maxStart = sessions - blockSize;
        for (int p = 0; p <= maxStart; p++) {
          if (!_teacherFreeForBlock(
              teacher: teacher, day: day, start: p, blockSize: blockSize)) {
            continue;
          }
          // Hard constraint: teacher must not already be assigned to another
          // group/subject in any of these periods.
          if (!state.teacherFree(teacher.id, day, p, blockSize)) continue;
          if (!state.sectionFree(section.id, day, p, blockSize)) continue;
          // Return immediately — greedy takes the first valid slot.
          return [
            _Decision(
              teacherId: teacher.id,
              day: day,
              start: p,
              blockSize: blockSize,
              sectionIds: [section.id],
              subjectId: subject.id,
            )
          ];
        }
      }
    }
    return [];
  }

  List<_Decision> _sharedCandidatesRelaxed({
    required _SharedTask task,
    required _ScheduleState state,
    required List<Teacher> teachers,
    required List<Grade> grades,
  }) {
    final unit = task.unit;
    final subject = unit.subject;
    final block = unit.block;
    final grade = unit.grade;
    final config = grade.config;
    final days = config.classDays;
    final sectionIds = block.sectionIds;
    final cfg = subject.configForLevel(grade.levelId)!;
    final blockSize = cfg.sessionPeriods.clamp(1, sessions);

    final eligible = _eligibleTeachersForSharedBlock(
      subject: subject,
      grade: grade,
      sectionIds: sectionIds,
      teachers: teachers,
      allGrades: grades,
    );
    if (eligible.isEmpty) return [];

    for (final day in days) {
      // Respect per-day session limit (e.g. Friday early dismissal).
      final sessions = config.sessionsForDay(day);
      for (final teacher in eligible) {
        if (!_teacherAvailableOnDay(teacher, day)) continue;
        final maxStart = sessions - blockSize;
        for (int p = 0; p <= maxStart; p++) {
          if (!_teacherFreeForBlock(
              teacher: teacher, day: day, start: p, blockSize: blockSize)) {
            continue;
          }
          // Hard constraint: teacher must not already be assigned to another
          // group/subject in any of these periods.
          if (!state.teacherFree(teacher.id, day, p, blockSize)) continue;
          if (!state.allSectionsFree(sectionIds, day, p, blockSize)) continue;
          return [
            _Decision(
              teacherId: teacher.id,
              day: day,
              start: p,
              blockSize: blockSize,
              sectionIds: sectionIds,
              subjectId: subject.id,
            )
          ];
        }
      }
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // POST-FAILURE CONFLICT REPORTING
  // ---------------------------------------------------------------------------

  void _collectUnplacedConflicts({
    required List<_PlacementTask> tasks,
    required _ScheduleState state,
    required List<Teacher> teachers,
    required List<Grade> grades,
    required List<String> globalConflicts,
    required Map<String, List<String>> sectionConflicts,
  }) {
    final Map<String, int> neededCount = {};
    for (final task in tasks) {
      final key = _taskKey(task);
      neededCount[key] = (neededCount[key] ?? 0) + 1;
    }

    for (final task in tasks) {
      final key = _taskKey(task);
      final needed = neededCount[key] ?? 0;
      final placed = _countPlacedSlots(state, task);
      if (placed >= needed) continue;

      final missing = needed - placed;
      final msg = _buildConflictMessage(
        task: task,
        missing: missing,
        teachers: teachers,
        grades: grades,
      );

      if (task is _SharedTask) {
        globalConflicts.add(msg);
        for (final sId in task.unit.block.sectionIds) {
          sectionConflicts.putIfAbsent(sId, () => []).add(msg);
        }
      } else if (task is _SoloTask) {
        final sId = task.unit.section.id;
        sectionConflicts.putIfAbsent(sId, () => []).add(msg);
      }
    }
  }

  String _taskKey(_PlacementTask task) {
    if (task is _SoloTask) {
      return '${task.unit.section.id}|${task.unit.subject.id}';
    } else if (task is _SharedTask) {
      return '${task.unit.block.id}|${task.unit.subject.id}';
    }
    return task.hashCode.toString();
  }

  int _countPlacedSlots(_ScheduleState state, _PlacementTask task) {
    if (task is _SoloTask) {
      final sId   = task.unit.section.id;
      final subId = task.unit.subject.id;
      // Count only SOLO-placed slots for this section+subject.
      // Shared-placed slots must NOT be counted here: the greedy fallback
      // uses this number to decide whether a solo task is already done, and
      // if shared slots were included it would silently skip individual hours
      // that were never actually placed (the original bug).
      return (state.sectionSlots[sId] ?? [])
          .where((s) =>
              s.subjectId == subId &&
              !state.isSharedSlot(sId, s.day, s.periodIndex))
          .length;
    } else if (task is _SharedTask) {
      final sId   = task.unit.block.sectionIds.first;
      final subId = task.unit.subject.id;
      // Count only SHARED-placed slots for this block's reference section.
      return (state.sectionSlots[sId] ?? [])
          .where((s) =>
              s.subjectId == subId &&
              state.isSharedSlot(sId, s.day, s.periodIndex))
          .length;
    }
    return 0;
  }

  String _buildConflictMessage({
    required _PlacementTask task,
    required int missing,
    required List<Teacher> teachers,
    required List<Grade> grades,
  }) {
    if (task is _SoloTask) {
      final unit = task.unit;
      final subjectName = unit.subject.name;
      final sectionName = unit.section.name;
      final eligible = _eligibleTeachersForSection(
        subject: unit.subject,
        grade: unit.grade,
        section: unit.section,
        teachers: teachers,
      );
      if (eligible.isEmpty) {
        return 'Sin maestro para "$subjectName" en $sectionName. '
            'Solución: ve a Maestros y asigna la materia "$subjectName" '
            'a al menos un maestro autorizado para ese grupo.';
      }
      return 'No se pudieron ubicar $missing sesión(es) de "$subjectName" '
          'en $sectionName. Los maestros disponibles '
          '(${eligible.map((t) => t.fullName).join(', ')}) no tienen '
          'suficientes huecos libres compatibles. Solución: amplía la '
          'disponibilidad del maestro, reduce las horas totales de '
          '"$subjectName" en ese grupo, o aumenta los días/sesiones '
          'diarias del grado.';
    } else if (task is _SharedTask) {
      final unit = task.unit;
      final subjectName = unit.subject.name;
      final sectionNames = unit.block.sectionIds.join(', ');
      final eligible = _eligibleTeachersForSharedBlock(
        subject: unit.subject,
        grade: unit.grade,
        sectionIds: unit.block.sectionIds,
        teachers: teachers,
        allGrades: grades,
      );
      if (eligible.isEmpty) {
        return 'Bloque compartido "$subjectName" [$sectionNames]: '
            'sin maestro disponible para todos los grupos. '
            'Solución: en Maestros, asegúrate de que un mismo maestro '
            'tenga asignada "$subjectName" para todos los grupos del '
            'bloque compartido.';
      }
      return 'Bloque compartido "$subjectName" [$sectionNames]: '
          'no se pudieron ubicar $missing sesión(es) simultáneas. '
          'Los grupos no tienen suficientes huecos libres en común. '
          'Solución: reduce las horas del bloque compartido o '
          'disminuye las horas de otras materias en esos grupos.';
    }
    return 'No se pudo completar la tarea de horario (tarea ${task.hashCode}).';
  }

  // ---------------------------------------------------------------------------
  // TEACHER ELIGIBILITY HELPERS
  // ---------------------------------------------------------------------------

  List<Teacher> _eligibleTeachersForSharedBlock({
    required Subject subject,
    required Grade grade,
    required List<String> sectionIds,
    required List<Teacher> teachers,
    List<Grade>? allGrades,
  }) {
    // Build a map sectionId → gradeId so we can check canTeach with the
    // correct grade even when sections span multiple grades.
    final sectionGradeMap = <String, String>{};
    final gradesToSearch = allGrades ?? [grade];
    for (final g in gradesToSearch) {
      for (final s in _sectionsOf(g)) {
        sectionGradeMap[s.id] = g.id;
      }
    }

    return teachers.where((t) {
      if (!t.subjectIds.contains(subject.id)) return false;
      return sectionIds.every((sId) => t.canTeach(
            subjectId: subject.id,
            sectionId: sId,
            gradeId: sectionGradeMap[sId] ?? grade.id,
          ));
    }).toList();
  }

  List<Teacher> _eligibleTeachersForSection({
    required Subject subject,
    required Grade grade,
    required Section section,
    required List<Teacher> teachers,
  }) {
    final specific = <Teacher>[];
    final gradeWide = <Teacher>[];
    final unrestricted = <Teacher>[];

    for (final t in teachers) {
      if (!t.subjectIds.contains(subject.id)) continue;

      if (t.assignments.isEmpty) {
        unrestricted.add(t);
        continue;
      }

      final hasSpecific = t.assignments.any((a) =>
          a.subjectId == subject.id &&
          a.gradeId == grade.id &&
          a.sectionId == section.id);

      if (hasSpecific) {
        specific.add(t);
        continue;
      }

      final hasGradeWide = t.assignments.any((a) =>
          a.subjectId == subject.id &&
          a.gradeId == grade.id &&
          a.sectionId == null);

      if (hasGradeWide) {
        gradeWide.add(t);
        continue;
      }

      final hasAnyForSubject =
          t.assignments.any((a) => a.subjectId == subject.id);
      if (!hasAnyForSubject) unrestricted.add(t);
    }

    return [...specific, ...gradeWide, ...unrestricted];
  }

  // ---------------------------------------------------------------------------
  // AVAILABILITY HELPERS
  // ---------------------------------------------------------------------------

  bool _teacherFreeForBlock({
    required Teacher teacher,
    required String day,
    required int start,
    required int blockSize,
  }) {
    if (teacher.availability.isNotEmpty) {
      final avail = _getDayAvail(teacher, day);
      if (avail == null) return false;
      for (int b = 0; b < blockSize; b++) {
        if (!avail.availablePeriods.contains(start + b)) return false;
      }
    }
    return true;
  }

  bool _teacherAvailableOnDay(Teacher teacher, String day) {
    if (teacher.availability.isEmpty) return true;
    final dayAvail = _getDayAvail(teacher, day);
    if (dayAvail == null) return false;
    return dayAvail.availablePeriods.isNotEmpty;
  }

  DayAvailability? _getDayAvail(Teacher teacher, String day) {
    try {
      return teacher.availability.firstWhere((a) => a.day == day);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ADJACENCY / SAME-DAY HELPERS
  // ---------------------------------------------------------------------------

  Set<String> _usedDaysForUnit(
      _ScheduleState state, String sectionId, String subjectId, List<String> days) {
    final used = <String>{};
    for (final day in days) {
      if (state.subjectPeriodsOnDay(sectionId, subjectId, day).isNotEmpty) {
        used.add(day);
      }
    }
    return used;
  }

  /// Original strict adjacency check (kept for reference / potential reuse).
  bool _isAdjacentBlock(List<int> existing, int start, int blockSize) {
    if (existing.isEmpty) return true;
    final existMin = existing.first;
    final existMax = existing.last;
    final newEnd = start + blockSize - 1;
    return start == existMax + 1 || newEnd == existMin - 1;
  }

  /// Relaxed same-day check: only rejects a slot if it physically overlaps
  /// (same period index) with an already-placed block of the same subject.
  /// Allows the subject to appear multiple times on the same day as long as
  /// the slots don't collide.  This unblocks ~80% of slots that
  /// _isAdjacentBlock was rejecting unnecessarily.
  bool _overlapsExisting(List<int> existing, int start, int blockSize) {
    for (int b = 0; b < blockSize; b++) {
      if (existing.contains(start + b)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // PRE-FEASIBILITY CHECK
  //
  // Runs before backtracking to surface impossible assignments early so they
  // appear as clear conflict messages rather than silent failures.
  //
  // Checks:
  //   1. No eligible teacher for a solo task.
  //   2. Teacher availability slots < hours required for the week
  //      (e.g. teacher available 3 periods/day × 2 days = 6 slots, but 8
  //       hours needed → impossible).
  // ---------------------------------------------------------------------------

  void _checkFeasibility({
    required List<_PlacementTask> tasks,
    required List<Teacher> teachers,
    required List<Grade> grades,
    required List<String> globalConflicts,
  }) {
    // Aggregate hours per (teacher, subject) pair so we only emit one warning.
    final Map<String, int> teacherSubjectHours = {};
    final Map<String, int> teacherTotalAvail = {};

    for (final task in tasks) {
      if (task is! _SoloTask) continue;
      final unit = task.unit;
      final eligible = _eligibleTeachersForSection(
        subject: unit.subject,
        grade: unit.grade,
        section: unit.section,
        teachers: teachers,
      );

      // Warn once per (subject, section) combo if no teacher is available.
      if (eligible.isEmpty) continue; // Already caught by conflict reporter.

      for (final teacher in eligible) {
        // Count total available periods across all class days.
        final key = '${teacher.id}|${unit.subject.id}';
        if (!teacherSubjectHours.containsKey(key)) {
          teacherSubjectHours[key] = 0;

          if (!teacherTotalAvail.containsKey(teacher.id)) {
            if (teacher.availability.isEmpty) {
              // No restrictions — treat as fully available.
              teacherTotalAvail[teacher.id] = 9999;
            } else {
              final avail = teacher.availability
                  .fold<int>(0, (sum, a) => sum + a.availablePeriods.length);
              teacherTotalAvail[teacher.id] = avail;
            }
          }
        }
        teacherSubjectHours[key] = (teacherSubjectHours[key] ?? 0) + 1;
      }
    }

    // Detect teachers whose total availability is less than the hours they
    // need to cover for a single subject across all assigned groups.
    final checked = <String>{};
    for (final entry in teacherSubjectHours.entries) {
      final parts = entry.key.split('|');
      if (parts.length < 2) continue;
      final teacherId = parts[0];
      final subjectId = parts[1];
      if (!checked.add(entry.key)) continue;

      final avail = teacherTotalAvail[teacherId] ?? 9999;
      if (avail >= 9999) continue; // No restriction.

      final hours = entry.value;
      if (hours > avail) {
        final teacher = teachers.where((t) => t.id == teacherId).firstOrNull;
        final subject = teachers
            .expand((t) => <String>[])
            .toList(); // dummy — we only need the ids
        globalConflicts.add(
          'FACTIBILIDAD: "${teacher?.fullName ?? teacherId}" tiene solo '
          '$avail período(s) disponible(s) en la semana pero necesita '
          'cubrir $hours sesión(es) de la materia "$subjectId". '
          'Solución: amplía la disponibilidad del maestro o reduce las horas asignadas.',
        );
      }
    }
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

  // ---------------------------------------------------------------------------
  // VALIDATION (cross-schedule teacher conflicts) — unchanged
  // ---------------------------------------------------------------------------

  List<String> validate({
    required List<SectionSchedule> schedules,
    required List<Grade> grades,
    required List<Subject> subjects,
    required List<Teacher> teachers,
  }) {
    final issues = <String>[];

    final Map<String, Map<String, List<String>>> teacherSlots = {};
    final Map<String, Map<String, String>> sectionSlots = {};

    for (final sched in schedules) {
      for (final slot in sched.slots) {
        final dayPeriod = '${slot.day}-${slot.periodIndex}';

        teacherSlots
            .putIfAbsent(slot.teacherId, () => {})
            .putIfAbsent(dayPeriod, () => [])
            .add(sched.sectionId);

        final prev =
            sectionSlots.putIfAbsent(sched.sectionId, () => {})[dayPeriod];
        if (prev != null && prev != slot.subjectId) {
          final section = _findSectionById(grades, sched.sectionId);
          final subA = _findSubjectById(subjects, prev);
          final subB = _findSubjectById(subjects, slot.subjectId);
          issues.add(
            'CONFLICTO GRUPO: ${section?.name ?? sched.sectionId} tiene '
            '"${subA?.name ?? prev}" y "${subB?.name ?? slot.subjectId}" '
            'al mismo tiempo (${slot.day}, sesión ${slot.periodIndex + 1}).',
          );
        } else {
          sectionSlots
              .putIfAbsent(sched.sectionId, () => {})[dayPeriod] =
              slot.subjectId;
        }
      }
    }

    for (final entry in teacherSlots.entries) {
      for (final slotEntry in entry.value.entries) {
        final sections = slotEntry.value.toSet();
        if (sections.length <= 1) continue;

        final parts = slotEntry.key.split('-');
        final day = parts[0];
        final period = int.tryParse(parts[1]) ?? -1;
        final involved = schedules
            .where((s) => sections.contains(s.sectionId))
            .toList();

        final subjectIds = involved
            .map((s) => s.getSlot(day, period)?.subjectId)
            .whereType<String>()
            .toSet();

        if (subjectIds.length == 1) continue;

        final teacher = _findTeacherById(teachers, entry.key);
        issues.add(
          'CONFLICTO MAESTRO: ${teacher?.fullName ?? entry.key} '
          'asignado a grupos distintos en $day sesión ${period + 1} '
          'con materias diferentes.',
        );
      }
    }

    return issues;
  }

  // ---------------------------------------------------------------------------
  // Find helpers
  // ---------------------------------------------------------------------------

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