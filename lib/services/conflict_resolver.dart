import '../models/models.dart';

// =============================================================================
// TIPOS DE CONFLICTO
// =============================================================================

/// Distingue entre un maestro que aparece en dos salones a la vez
/// y una materia que no tiene suficientes sesiones programadas.
enum ConflictType {
  /// El mismo maestro está asignado a 2+ grupos en el mismo periodo.
  doubleBooking,

  /// Una materia requiere N sesiones/semana en una sección pero el horario
  /// generado tiene menos de N (el generador no encontró maestro disponible).
  coverageGap,
}

// =============================================================================
// TIPOS DE SUGERENCIA
// =============================================================================

enum SuggestionKind {
  /// Mover el slot conflictivo a otro periodo libre.
  moveSlot,

  /// Reemplazar al maestro del slot por otro disponible.
  swapTeacher,

  /// Intercambiar dos slots del mismo maestro para deshacer el choque.
  swapSlots,

  /// No existe otro maestro para esta materia → se debe contratar uno.
  needsNewTeacher,

  /// Otro maestro conoce la materia pero también está ocupado en ese periodo.
  reassignToOccupied,

  /// [coverageGap] Un maestro habilitado tiene horas libres esta semana;
  /// puede asumir los periodos faltantes si se edita el horario.
  assignFreeTeacher,

  /// [coverageGap] Un maestro conoce la materia pero sus restricciones de
  /// disponibilidad no cubren los periodos que faltan.
  expandAvailability,
}

// =============================================================================
// INFORMACIÓN DE DISPONIBILIDAD DE MAESTRO  (para coverageGap)
// =============================================================================

/// Resumen de qué tan libre está un maestro para cubrir horas faltantes.
class TeacherFreeTimeInfo {
  final Teacher teacher;

  /// Periodos libres contados en toda la semana según el horario actual.
  final int freePeriodsTotal;

  /// Días en los que el maestro tiene al menos un periodo libre.
  final List<String> freeDays;

  /// Periodos que ya imparte en la semana (carga actual).
  final int currentLoad;

  /// true si ya tiene asignación (explícita) para esta sección/grado.
  final bool isAssignedToSection;

  const TeacherFreeTimeInfo({
    required this.teacher,
    required this.freePeriodsTotal,
    required this.freeDays,
    required this.currentLoad,
    required this.isAssignedToSection,
  });
}

// =============================================================================
// SUGERENCIA CONCRETA
// =============================================================================

class ConflictSuggestion {
  final SuggestionKind kind;
  final String description;
  final int cost; // menor = mejor

  // ── Datos para doubleBooking ──────────────────────────────────────────────
  final ScheduleSlot? slotToMove;
  final String? targetDay;
  final int? targetPeriod;
  final String? sectionId;
  final Teacher? alternativeTeacher;
  final ScheduleSlot? slotA;
  final ScheduleSlot? slotB;
  final String? sectionIdA;
  final String? sectionIdB;
  final Subject? subjectNeeded;

  // ── Datos extra para coverageGap ──────────────────────────────────────────
  /// Lista de maestros con tiempo libre (para assignFreeTeacher).
  final List<TeacherFreeTimeInfo> freeTeachers;

  /// Lista de maestros que conocen la materia pero están saturados.
  final List<TeacherFreeTimeInfo> busyTeachers;

  const ConflictSuggestion({
    required this.kind,
    required this.description,
    required this.cost,
    this.slotToMove,
    this.targetDay,
    this.targetPeriod,
    this.sectionId,
    this.alternativeTeacher,
    this.slotA,
    this.slotB,
    this.sectionIdA,
    this.sectionIdB,
    this.subjectNeeded,
    this.freeTeachers = const [],
    this.busyTeachers = const [],
  });
}

// =============================================================================
// CONFLICTO ENRIQUECIDO
// =============================================================================

class RichConflict {
  final ConflictType type;
  final List<ConflictSuggestion> suggestions;

  // ── Campos para doubleBooking ─────────────────────────────────────────────
  final Teacher? teacher;
  final String day;
  final int periodIndex;
  final String periodLabel;
  final List<ConflictSlotDetail> details;

  // ── Campos para coverageGap ───────────────────────────────────────────────
  /// ID de la sección que tiene la brecha.
  final String? gapSectionId;
  final String? gapSectionLabel;
  final Subject? gapSubject;
  final Grade? gapGrade;

  /// Cuántas sesiones/semana se requieren según la configuración.
  final int requiredHours;

