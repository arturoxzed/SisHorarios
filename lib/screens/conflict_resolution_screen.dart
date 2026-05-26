import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/conflict_resolver.dart';
import '../theme/app_theme.dart'; 

// =============================================================================
// PANTALLA PRINCIPAL
// =============================================================================

class ConflictResolutionScreen extends StatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  final _resolver = ConflictResolverService();
  List<RichConflict> _conflicts = [];
  int? _selectedIndex;
  bool _applying = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  void _analyze() {
    final p = context.read<AppProvider>();
    final conflicts = _resolver.analyze(
      schedules: p.schedules,
      grades: p.grades,
      subjects: p.subjects,
      teachers: p.teachers,
    );
    setState(() {
      _conflicts = conflicts;
      _selectedIndex = conflicts.isNotEmpty ? 0 : null;
      _statusMessage = null;
    });
  }

  Future<void> _applySuggestion(ConflictSuggestion suggestion) async {
    // Sugerencias que no se aplican automáticamente → navegar a la pantalla correcta.
    if (suggestion.kind == SuggestionKind.needsNewTeacher ||
        suggestion.kind == SuggestionKind.expandAvailability) {
      context.read<AppProvider>().navigate(AppScreen.teachers);
      return;
    }
    if (suggestion.kind == SuggestionKind.assignFreeTeacher) {
      context.read<AppProvider>().navigate(AppScreen.schedules);
      return;
    }

    final p = context.read<AppProvider>();
    setState(() {
      _applying = true;
      _statusMessage = null;
    });

    try {
      final updated = _resolver.applySuggestion(
        suggestion: suggestion,
        schedules: p.schedules,
      );

      if (updated == null) {
        setState(() {
          _statusIsError = true;
          _statusMessage =
              'No se pudo aplicar la sugerencia. Verifica que el horario no haya cambiado.';
        });
        return;
      }

      await p.replaceSchedules(updated);

      final newConflicts = _resolver.analyze(
        schedules: updated,
        grades: p.grades,
        subjects: p.subjects,
        teachers: p.teachers,
      );

      final resolved = _conflicts.length - newConflicts.length;

      setState(() {
        _conflicts = newConflicts;
        _selectedIndex = newConflicts.isNotEmpty ? 0 : null;
        _statusIsError = false;
        if (suggestion.kind == SuggestionKind.reassignToOccupied) {
          _statusMessage = resolved > 0
              ? '✅ Reasignación aplicada. Revisa si aparecieron nuevos conflictos en el horario de '
                '${suggestion.alternativeTeacher?.fullName ?? "el maestro"}.'
              : '⚠️ Reasignación aplicada. Es posible que se haya creado un nuevo conflicto — revisa la lista.';
        } else {
          _statusMessage = resolved > 0
              ? '✅ Sugerencia aplicada. Se resolvió $resolved conflicto(s).'
              : '⚠️ Sugerencia aplicada pero el conflicto persiste. Intenta con otra opción.';
        }
      });
    } catch (e) {
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Error al aplicar: $e';
      });
    } finally {
      setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doubleBookings =
        _conflicts.where((c) => c.type == ConflictType.doubleBooking).length;
    final coverageGaps =
        _conflicts.where((c) => c.type == ConflictType.coverageGap).length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          _Header(
            doubleBookings: doubleBookings,
            coverageGaps: coverageGaps,
            onRefresh: _analyze,
          ),

          // ── Status banner ────────────────────────────────────────────────
          if (_statusMessage != null)
            _StatusBanner(
              message: _statusMessage!,
              isError: _statusIsError,
              onDismiss: () => setState(() => _statusMessage = null),
            ),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: _conflicts.isEmpty
                ? const _AllClearState()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Panel izquierdo – lista de conflictos
                      _ConflictList(
                        conflicts: _conflicts,
                        selectedIndex: _selectedIndex,
                        onSelect: (i) => setState(() => _selectedIndex = i),
                      ),

                      // Panel derecho – detalle + sugerencias
                      Expanded(
                        child: _selectedIndex != null
                            ? _ConflictDetail(
                                conflict: _conflicts[_selectedIndex!],
                                applying: _applying,
                                onApply: _applySuggestion,
                              )
                            : const Center(
                                child: Text(
                                  'Selecciona un conflicto para ver sugerencias',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================

class _Header extends StatelessWidget {
  final int doubleBookings;
  final int coverageGaps;
  final VoidCallback onRefresh;

  const _Header({
    required this.doubleBookings,
    required this.coverageGaps,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final total = doubleBookings + coverageGaps;
    String subtitle;
    if (total == 0) {
      subtitle = 'Sin conflictos detectados';
    } else {
      final parts = <String>[];
      if (doubleBookings > 0) parts.add('$doubleBookings choque(s) de maestro');
      if (coverageGaps > 0)   parts.add('$coverageGaps materia(s) sin cubrir');
      subtitle = '${parts.join(' · ')} — selecciona uno para ver sugerencias';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Volver',
            onPressed: () =>
                context.read<AppProvider>().navigate(AppScreen.schedules),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resolución de Conflictos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(subtitle,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),
          // Badge counters
          if (doubleBookings > 0) ...[
            _CountBadge(
              label: '$doubleBookings choque${doubleBookings > 1 ? "s" : ""}',
              color: AppTheme.error,
              icon: Icons.person_off_rounded,
            ),
            const SizedBox(width: 8),
          ],
          if (coverageGaps > 0) ...[
            _CountBadge(
              label: '$coverageGaps sin cubrir',
              color: AppTheme.warning,
              icon: Icons.event_busy_rounded,
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Re-analizar'),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _CountBadge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// =============================================================================
// STATUS BANNER
// =============================================================================

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _StatusBanner({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.error : AppTheme.success;
    return Container(
      color: color.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: color, fontSize: 13))),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 16, color: color),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LISTA DE CONFLICTOS  (panel izquierdo)
// =============================================================================

class _ConflictList extends StatelessWidget {
  final List<RichConflict> conflicts;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const _ConflictList({
    required this.conflicts,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Sub-header counts
          _ListHeader(conflicts: conflicts),
          Expanded(
            child: ListView.builder(
              itemCount: conflicts.length,
              itemBuilder: (_, i) => _ConflictListItem(
                conflict: conflicts[i],
                index: i,
                isSelected: selectedIndex == i,
                onTap: () => onSelect(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  final List<RichConflict> conflicts;
  const _ListHeader({required this.conflicts});

  @override
  Widget build(BuildContext context) {
    final db = conflicts.where((c) => c.type == ConflictType.doubleBooking).length;
    final cg = conflicts.where((c) => c.type == ConflictType.coverageGap).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          if (db > 0) _MiniTag(label: '$db choque${db>1?"s":""}',
              color: AppTheme.error),
          if (db > 0 && cg > 0) const SizedBox(width: 6),
          if (cg > 0) _MiniTag(label: '$cg sin cubrir',
              color: AppTheme.warning),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ConflictListItem extends StatelessWidget {
  final RichConflict conflict;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConflictListItem({
    required this.conflict,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGap = conflict.type == ConflictType.coverageGap;

    final Color typeColor = isGap ? AppTheme.warning : AppTheme.error;
    final IconData typeIcon =
        isGap ? Icons.event_busy_rounded : Icons.person_off_rounded;

    // Title and subtitle differ by type
    String title;
    String subtitle;
    String? badge;
    Color badgeColor = typeColor;

    if (isGap) {
      title    = conflict.gapSubject?.name ?? 'Materia desconocida';
      subtitle = conflict.gapSectionLabel ?? '';
      final miss = conflict.missingHours;
      badge    = '-$miss sesión${miss>1?"es":""}';
    } else {
      title    = conflict.teacher?.fullName ?? 'Maestro';
      subtitle = '${conflict.day}, sesión ${conflict.periodIndex + 1}';
      badge    = '${conflict.details.length} grupos';
    }

    final hasSuggestions = conflict.hasSuggestions;
    final Color suggestionDot =
        hasSuggestions ? AppTheme.success : const Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: isSelected
            ? AppTheme.primary.withOpacity(0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(typeIcon, size: 15, color: typeColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 13,
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(badge!,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: badgeColor)),
                ),
                const SizedBox(height: 4),
                // Suggestions dot
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: suggestionDot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      hasSuggestions ? 'con sugerencias' : 'sin solución rápida',
                      style: TextStyle(fontSize: 9, color: suggestionDot),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DETALLE DEL CONFLICTO  (panel derecho)
// =============================================================================

class _ConflictDetail extends StatelessWidget {
  final RichConflict conflict;
  final bool applying;
  final Future<void> Function(ConflictSuggestion) onApply;

  const _ConflictDetail({
    required this.conflict,
    required this.applying,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return conflict.type == ConflictType.coverageGap
        ? _CoverageGapDetail(
            conflict: conflict, applying: applying, onApply: onApply)
        : _DoubleBookingDetail(
            conflict: conflict, applying: applying, onApply: onApply);
  }
}

// =============================================================================
// DETALLE – DOUBLE BOOKING
// =============================================================================

class _DoubleBookingDetail extends StatelessWidget {
  final RichConflict conflict;
  final bool applying;
  final Future<void> Function(ConflictSuggestion) onApply;

  const _DoubleBookingDetail({
    required this.conflict,
    required this.applying,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título ──────────────────────────────────────────────────────
          _SectionHeader(icon: Icons.person_off_rounded, label: 'Choque de maestro'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      conflict.teacher?.fullName ?? '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF7F1D1D)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: Color(0xFF991B1B)),
                    const SizedBox(width: 6),
                    Text(
                      '${conflict.day}  ·  ${conflict.periodLabel}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF991B1B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Grupos en conflicto ──────────────────────────────────────────
          _SectionHeader(
              icon: Icons.groups_rounded, label: 'Grupos afectados'),
          const SizedBox(height: 8),
          ...conflict.details.map((d) => _DetailSlotRow(detail: d)),

          const SizedBox(height: 20),

          // ── Sugerencias ──────────────────────────────────────────────────
          _SectionHeader(
              icon: Icons.lightbulb_rounded, label: 'Sugerencias de solución'),
          const SizedBox(height: 10),
          if (conflict.suggestions.isEmpty)
            _NoSuggestionsCard(conflict: conflict)
          else
            ...conflict.suggestions.asMap().entries.map(
                  (e) => _SuggestionCard(
                    index: e.key,
                    suggestion: e.value,
                    applying: applying,
                    onApply: () => onApply(e.value),
                  ),
                ),
        ],
      ),
    );
  }
}

class _DetailSlotRow extends StatelessWidget {
  final ConflictSlotDetail detail;
  const _DetailSlotRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          if (detail.subject != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: detail.subject!.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail.sectionLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                if (detail.subject != null)
                  Text(detail.subject!.name,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DETALLE – COVERAGE GAP
// =============================================================================

class _CoverageGapDetail extends StatelessWidget {
  final RichConflict conflict;
  final bool applying;
  final Future<void> Function(ConflictSuggestion) onApply;

  const _CoverageGapDetail({
    required this.conflict,
    required this.applying,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final subject = conflict.gapSubject;
    final missing = conflict.missingHours;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título ──────────────────────────────────────────────────────
          _SectionHeader(
              icon: Icons.event_busy_rounded, label: 'Materia sin cubrir completamente'),
          const SizedBox(height: 12),

          // ── Resumen de la brecha ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                if (subject != null) ...[
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        color: subject.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject?.name ?? 'Materia desconocida',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conflict.gapSectionLabel ?? '',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF78350F)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Barra de progreso de horas ───────────────────────────────────
          _HoursProgressBar(
            required: conflict.requiredHours,
            scheduled: conflict.scheduledHours,
          ),
          const SizedBox(height: 20),

          // ── Análisis de disponibilidad de maestros ───────────────────────
          if (conflict.suggestions.isNotEmpty) ...[
            _SectionHeader(
                icon: Icons.manage_accounts_rounded,
                label: 'Análisis de disponibilidad'),
            const SizedBox(height: 10),
            _TeacherAvailabilityPanel(
                suggestion: conflict.suggestions.first,
                missingHours: missing),
            const SizedBox(height: 20),
          ],

          // ── Sugerencias ──────────────────────────────────────────────────
          _SectionHeader(
              icon: Icons.lightbulb_rounded, label: 'Qué hacer'),
          const SizedBox(height: 10),
          if (conflict.suggestions.isEmpty)
            _NoSuggestionsCard(conflict: conflict)
          else
            ...conflict.suggestions.asMap().entries.map(
                  (e) => _SuggestionCard(
                    index: e.key,
                    suggestion: e.value,
                    applying: applying,
                    onApply: () => onApply(e.value),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Barra de progreso de horas ────────────────────────────────────────────────

class _HoursProgressBar extends StatelessWidget {
  final int required;
  final int scheduled;
  const _HoursProgressBar({required this.required, required this.scheduled});

  @override
  Widget build(BuildContext context) {
    final missing  = required - scheduled;
    final fraction = required > 0 ? scheduled / required : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sesiones programadas',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Text('$scheduled / $required',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: const Color(0xFFFEE2E2),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 13, color: AppTheme.warning),
            const SizedBox(width: 4),
            Text(
              'Faltan $missing sesión${missing > 1 ? "es" : ""} por asignar esta semana',
              style: const TextStyle(fontSize: 11, color: AppTheme.warning),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Panel de disponibilidad de maestros ───────────────────────────────────────

class _TeacherAvailabilityPanel extends StatelessWidget {
  final ConflictSuggestion suggestion;
  final int missingHours;

  const _TeacherAvailabilityPanel({
    required this.suggestion,
    required this.missingHours,
  });

  @override
  Widget build(BuildContext context) {
    final free = suggestion.freeTeachers;
    final busy = suggestion.busyTeachers;

    if (free.isEmpty && busy.isEmpty) {
      return const _EmptyTeachersCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (free.isNotEmpty) ...[
          // ── Maestros con tiempo libre suficiente ──────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  'Maestros disponibles (tienen $missingHours+ periodos libres)',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success),
                ),
              ],
            ),
          ),
          ...free.map((info) => _TeacherAvailabilityRow(
                info: info,
                available: true,
                missingHours: missingHours,
              )),
          if (busy.isNotEmpty) const SizedBox(height: 12),
        ],
        if (busy.isNotEmpty) ...[
          // ── Maestros con tiempo insuficiente ─────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.warning, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Maestros que conocen la materia pero tienen poco tiempo libre',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning),
                ),
              ],
            ),
          ),
          ...busy.map((info) => _TeacherAvailabilityRow(
                info: info,
                available: false,
                missingHours: missingHours,
              )),
        ],
      ],
    );
  }
}

class _TeacherAvailabilityRow extends StatelessWidget {
  final TeacherFreeTimeInfo info;
  final bool available;
  final int missingHours;

  const _TeacherAvailabilityRow({
    required this.info,
    required this.available,
    required this.missingHours,
  });

  @override
  Widget build(BuildContext context) {
    final color = available ? AppTheme.success : AppTheme.warning;
    final bgColor = available
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFFFBEB);
    final borderColor = available
        ? const Color(0xFFBBF7D0)
        : const Color(0xFFFDE68A);

    final freeDaysShort =
        info.freeDays.map((d) => d.substring(0, 3)).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Avatar initials
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                info.teacher.name.isNotEmpty
                    ? '${info.teacher.name[0]}${info.teacher.lastName.isNotEmpty ? info.teacher.lastName[0] : ""}'
                        .toUpperCase()
                    : '?',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(info.teacher.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (!info.isAssignedToSection) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('sin asignación',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  info.freePeriodsTotal > 0
                      ? '${info.freePeriodsTotal} periodo${info.freePeriodsTotal > 1 ? "s" : ""} libre${info.freePeriodsTotal > 1 ? "s" : ""}'
                        '  ·  ${freeDaysShort.isNotEmpty ? freeDaysShort : "—"}'
                        '  ·  Carga actual: ${info.currentLoad} periodos'
                      : 'Sin periodos libres esta semana  ·  Carga actual: ${info.currentLoad} periodos',
                  style: TextStyle(
                      fontSize: 10,
                      color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          // Free slots indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              available ? '✓ libre' : '~ parcial',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTeachersCard extends StatelessWidget {
  const _EmptyTeachersCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_off_rounded, color: AppTheme.error, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No hay maestros registrados para esta materia en este grupo.',
              style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TARJETA DE SUGERENCIA
// =============================================================================

class _SuggestionCard extends StatelessWidget {
  final int index;
  final ConflictSuggestion suggestion;
  final bool applying;
  final VoidCallback onApply;

  const _SuggestionCard({
    required this.index,
    required this.suggestion,
    required this.applying,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, textColor, badgeColor, badgeLabel, canAutoApply) =
        _styleForKind(suggestion.kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestion.description,
                  style: TextStyle(
                      fontSize: 12, color: textColor, height: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badgeLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          // Action button
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: applying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : _ActionButton(
                    kind: suggestion.kind,
                    canAutoApply: canAutoApply,
                    onApply: onApply,
                  ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color, Color, String, bool) _styleForKind(SuggestionKind k) {
    switch (k) {
      case SuggestionKind.moveSlot:
      case SuggestionKind.swapSlots:
        return (
          const Color(0xFFEFF6FF),
          const Color(0xFFBFDBFE),
          const Color(0xFF1E40AF),
          AppTheme.primary,
          'Auto',
          true,
        );
      case SuggestionKind.swapTeacher:
        return (
          const Color(0xFFF0FDF4),
          const Color(0xFFBBF7D0),
          const Color(0xFF14532D),
          AppTheme.success,
          'Auto',
          true,
        );
      case SuggestionKind.assignFreeTeacher:
        return (
          const Color(0xFFF0FDF4),
          const Color(0xFFBBF7D0),
          const Color(0xFF14532D),
          AppTheme.success,
          'Manual',
          false,
        );
      case SuggestionKind.reassignToOccupied:
        return (
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
          const Color(0xFF78350F),
          AppTheme.warning,
          'Manual',
          true, // can "apply" (force swap), but with warning
        );
      case SuggestionKind.expandAvailability:
        return (
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
          const Color(0xFF78350F),
          AppTheme.warning,
          'Config.',
          false,
        );
      case SuggestionKind.needsNewTeacher:
        return (
          const Color(0xFFFEF2F2),
          const Color(0xFFFECACA),
          const Color(0xFF7F1D1D),
          AppTheme.error,
          'Acción requerida',
          false,
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final SuggestionKind kind;
  final bool canAutoApply;
  final VoidCallback onApply;

  const _ActionButton({
    required this.kind,
    required this.canAutoApply,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case SuggestionKind.needsNewTeacher:
      case SuggestionKind.expandAvailability:
        return OutlinedButton.icon(
          icon: const Icon(Icons.person_rounded, size: 14),
          label: const Text('Ir a Maestros', style: TextStyle(fontSize: 12)),
          onPressed: onApply,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: const BorderSide(color: AppTheme.error),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        );
      case SuggestionKind.assignFreeTeacher:
        return OutlinedButton.icon(
          icon: const Icon(Icons.edit_calendar_rounded, size: 14),
          label: const Text('Ir a Generación / Editor',
              style: TextStyle(fontSize: 12)),
          onPressed: onApply,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.success,
            side: const BorderSide(color: AppTheme.success),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        );
      default:
        return ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 14),
          label: Text(
              kind == SuggestionKind.reassignToOccupied
                  ? 'Forzar reasignación'
                  : 'Aplicar automáticamente',
              style: const TextStyle(fontSize: 12)),
          onPressed: onApply,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        );
    }
  }
}

// =============================================================================
// NO SUGGESTIONS CARD
// =============================================================================

class _NoSuggestionsCard extends StatelessWidget {
  final RichConflict conflict;
  const _NoSuggestionsCard({required this.conflict});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_rounded, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 8),
              Text('No hay sugerencias automáticas disponibles',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Acciones manuales recomendadas:',
              style: TextStyle(fontSize: 12, color: Color(0xFF78350F))),
          const SizedBox(height: 8),
          _ManualHint(
            icon: Icons.person_add_rounded,
            text: 'Registra otro maestro para '
                '${conflict.type == ConflictType.coverageGap ? '"${conflict.gapSubject?.name ?? "esta materia"}"' : 'las materias en conflicto'}.',
          ),
          _ManualHint(
            icon: Icons.schedule_rounded,
            text: conflict.type == ConflictType.coverageGap
                ? 'Amplía la disponibilidad horaria del maestro de esta materia.'
                : 'Amplía la disponibilidad de "${conflict.teacher?.fullName ?? "el maestro"}".',
          ),
          _ManualHint(
            icon: Icons.tune_rounded,
            text: 'Reduce las horas semanales de alguna materia para liberar espacios.',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_rounded, size: 16),
            label: const Text('Ir a Maestros'),
            onPressed: () =>
                context.read<AppProvider>().navigate(AppScreen.teachers),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD97706),
              side: const BorderSide(color: Color(0xFFF59E0B)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ManualHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFD97706)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF78350F), height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ALL-CLEAR STATE
// =============================================================================

class _AllClearState extends StatelessWidget {
  const _AllClearState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppTheme.success, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Sin conflictos!',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.success),
          ),
          const SizedBox(height: 8),
          const Text(
            'Todos los horarios están correctamente configurados.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.grid_view_rounded, size: 16),
            label: const Text('Ver horarios'),
            onPressed: () => context
                .read<AppProvider>()
                .navigate(AppScreen.visualization),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}