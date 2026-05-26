import 'package:flutter/material.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULE TABLE WIDGET
// ─────────────────────────────────────────────────────────────────────────────
//
// The break is rendered as a dedicated full-width row between regular sessions.
// It is NOT treated as a session slot and never occupies a periodIndex.
// The position of the break row is determined by GradeConfig.breakAfterSession.

class ScheduleTableWidget extends StatelessWidget {
  final SectionSchedule schedule;
  final Grade grade;
  final List<Subject> subjects;
  final List<Teacher> teachers;
  final bool compact;

  /// Optional callback that returns a group/section label for a given
  /// (day, periodIndex) slot.  Used by the teacher view to show which group
  /// the teacher has in each cell.
  final String? Function(String day, int periodIndex)? slotSectionLabel;

  final void Function(String day, int sessionIndex, ScheduleSlot? current)?
      onSlotTap;

  const ScheduleTableWidget({
    super.key,
    required this.schedule,
    required this.grade,
    required this.subjects,
    required this.teachers,
    this.compact = false,
    this.slotSectionLabel,
    this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final config   = grade.config;
    final days     = config.classDays;
    // Usar el máximo de sesiones entre todos los días.
    // Si el viernes tiene salida anticipada (ej. 7 sesiones) y los demás
    // días tienen 8, se generan 8 filas y la celda del viernes en la fila 8
    // muestra _DisabledCell.  Pero si ningún día llega a 8 (viernes
    // incluido), esa fila simplemente no existe.
    final sessions = days.fold<int>(0, (m, d) {
      final s = config.sessionsForDay(d);
      return s > m ? s : m;
    });
    final labels   = config.sessionLabels;

    Subject? findSubject(String id) {
      try { return subjects.firstWhere((s) => s.id == id); } catch (_) { return null; }
    }

    Teacher? findTeacher(String id) {
      try { return teachers.firstWhere((t) => t.id == id); } catch (_) { return null; }
    }

    final cellW = compact ? 120.0 : 150.0;
    final cellH = compact ? 72.0  : 88.0;
    final timeW = compact ? 120.0 : 140.0;
    // Break row is shorter — just enough to show the time range
    final breakH = compact ? 34.0  : 38.0;

    // Determine where the break row goes (after which session index).
    // -1 means no break; value >= sessions means break is after all rows.
    final breakAfter = config.hasBreak ? config.breakAfterSession : -1;

    // Build the ordered list of "row descriptors".
    // Each entry is either an int (session index) or the string 'break'.
    final List<dynamic> rows = [];
    for (int p = 0; p < sessions; p++) {
      rows.add(p);
      if (p == breakAfter) rows.add('break');
    }
    // If breakAfter == -1 or >= sessions the break row was not inserted above.
    // breakAfter == -1 → no break configured (skip).
    // breakAfter >= sessions → insert after last session.
    if (breakAfter >= sessions) rows.add('break');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Row(
              children: [
                _HeaderCell(text: 'Sesión / Día', width: timeW, height: 36),
                ...days.map((d) => _HeaderCell(text: d, width: cellW, height: 36)),
              ],
            ),

            // ── Session + break rows ──────────────────────────────────────
            ...rows.map((row) {
              // ── Break row ──────────────────────────────────────────────
              if (row == 'break') {
                final label = '${config.breakStart} – ${config.breakEnd}';
                return Row(
                  children: [
                    // Time label
                    Container(
                      width: timeW,
                      height: breakH,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF7ED),
                        border: Border(
                          top:    BorderSide(color: Color(0xFFFED7AA)),
                          bottom: BorderSide(color: Color(0xFFFED7AA)),
                          left:   BorderSide(color: Color(0xFFFED7AA)),
                          right:  BorderSide(color: Color(0xFFFED7AA)),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          /*const Icon(Icons.free_breakfast_rounded,
                              size: 12, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),*/
                          Flexible(
                            child: Text(
                              'RECESO  $label',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFD97706),
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // One break cell per day
                    ...days.map((_) => Container(
                          width: cellW,
                          height: breakH,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            border: Border.all(color: const Color(0xFFFED7AA)),
                          ),
                          child: const Center(
                            child: Text('Receso',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFD97706),
                                    fontWeight: FontWeight.w600)),
                          ),
                        )),
                  ],
                );
              }

              // ── Regular session row ─────────────────────────────────────
              final int p = row as int;

              return Row(
                children: [
                  // Time label
                  Container(
                    width: timeW,
                    height: cellH,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        top:    BorderSide(color: Color(0xFFE2E8F0)),
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        left:   BorderSide(color: Color(0xFFE2E8F0)),
                        right:  BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'S ${p + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          labels[p],
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),

                  // Day cells
                  ...days.map((day) {
                    // If this period exceeds the number of sessions for this
                    // day (e.g. Friday early dismissal), show a grayed-out
                    // "no-class" cell instead of a normal slot.
                    final daySessions = config.sessionsForDay(day);
                    if (p >= daySessions) {
                      return _DisabledCell(width: cellW, height: cellH);
                    }

                    final slot = schedule.getSlot(day, p);
                    final sub  = slot != null ? findSubject(slot.subjectId) : null;
                    final tea  = slot != null ? findTeacher(slot.teacherId) : null;
                    final groupLabel = slot != null
                        ? slotSectionLabel?.call(day, p)
                        : null;

                    final cellWidget = slot == null
                        ? _EmptyCell(width: cellW, height: cellH)
                        : _SubjectCell(
                            subject: sub,
                            teacher: tea,
                            groupLabel: groupLabel,
                            width: cellW,
                            height: cellH,
                            compact: compact,
                          );

                    if (onSlotTap == null) return cellWidget;

                    return InkWell(
                      onTap: () => onSlotTap!(day, p, slot),
                      child: cellWidget,
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL CELLS
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final double height;

  const _HeaderCell(
      {required this.text, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E40AF),
        border: Border.all(color: const Color(0xFF1E3A8A)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  final double width;
  final double height;
  const _EmptyCell({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Text('—',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 18)),
      ),
    );
  }
}

/// Shown for periods that fall outside the allowed sessions for a given day
/// (e.g. Friday early-dismissal slots).
class _DisabledCell extends StatelessWidget {
  final double width;
  final double height;
  const _DisabledCell({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Icon(Icons.block_rounded, color: Color(0xFFCBD5E1), size: 16),
      ),
    );
  }
}

class _SubjectCell extends StatelessWidget {
  final Subject? subject;
  final Teacher? teacher;
  final String? groupLabel;
  final double width;
  final double height;
  final bool compact;

  const _SubjectCell({
    required this.subject,
    required this.teacher,
    this.groupLabel,
    required this.width,
    required this.height,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final color     = subject?.color ?? const Color(0xFF94A3B8);
    final textColor = _contrastColor(color);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject?.name ?? 'Sin materia',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 10 : 11,
            ),
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          // Teacher name
          if (teacher != null) ...[
            const SizedBox(height: 2),
            Text(
              teacher!.fullName,
              style: TextStyle(
                color: textColor.withOpacity(0.85),
                fontSize: compact ? 8 : 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Group label (shown in teacher view)
          if (groupLabel != null) ...[
            const SizedBox(height: 1),
            Text(
              groupLabel!,
              style: TextStyle(
                color: textColor.withOpacity(0.75),
                fontSize: compact ? 7 : 8,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Color _contrastColor(Color bg) =>
      bg.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBJECT LEGEND
// ─────────────────────────────────────────────────────────────────────────────

class SubjectLegend extends StatelessWidget {
  final List<Subject> subjects;
  const SubjectLegend({super.key, required this.subjects});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: subjects.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: s.color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            s.name,
            style: TextStyle(
              color: s.color.computeLuminance() > 0.4
                  ? Colors.black87
                  : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}