  /// Cuántas sesiones/semana están actualmente en el horario.
  final int scheduledHours;

  const RichConflict({
    required this.type,
    required this.suggestions,
    // doubleBooking
    this.teacher,
    this.day = '',
    this.periodIndex = -1,
    this.periodLabel = '',
    this.details = const [],
    // coverageGap
    this.gapSectionId,
    this.gapSectionLabel,
    this.gapSubject,
    this.gapGrade,
    this.requiredHours = 0,
    this.scheduledHours = 0,
  });

  bool get hasSuggestions => suggestions.isNotEmpty;

  int get missingHours => requiredHours - scheduledHours;
}

class ConflictSlotDetail {
  final String sectionId;
  final String sectionLabel;
  final Subject? subject;
  final ScheduleSlot slot;

  const ConflictSlotDetail({
    required this.sectionId,
    required this.sectionLabel,
    required this.subject,
    required this.slot,
  });
}

// =============================================================================
// SERVICIO PRINCIPAL
// =============================================================================

class ConflictResolverService {
  // ---------------------------------------------------------------------------
  // ENTRY POINT
  // ---------------------------------------------------------------------------

  List<RichConflict> analyze({
    required List<SectionSchedule> schedules,
    required List<Grade> grades,
    required List<Subject> subjects,
    required List<Teacher> teachers,
  }) {
    final result = <RichConflict>[];

    // ── Paso 1: Detectar choques de maestro (doubleBooking) ─────────────────
    result.addAll(_detectDoubleBookings(
      schedules: schedules,
      grades: grades,
      subjects: subjects,
      teachers: teachers,
    ));

    // ── Paso 2: Detectar brechas de cobertura (coverageGap) ─────────────────
    result.addAll(_detectCoverageGaps(
      schedules: schedules,
      grades: grades,
      subjects: subjects,
      teachers: teachers,
    ));

    // Ordenar: doubleBookings con sugerencias primero, luego coverageGaps,
    // luego sin sugerencias; dentro de cada grupo por nombre de grupo.
    result.sort((a, b) {
      // Priorizar conflictos con sugerencias
      final hasSugA = a.hasSuggestions ? 0 : 1;
      final hasSugB = b.hasSuggestions ? 0 : 1;
      if (hasSugA != hasSugB) return hasSugA - hasSugB;
      // Luego doubleBooking antes que coverageGap
      if (a.type != b.type) {
        return a.type == ConflictType.doubleBooking ? -1 : 1;
      }
      return 0;
    });

    return result;
  }

  // ---------------------------------------------------------------------------
  // PASO 1 – DOUBLE-BOOKING DETECTION
  // ---------------------------------------------------------------------------

  List<RichConflict> _detectDoubleBookings({
    required List<SectionSchedule> schedules,
    required List<Grade> grades,
    required List<Subject> subjects,
    required List<Teacher> teachers,
  }) {
    // teacher-id → 'day|||period' → [sectionIds]
    final teacherMap = <String, Map<String, List<String>>>{};
    for (final sched in schedules) {
      for (final slot in sched.slots) {
        teacherMap
            .putIfAbsent(slot.teacherId, () => {})
            .putIfAbsent('${slot.day}|||${slot.periodIndex}', () => [])
            .add(sched.sectionId);
      }
    }

    final legitimateKeys = _buildLegitimateKeys(subjects);
    final result = <RichConflict>[];

    for (final tEntry in teacherMap.entries) {
      final teacher = _findTeacher(teachers, tEntry.key);
      if (teacher == null) continue;

      for (final slotEntry in tEntry.value.entries) {
        final sectionIds = slotEntry.value.toSet().toList();
        if (sectionIds.length <= 1) continue;

        final parts  = slotEntry.key.split('|||');
        final day    = parts[0];
        final period = int.tryParse(parts[1]) ?? -1;

        // Bloque compartido legítimo → ignorar
        final subjectIds = _subjectIdsAt(schedules, sectionIds, day, period);
        if (subjectIds.length == 1) {
          final sorted = sectionIds.toList()..sort();
          final key    = '${sorted.join(",")}|${subjectIds.first}';
          if (legitimateKeys.contains(key)) continue;
        }

        final details = sectionIds.map((sId) {
          final sched = schedules.where((s) => s.sectionId == sId).firstOrNull;
          final slot  = sched?.getSlot(day, period);
          final subj  = slot != null
              ? subjects.where((s) => s.id == slot.subjectId).firstOrNull
              : null;
          return ConflictSlotDetail(
            sectionId: sId,
            sectionLabel: _sectionLabel(grades, sId),
            subject: subj,
            slot: slot ??
                ScheduleSlot(
                  day: day,
                  periodIndex: period,
                  subjectId: '',
                  teacherId: teacher.id,
                ),
          );
        }).toList();

        final periodLabel = _periodLabel(grades, sectionIds.first, period);
        final suggestions = _buildDoubleBookingSuggestions(
          conflict: _RawConflict(
            teacher: teacher,
            day: day,
            period: period,
            details: details,
          ),
          schedules: schedules,
          grades: grades,
          subjects: subjects,
          teachers: teachers,
        );

        result.add(RichConflict(
          type: ConflictType.doubleBooking,
          teacher: teacher,
          day: day,
          periodIndex: period,
          periodLabel: periodLabel,
          details: details,
          suggestions: suggestions,
        ));
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // PASO 2 – COVERAGE GAP DETECTION
  // ---------------------------------------------------------------------------

  List<RichConflict> _detectCoverageGaps({
    required List<SectionSchedule> schedules,
    required List<Grade> grades,
    required List<Subject> subjects,
    required List<Teacher> teachers,
  }) {
    final result = <RichConflict>[];

    for (final sched in schedules) {
      final sectionId = sched.sectionId;
      final gs = _gradeAndSectionFor(grades, sectionId);
      if (gs == null) continue;
      final (grade, section) = gs;

      for (final subj in subjects) {
        // ¿Aplica este subject a este nivel/sección?
        final levelCfg = subj.levelConfigs
            .where((c) => c.levelId == section.levelId)
            .firstOrNull;
        if (levelCfg == null) continue;

        final required = levelCfg.hoursForSection(sectionId);
        if (required <= 0) continue;

        final scheduled =
            sched.slots.where((s) => s.subjectId == subj.id).length;

        if (scheduled >= required) continue; // sin brecha

        // ── Hay una brecha → construir sugerencias ──────────────────────────
        final sectionLabel = _sectionLabel(grades, sectionId);
        final suggestions = _buildCoverageGapSuggestions(
          sectionId: sectionId,
          sectionLabel: sectionLabel,
          grade: grade,
          subject: subj,
          requiredHours: required,
          scheduledHours: scheduled,
          schedules: schedules,
          grades: grades,
          teachers: teachers,
        );

        result.add(RichConflict(
          type: ConflictType.coverageGap,
          suggestions: suggestions,
          gapSectionId: sectionId,
          gapSectionLabel: sectionLabel,
          gapSubject: subj,
          gapGrade: grade,
          requiredHours: required,
          scheduledHours: scheduled,
        ));
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // SUGERENCIAS – DOUBLE BOOKING
  // ---------------------------------------------------------------------------

  List<ConflictSuggestion> _buildDoubleBookingSuggestions({
    required _RawConflict conflict,
    required List<SectionSchedule> schedules,
    required List<Grade> grades,
    required List<Subject> subjects,
    required List<Teacher> teachers,
  }) {
    final suggestions = <ConflictSuggestion>[];

    final teacherBusy  = <String, bool>{};
    final sectionBusy  = <String, bool>{};
    for (final sched in schedules) {
      for (final s in sched.slots) {
        teacherBusy['${s.teacherId}-${s.day}-${s.periodIndex}'] = true;
        sectionBusy['${sched.sectionId}-${s.day}-${s.periodIndex}'] = true;
      }
    }

    final swapTeacherSections = <String>{};

    for (final detail in conflict.details) {
      final slot    = detail.slot;
      final section = _gradeAndSectionFor(grades, detail.sectionId);
      if (section == null) continue;

      final grade    = section.$1;
      final allSlots = _allTimeSlots(grade);

      // ── A: Mover el slot a otro hueco libre ──────────────────────────────
      for (final ts in allSlots) {
        if (ts.day == conflict.day && ts.period == conflict.period) continue;
        if (teacherBusy['${conflict.teacher.id}-${ts.day}-${ts.period}'] == true) continue;
        if (!_teacherAvailable(conflict.teacher, ts.day, ts.period)) continue;
        if (sectionBusy['${detail.sectionId}-${ts.day}-${ts.period}'] == true) continue;

        final subjName  = detail.subject?.name ?? 'Materia';
        final secLabel  = detail.sectionLabel;
        final destLabel = '${ts.day}, sesión ${ts.period + 1} '
            '(${_periodLabelFromGrade(grade, ts.period)})';
        final srcLabel  = '${conflict.day}, sesión ${conflict.period + 1}';

        suggestions.add(ConflictSuggestion(
          kind: SuggestionKind.moveSlot,
          description:
              '📅 Mover "$subjName" de $secLabel\n'
              '   De: $srcLabel → A: $destLabel',
          cost: ts.day == conflict.day ? 1 : 2,
          slotToMove: slot,
          targetDay: ts.day,
          targetPeriod: ts.period,
          sectionId: detail.sectionId,
        ));
        if (suggestions.where((s) => s.kind == SuggestionKind.moveSlot).length >= 6) break;
      }

      // ── B: Cambiar por otro maestro disponible ───────────────────────────
      if (detail.subject != null) {
        final subj = detail.subject!;
        final alternatives = teachers.where((t) {
          if (t.id == conflict.teacher.id) return false;
          if (!t.subjectIds.contains(subj.id)) return false;
          if (!t.canTeach(
              subjectId: subj.id,
              sectionId: detail.sectionId,
              gradeId: grade.id)) return false;
          if (teacherBusy['${t.id}-${conflict.day}-${conflict.period}'] == true) return false;
          if (!_teacherAvailable(t, conflict.day, conflict.period)) return false;
          return true;
        }).toList();

        for (final alt in alternatives) {
          swapTeacherSections.add(detail.sectionId);
          suggestions.add(ConflictSuggestion(
            kind: SuggestionKind.swapTeacher,
            description:
                '👤 Cambiar maestro de "${subj.name}" en ${detail.sectionLabel}\n'
                '   ${conflict.teacher.fullName} → ${alt.fullName}\n'
                '   (${conflict.day}, sesión ${conflict.period + 1})',
            cost: 3,
            slotToMove: slot,
            sectionId: detail.sectionId,
            alternativeTeacher: alt,
          ));
        }
      }
    }

    // ── C: Intercambiar dos slots del mismo maestro ──────────────────────────
    if (conflict.details.length >= 2) {
      final detailA = conflict.details[0];
      final detailB = conflict.details[1];
      final slotA   = detailA.slot;

      final schedA = schedules.where((s) => s.sectionId == detailA.sectionId).firstOrNull;
      final schedB = schedules.where((s) => s.sectionId == detailB.sectionId).firstOrNull;

      if (schedA != null && schedB != null) {
        for (final altA in schedA.slots) {
          if (altA.day == conflict.day && altA.periodIndex == conflict.period) continue;
          if (altA.teacherId != conflict.teacher.id) continue;

          final bFreeAtAltA =
              sectionBusy['${detailB.sectionId}-${altA.day}-${altA.periodIndex}'] != true;
          final teacherFreeAtAltA = schedA.getSlot(altA.day, altA.periodIndex) == null ||
              schedA.getSlot(altA.day, altA.periodIndex)?.teacherId ==
                  conflict.teacher.id;

          if (bFreeAtAltA && teacherFreeAtAltA) {
            final subjA = detailA.subject?.name ?? 'Materia';
            final subjB = detailB.subject?.name ?? 'Materia';
            suggestions.add(ConflictSuggestion(
              kind: SuggestionKind.swapSlots,
              description:
                  '🔄 Intercambiar sesiones de ${conflict.teacher.fullName}:\n'
                  '   "$subjA" (${detailA.sectionLabel}) en ${conflict.day} s.${conflict.period + 1}\n'
                  '   ↔ "$subjA" en ${altA.day} s.${altA.periodIndex + 1}\n'
                  '   Libera el espacio para "$subjB" (${detailB.sectionLabel})',
              cost: 4,
              slotA: slotA,
              slotB: altA,
              sectionIdA: detailA.sectionId,
              sectionIdB: detailA.sectionId,
            ));
            break;
          }
        }
      }
    }

    // ── D: Análisis profundo cuando no hay solución directa ──────────────────
    final dedupeKeys = <String>{};

    for (final detail in conflict.details) {
      if (detail.subject == null) continue;
      final subj = detail.subject!;
      if (swapTeacherSections.contains(detail.sectionId)) continue;

      final gs      = _gradeAndSectionFor(grades, detail.sectionId);
      final gradeId = gs?.$1.id ?? '';

      final allKnowing = teachers.where((t) {
        if (t.id == conflict.teacher.id) return false;
        return t.canTeach(
          subjectId: subj.id,
          sectionId: detail.sectionId,
          gradeId: gradeId,
        );
      }).toList();

      if (allKnowing.isEmpty) {
        final key = 'needsNew:${subj.id}:${detail.sectionId}';
        if (!dedupeKeys.contains(key)) {
          dedupeKeys.add(key);
          String horasInfo = '';
          for (final cfg in subj.levelConfigs) {
            final h = cfg.hoursForSection(detail.sectionId);
            if (h > 0) { horasInfo = ' ($h h/semana)'; break; }
          }
          suggestions.add(ConflictSuggestion(
            kind: SuggestionKind.needsNewTeacher,
            description:
                '🧑‍🏫+ Se requiere un maestro adicional para "${subj.name}"$horasInfo\n\n'
                '   ${conflict.teacher.fullName} es el ÚNICO maestro registrado '
                'que puede impartir esta materia, pero tiene conflicto de horario '
                'en ${conflict.day}, sesión ${conflict.period + 1}.\n\n'
                '   Grupos afectados: ${conflict.details.where((d) => d.subject?.id == subj.id).map((d) => d.sectionLabel).join(", ")}\n\n'
                '   ➡ Registra otro maestro con "${subj.name}" en su lista de materias '
                'y vuelve a generar los horarios.',
            cost: 5,
            subjectNeeded: subj,
            sectionId: detail.sectionId,
          ));
        }
      } else {
        for (final alt in allKnowing.take(3)) {
          final key = 'occupied:${subj.id}:${detail.sectionId}:${alt.id}';
          if (dedupeKeys.contains(key)) continue;
          dedupeKeys.add(key);

          String altOccupancyDesc = 'otra materia';
          for (final sched in schedules) {
            final s = sched.getSlot(conflict.day, conflict.period);
            if (s?.teacherId == alt.id) {
              final altSubj = subjects.where((x) => x.id == s!.subjectId).firstOrNull;
              final altSec  = _sectionLabel(grades, sched.sectionId);
              altOccupancyDesc = '"${altSubj?.name ?? "?"}" en $altSec';
              break;
            }
          }

          final isFreeElsewhere = !_teacherBusyAllWeek(alt, schedules, grades);
          suggestions.add(ConflictSuggestion(
            kind: SuggestionKind.reassignToOccupied,
            description:
                '🔃 Reasignar "${subj.name}" (${detail.sectionLabel}) a ${alt.fullName}\n\n'
                '   ${alt.fullName} conoce "${subj.name}" pero actualmente imparte '
                '$altOccupancyDesc en ese mismo periodo.\n\n'
                '${isFreeElsewhere ? "   ✅ Tiene disponibilidad en otros horarios.\n\n" : ""}'
                '   ➡ Usa el editor de horarios para liberar un slot de '
                '${alt.fullName} en ese periodo.',
            cost: 4,
            alternativeTeacher: alt,
            subjectNeeded: subj,
            sectionId: detail.sectionId,
            slotToMove: detail.slot,
          ));
        }
      }
    }

    suggestions.sort((a, b) {
      final cmp = a.cost.compareTo(b.cost);
      if (cmp != 0) return cmp;
      return a.kind.index.compareTo(b.kind.index);
    });

    return suggestions.take(12).toList();
  }

  // ---------------------------------------------------------------------------
  // SUGERENCIAS – COVERAGE GAP
  // ---------------------------------------------------------------------------

  List<ConflictSuggestion> _buildCoverageGapSuggestions({
    required String sectionId,
    required String sectionLabel,
    required Grade grade,
    required Subject subject,
    required int requiredHours,
    required int scheduledHours,
    required List<SectionSchedule> schedules,
    required List<Grade> grades,
    required List<Teacher> teachers,
  }) {
    final missing = requiredHours - scheduledHours;

    // Construir mapa de ocupación de maestros
    final teacherBusy = <String, Set<String>>{};
    for (final sched in schedules) {
      for (final s in sched.slots) {
        teacherBusy.putIfAbsent(s.teacherId, () => {}).add('${s.day}|${s.periodIndex}');
      }
    }

    // Todos los slots posibles del grado
    final allSlots = _allTimeSlots(grade);
    final totalSlotsInWeek = allSlots.length;

    // Clasificar maestros
    final freeTeachers  = <TeacherFreeTimeInfo>[];
    final busyTeachers  = <TeacherFreeTimeInfo>[];
    bool anyQualified   = false;

    for (final t in teachers) {
      if (!t.canTeach(
          subjectId: subject.id,
          sectionId: sectionId,
          gradeId: grade.id)) continue;

      anyQualified = true;
      final occupiedSlots = teacherBusy[t.id] ?? {};
      final currentLoad   = occupiedSlots.length;

      // Calcular periodos libres dentro de la disponibilidad del maestro
      final freeSlots = allSlots.where((ts) {
        if (occupiedSlots.contains('${ts.day}|${ts.period}')) return false;
        return _teacherAvailable(t, ts.day, ts.period);
      }).toList();

      final freeDays = freeSlots.map((ts) => ts.day).toSet().toList()..sort();
      final freeTotal = freeSlots.length;

      final isAssigned = t.assignments.isEmpty ||
          t.assignments.any((a) =>
              a.subjectId == subject.id &&
              (a.sectionId == sectionId ||
                  (a.sectionId == null && a.gradeId == grade.id)));

      final info = TeacherFreeTimeInfo(
        teacher: t,
        freePeriodsTotal: freeTotal,
        freeDays: freeDays,
        currentLoad: currentLoad,
        isAssignedToSection: isAssigned,
      );

      if (freeTotal >= missing) {
        freeTeachers.add(info);
      } else {
        busyTeachers.add(info);
      }
    }

    // Ordenar: más horas libres primero
    freeTeachers.sort((a, b) => b.freePeriodsTotal - a.freePeriodsTotal);
    busyTeachers.sort((a, b) => b.freePeriodsTotal - a.freePeriodsTotal);

    final suggestions = <ConflictSuggestion>[];

    if (freeTeachers.isNotEmpty) {
      // ── Caso A: Hay maestros con tiempo libre suficiente ──────────────────
      final names = freeTeachers
          .take(3)
          .map((i) => '${i.teacher.fullName} '
              '(${i.freePeriodsTotal} periodos libres — '
              '${i.freeDays.map((d) => d.substring(0, 3)).join(", ")})')
          .join('\n   • ');

      suggestions.add(ConflictSuggestion(
        kind: SuggestionKind.assignFreeTeacher,
        description:
            '✅ Maestro(s) disponible(s) para cubrir las $missing sesión(es) faltante(s) '
            'de "${subject.name}" en $sectionLabel:\n\n'
            '   • $names\n\n'
            '   ➡ Abre el editor de horarios de $sectionLabel y asigna '
            'los periodos faltantes de "${subject.name}" a uno de estos maestros.\n'
            '   También puedes re-generar los horarios; el sistema intentará '
            'asignarlos automáticamente.',
        cost: 1,
        subjectNeeded: subject,
        sectionId: sectionId,
        freeTeachers: freeTeachers,
        busyTeachers: busyTeachers,
      ));
    } else if (busyTeachers.isNotEmpty) {
      // ── Caso B: Maestros conocen la materia pero están muy ocupados ────────
      final descriptions = busyTeachers.take(3).map((i) {
        final freeDesc = i.freePeriodsTotal > 0
            ? '${i.freePeriodsTotal} periodo(s) libre(s) — '
              '${i.freeDays.map((d) => d.substring(0, 3)).join(", ")}'
            : 'sin periodos libres esta semana';
        return '${i.teacher.fullName} ($freeDesc, carga actual: ${i.currentLoad} periodos)';
      }).join('\n   • ');

      suggestions.add(ConflictSuggestion(
        kind: SuggestionKind.reassignToOccupied,
        description:
            '⚠️ Faltan $missing sesión(es) de "${subject.name}" en $sectionLabel.\n\n'
            '   Los siguientes maestros conocen la materia pero '
            'no tienen ${missing}+ periodos libres:\n\n'
            '   • $descriptions\n\n'
            '   ➡ Opciones:\n'
            '   1. Reorganiza el horario de alguno de estos maestros para '
            'liberar ${missing} periodo(s).\n'
            '   2. Amplía su disponibilidad en la pantalla de Maestros.\n'
            '   3. Reduce las horas semanales de "${subject.name}" en la configuración.',
        cost: 3,
        subjectNeeded: subject,
        sectionId: sectionId,
        freeTeachers: const [],
        busyTeachers: busyTeachers,
      ));
    } else if (!anyQualified) {
      // ── Caso C: No existe ningún maestro para esta materia/sección ─────────
      suggestions.add(ConflictSuggestion(
        kind: SuggestionKind.needsNewTeacher,
        description:
            '🧑‍🏫+ No hay ningún maestro registrado que pueda impartir '
            '"${subject.name}" en $sectionLabel.\n\n'
            '   Faltan $missing sesión(es)/semana sin cubrir.\n\n'
            '   ➡ Ve a la pantalla de Maestros y:\n'
            '   1. Registra un nuevo maestro con "${subject.name}" en su lista '
            'de materias.\n'
            '   2. Asígnalo al grado "${grade.name}" o específicamente a $sectionLabel.\n'
            '   3. Vuelve a generar los horarios.',
        cost: 5,
        subjectNeeded: subject,
        sectionId: sectionId,
      ));
    } else {
      // ── Caso D: Todos los maestros tienen availability muy restringida ──────
      suggestions.add(ConflictSuggestion(
        kind: SuggestionKind.expandAvailability,
        description:
            '📅 Faltan $missing sesión(es) de "${subject.name}" en $sectionLabel.\n\n'
            '   Hay maestros registrados para esta materia, pero sus '
            'restricciones de disponibilidad no cubren los periodos necesarios.\n\n'
            '   ➡ Ve a la pantalla de Maestros, selecciona al maestro de '
            '"${subject.name}" y amplía su disponibilidad horaria para incluir '
            'más días o periodos de la semana.',
        cost: 4,
        subjectNeeded: subject,
        sectionId: sectionId,
        busyTeachers: busyTeachers,
      ));
    }

    return suggestions;
  }

  // ---------------------------------------------------------------------------
  // APLICAR SUGERENCIA  (solo aplica a doubleBooking)
  // ---------------------------------------------------------------------------

  List<SectionSchedule>? applySuggestion({
    required ConflictSuggestion suggestion,
    required List<SectionSchedule> schedules,
  }) {
    switch (suggestion.kind) {
      case SuggestionKind.moveSlot:
        return _applyMoveSlot(suggestion, schedules);
      case SuggestionKind.swapTeacher:
        return _applySwapTeacher(suggestion, schedules);
      case SuggestionKind.swapSlots:
        return _applySwapSlots(suggestion, schedules);
      case SuggestionKind.needsNewTeacher:
      case SuggestionKind.assignFreeTeacher:
      case SuggestionKind.expandAvailability:
        // Requiere acción manual → el llamador debe navegar a la pantalla correcta.
        return null;
      case SuggestionKind.reassignToOccupied:
        return _applySwapTeacher(suggestion, schedules);
    }
  }

  List<SectionSchedule>? _applyMoveSlot(
    ConflictSuggestion s,
    List<SectionSchedule> schedules,
  ) {
    if (s.slotToMove == null || s.targetDay == null ||
        s.targetPeriod == null || s.sectionId == null) return null;

    return schedules.map((sched) {
      if (sched.sectionId != s.sectionId) return sched;
      final newSlots = sched.slots.map((slot) {
        if (slot.day == s.slotToMove!.day &&
            slot.periodIndex == s.slotToMove!.periodIndex &&
            slot.subjectId  == s.slotToMove!.subjectId &&
            slot.teacherId  == s.slotToMove!.teacherId) {
          return slot.copyWith(day: s.targetDay, periodIndex: s.targetPeriod);
        }
        return slot;
      }).toList();
      return sched.copyWith(slots: newSlots);
    }).toList();
  }

  List<SectionSchedule>? _applySwapTeacher(
    ConflictSuggestion s,
    List<SectionSchedule> schedules,
  ) {
    if (s.slotToMove == null || s.alternativeTeacher == null ||
        s.sectionId == null) return null;

    return schedules.map((sched) {
      if (sched.sectionId != s.sectionId) return sched;
      final newSlots = sched.slots.map((slot) {
        if (slot.day == s.slotToMove!.day &&
            slot.periodIndex == s.slotToMove!.periodIndex &&
            slot.subjectId  == s.slotToMove!.subjectId) {
          return slot.copyWith(teacherId: s.alternativeTeacher!.id);
        }
        return slot;
      }).toList();
      return sched.copyWith(slots: newSlots);
    }).toList();
  }

  List<SectionSchedule>? _applySwapSlots(
    ConflictSuggestion s,
    List<SectionSchedule> schedules,
  ) {
    if (s.slotA == null || s.slotB == null || s.sectionIdA == null) return null;

    return schedules.map((sched) {
      if (sched.sectionId != s.sectionIdA) return sched;
      final newSlots = sched.slots.map((slot) {
        if (slot.day == s.slotA!.day &&
            slot.periodIndex == s.slotA!.periodIndex &&
            slot.subjectId  == s.slotA!.subjectId) {
          return slot.copyWith(day: s.slotB!.day, periodIndex: s.slotB!.periodIndex);
        }
        if (slot.day == s.slotB!.day &&
            slot.periodIndex == s.slotB!.periodIndex &&
            slot.subjectId  == s.slotB!.subjectId) {
          return slot.copyWith(day: s.slotA!.day, periodIndex: s.slotA!.periodIndex);
        }
        return slot;
      }).toList();
      return sched.copyWith(slots: newSlots);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // UTILIDADES
  // ---------------------------------------------------------------------------

  Set<String> _buildLegitimateKeys(List<Subject> subjects) {
    final keys = <String>{};
    for (final subj in subjects) {
      for (final cfg in subj.levelConfigs) {
        for (final block in cfg.sharedBlocks) {
          if (block.sectionIds.length < 2) continue;
          final sorted = List<String>.from(block.sectionIds)..sort();
          keys.add('${sorted.join(",")}|${subj.id}');
        }
      }
    }
    return keys;
  }

  Set<String> _subjectIdsAt(
    List<SectionSchedule> schedules,
    List<String> sectionIds,
    String day,
    int period,
  ) {
    final ids = <String>{};
    for (final sId in sectionIds) {
      final sched = schedules.where((s) => s.sectionId == sId).firstOrNull;
      final sid   = sched?.getSlot(day, period)?.subjectId;
      if (sid != null) ids.add(sid);
    }
    return ids;
  }

  Teacher? _findTeacher(List<Teacher> teachers, String id) {
    try { return teachers.firstWhere((t) => t.id == id); } catch (_) { return null; }
  }

  String _sectionLabel(List<Grade> grades, String sectionId) {
    for (final g in grades) {
      for (final s in g.sections) {
        if (s.id == sectionId) return '${g.name} – ${s.name}';
      }
      if (g.id == sectionId) return g.name;
    }
    return sectionId;
  }

  (Grade, Section)? _gradeAndSectionFor(List<Grade> grades, String sectionId) {
    for (final g in grades) {
      for (final s in g.sections) {
        if (s.id == sectionId) return (g, s);
      }
      if (g.id == sectionId) {
        final pseudo = Section(
          id: g.id, name: g.name, gradeId: g.id, levelId: g.levelId,
        );
        return (g, pseudo);
      }
    }
    return null;
  }

  List<({String day, int period})> _allTimeSlots(Grade grade) {
    final result = <({String day, int period})>[];
    for (final day in grade.config.classDays) {
      for (int p = 0; p < grade.config.sessionsForDay(day); p++) {
        result.add((day: day, period: p));
      }
    }
    return result;
  }

  bool _teacherAvailable(Teacher teacher, String day, int period) {
    if (teacher.availability.isEmpty) return true;
    final da = teacher.availability.where((a) => a.day == day).firstOrNull;
    if (da == null) return false;
    return da.availablePeriods.contains(period);
  }

  bool _teacherBusyAllWeek(
    Teacher teacher,
    List<SectionSchedule> schedules,
    List<Grade> grades,
  ) {
    final busyKeys = <String>{};
    for (final sched in schedules) {
      for (final s in sched.slots) {
        if (s.teacherId == teacher.id) busyKeys.add('${s.day}-${s.periodIndex}');
      }
    }
    for (final g in grades) {
      for (final ts in _allTimeSlots(g)) {
        if (!busyKeys.contains('${ts.day}-${ts.period}') &&
            _teacherAvailable(teacher, ts.day, ts.period)) {
          return false;
        }
      }
    }
    return true;
  }

  String _periodLabel(List<Grade> grades, String sectionId, int period) {
    for (final g in grades) {
      final hit = g.sections.any((s) => s.id == sectionId) || g.id == sectionId;
      if (!hit) continue;
      return _periodLabelFromGrade(g, period);
    }
    return 'Sesión ${period + 1}';
  }

  String _periodLabelFromGrade(Grade grade, int period) {
    final labels = grade.config.sessionLabels;
    if (period >= 0 && period < labels.length) return labels[period];
    return 'Sesión ${period + 1}';
  }
}

// ── Estructura interna temporal ─────────────────────────────────────────────
class _RawConflict {
  final Teacher teacher;
  final String day;
  final int period;
  final List<ConflictSlotDetail> details;

  const _RawConflict({
    required this.teacher,
    required this.day,
    required this.period,
    required this.details,
  });
}