import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';

const _uuid = Uuid();

// ─── Color groups for the subject color picker ────────────────────────────────

class _ColorGroup {
  final String label;
  final List<Color> colors;
  const _ColorGroup(this.label, this.colors);
}

const _colorGroups = [
  _ColorGroup('Azules', [
    Color(0xFF3B82F6), Color(0xFF1D4ED8), Color(0xFF0EA5E9), Color(0xFF06B6D4),
  ]),
  _ColorGroup('Verdes', [
    Color(0xFF10B981), Color(0xFF059669), Color(0xFF84CC16), Color(0xFF4ADE80),
  ]),
  _ColorGroup('Amarillos / Naranjas', [
    Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFEA580C), Color(0xFFD97706),
  ]),
  _ColorGroup('Rojos / Rosas', [
    Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFFE11D48), Color(0xFFEC4899),
    Color(0xFFF472B6), Color(0xFFBE185D),
  ]),
  _ColorGroup('Morados', [
    Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF6366F1), Color(0xFF4F46E5),
    Color(0xFFA855F7), Color(0xFF9333EA),
  ]),
  _ColorGroup('Turquesas / Cianos', [
    Color(0xFF14B8A6), Color(0xFF0D9488), Color(0xFF22D3EE),
  ]),
  _ColorGroup('Neutros', [
    Color(0xFF92400E), Color(0xFF78716C), Color(0xFF475569),
  ]),
];

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _FormDialog extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback onSave;

  const _FormDialog({required this.title, required this.body, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              body,
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onSave,
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _field(String label, TextEditingController ctrl,
    {String? hint, int maxLines = 1}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADE DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class GradeDialog extends StatefulWidget {
  final String levelId;
  final Grade? existing;
  const GradeDialog({super.key, required this.levelId, this.existing});

  @override
  State<GradeDialog> createState() => _GradeDialogState();
}

class _GradeDialogState extends State<GradeDialog> {
  late final TextEditingController _nameCtrl;
  late GradeConfig _config;
  bool _breakEnabled = false;
  bool _fridayEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _config = widget.existing?.config ?? const GradeConfig();
    _breakEnabled = _config.hasBreak;
    _fridayEnabled = _config.fridayEarlyDismissal;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  static const _allDays = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'
  ];

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: widget.existing == null ? 'Nuevo Grado' : 'Editar Grado',
      onSave: _save,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Nombre del Grado', _nameCtrl, hint: 'Ej: 1° Grado, Kínder A'),
            const SizedBox(height: 16),

            const Text('Días de Clase',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _allDays.map((day) {
                final selected = _config.classDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      final days = List<String>.from(_config.classDays);
                      if (v) {
                        days.add(day);
                        days.sort((a, b) =>
                            _allDays.indexOf(a) - _allDays.indexOf(b));
                      } else {
                        days.remove(day);
                      }
                      _config = _config.copyWith(classDays: days);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sesiones por día',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: _config.sessionsPerDay,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: List.generate(12, (i) => i + 4).map((n) {
                          return DropdownMenuItem(
                              value: n, child: Text('$n sesiones'));
                        }).toList(),
                        onChanged: (v) => setState(
                            () => _config = _config.copyWith(sessionsPerDay: v)),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Duración (min)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: _config.sessionDurationMinutes,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: [30, 40, 45, 50, 55, 60, 90].map((n) {
                          return DropdownMenuItem(
                              value: n, child: Text('$n min'));
                        }).toList(),
                        onChanged: (v) => setState(() =>
                            _config = _config.copyWith(sessionDurationMinutes: v)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hora de inicio',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _config.startTime,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      '06:00', '06:30', '07:00', '07:30',
                      '08:00', '08:30', '09:00'
                    ]
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _config = _config.copyWith(startTime: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text('Receso',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Switch(
                  value: _breakEnabled,
                  onChanged: (v) {
                    setState(() {
                      _breakEnabled = v;
                      if (!v) {
                        _config = _config.copyWith(
                            breakStart: null, breakEnd: null);
                      } else {
                        _config = _config.copyWith(
                            breakStart: '10:00', breakEnd: '10:20');
                      }
                    });
                  },
                ),
                const SizedBox(width: 6),
                Text(_breakEnabled ? 'Activo' : 'Sin receso',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            if (_breakEnabled) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 190,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Inicio del receso',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _config.breakStart,
                          isExpanded: true,
                          decoration: const InputDecoration(),
                          items: _timeOptions()
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(
                              () => _config = _config.copyWith(breakStart: v)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fin del receso',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _config.breakEnd,
                          isExpanded: true,
                          decoration: const InputDecoration(),
                          items: _timeOptions()
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(
                              () => _config = _config.copyWith(breakEnd: v)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_config.hasBreak)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                 child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.free_breakfast_rounded,
                         size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        'Receso: ${_config.breakStart} – ${_config.breakEnd}  '
                        '(${_breakDuration(_config.breakStart!, _config.breakEnd!)} min)',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFD97706)),
                      ),
                    ],
                  ),
                ),
            ],

            // ── Friday early-dismissal ────────────────────────────────────
            const SizedBox(height: 16),
            const Text('Salida temprana los viernes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Switch(
                  value: _fridayEnabled,
                  onChanged: (v) {
                    setState(() {
                      _fridayEnabled = v;
                      _config = _config.copyWith(
                        fridayEarlyDismissal: v,
                        fridayLastSession: v
                            ? (_config.sessionsPerDay - 2).clamp(0, _config.sessionsPerDay - 1)
                            : -1,
                      );
                    });
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  _fridayEnabled ? 'Activo' : 'Sin cambio',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            if (_fridayEnabled) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  // Dismissal time
                  SizedBox(
                    width: 190,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hora de salida',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _config.fridayDismissalTime,
                          isExpanded: true,
                          decoration: const InputDecoration(),
                          items: _timeOptions()
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(() =>
                              _config = _config.copyWith(fridayDismissalTime: v)),
                        ),
                      ],
                    ),
                  ),
                  // Last session on Friday
                  SizedBox(
                    width: 190,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Última sesión del viernes',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: _config.fridayLastSession
                              .clamp(0, _config.sessionsPerDay - 1),
                          isExpanded: true,
                          decoration: const InputDecoration(),
                          items: List.generate(
                            _config.sessionsPerDay,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text('Sesión ${i + 1}'),
                            ),
                          ),
                          onChanged: (v) => setState(() =>
                              _config = _config.copyWith(fridayLastSession: v)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_rounded,
                        size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'Los viernes: ${_config.fridayLastSession + 1} sesiones, '
                      'salida a las ${_config.fridayDismissalTime}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _breakDuration(String start, String end) {
    int toMin(String t) {
      final p = t.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }
    return (toMin(end) - toMin(start)).abs();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final provider = context.read<AppProvider>();
    if (widget.existing == null) {
      provider.addGrade(Grade(
        id: _uuid.v4(),
        name: name,
        levelId: widget.levelId,
        config: _config,
      ));
    } else {
      provider.updateGrade(widget.existing!.copyWith(name: name, config: _config));
    }
    Navigator.pop(context);
  }

  static List<String> _timeOptions() {
    final opts = <String>[];
    for (int h = 6; h < 18; h++) {
      for (int m = 0; m < 60; m += 5) {
        opts.add(
            '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      }
    }
    return opts;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class SectionDialog extends StatefulWidget {
  final String gradeId;
  final String levelId;
  final Section? existing;

  const SectionDialog({
    super.key,
    required this.gradeId,
    required this.levelId,
    this.existing,
  });

  @override
  State<SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<SectionDialog> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: widget.existing == null ? 'Nuevo Grupo' : 'Editar Grupo',
      onSave: _save,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field('Nombre del Grupo', _nameCtrl,
              hint: 'Ej: A, B, Única'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '',
                    style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final provider = context.read<AppProvider>();
    if (widget.existing == null) {
      provider.addSectionToGrade(
        widget.gradeId,
        Section(
          id: _uuid.v4(),
          name: name,
          gradeId: widget.gradeId,
          levelId: widget.levelId,
        ),
      );
    } else {
      provider.updateSection(
        widget.gradeId,
        widget.existing!.copyWith(name: name),
      );
    }
    Navigator.pop(context);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBJECT DIALOG  — group-centric configuration with hybrid/shared-hours support
// ─────────────────────────────────────────────────────────────────────────────
//
// Modes:
//   • Normal (SubjectType.base)    — each group has independent hours.
//   • Especial compartido (hybrid) — each group has individual hours PLUS
//     participates in one or more shared-hours blocks with other groups.
//
// Hybrid rule:
//   totalHours(group) = individualHours + Σ sharedHours(blocks where group participates)
//
// Data model:
//   SubjectSectionConfig.hoursPerWeek         → total hours
//   SubjectSectionConfig.individualHoursPerWeek → individual portion
//   SubjectLevelConfig.sharedBlocks           → list of SharedHoursBlock

class SubjectDialog extends StatefulWidget {
  final Subject? existing;
  const SubjectDialog({super.key, this.existing});

  @override
  State<SubjectDialog> createState() => _SubjectDialogState();
}

// ── Internal state per group ──────────────────────────────────────────────────

class _GroupEntry {
  final Section section;
  bool active;
  int totalHours;
  int individualHours;
  late final TextEditingController totalCtrl;
  late final TextEditingController indivCtrl;

  _GroupEntry({
    required this.section,
    required this.active,
    required this.totalHours,
    required this.individualHours,
  }) {
    totalCtrl = TextEditingController(text: active ? '$totalHours' : '');
    // Always show the actual stored value (including 0) so the field reflects reality.
    indivCtrl = TextEditingController(text: active ? '$individualHours' : '');
  }

  void dispose() {
    totalCtrl.dispose();
    indivCtrl.dispose();
  }
}

// ── Internal state for one shared block ──────────────────────────────────────

class _SharedBlockEntry {
  String id;
  Set<String> sectionIds;
  int hours;
  late final TextEditingController hoursCtrl;

  _SharedBlockEntry({
    required this.id,
    required this.sectionIds,
    required this.hours,
  }) {
    hoursCtrl = TextEditingController(text: '$hours');
  }

  void dispose() => hoursCtrl.dispose();
}

// ── Dialog state ──────────────────────────────────────────────────────────────

class _SubjectDialogState extends State<SubjectDialog> {
  late final TextEditingController _nameCtrl;
  late SubjectType _type;
  late bool _multipleTeachers;
  late int _colorValue;

  late Set<String> _selectedLevelIds;
  late Map<String, _GroupEntry> _groupEntries;

  // Hybrid mode: shared blocks per level
  late Map<String, List<_SharedBlockEntry>> _sharedBlocksByLevel;

  String? _validationError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl         = TextEditingController(text: e?.name ?? '');
    _type             = e?.type ?? SubjectType.base;
    _multipleTeachers = e?.multipleTeachers ?? false;
    _colorValue       = e?.colorValue ?? AppTheme.subjectColors[0].value;
    _selectedLevelIds = Set<String>.from(e?.levelIds ?? []);
    _groupEntries     = {};
    _sharedBlocksByLevel = {};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppProvider>();
    _rebuildGroupEntries(provider);
    _rebuildSharedBlocks(provider);
  }

  void _rebuildGroupEntries(AppProvider provider) {
    final existing = widget.existing;
    for (final unit in provider.allSchedulableUnits) {
      if (_groupEntries.containsKey(unit.id)) continue;
      bool active = false;
      int total   = 5;
      int indiv   = 0; // default 0 so hybrid mode starts with "all shared"
      if (existing != null) {
        final lvlCfg = existing.configForLevel(unit.levelId);
        if (lvlCfg != null) {
          final secCfg = lvlCfg.sectionConfigs
              .where((c) => c.sectionId == unit.id)
              .firstOrNull;
          if (secCfg != null) {
            active = secCfg.hoursPerWeek > 0;
            total  = secCfg.hoursPerWeek > 0 ? secCfg.hoursPerWeek : 5;
            indiv  = secCfg.individualHoursPerWeek;
          }
        }
      }
      _groupEntries[unit.id] = _GroupEntry(
        section: unit,
        active: active,
        totalHours: total,
        individualHours: indiv,
      );
    }
  }

  void _rebuildSharedBlocks(AppProvider provider) {
    final existing = widget.existing;
    if (existing == null) return;
    for (final lvlCfg in existing.levelConfigs) {
      if (_sharedBlocksByLevel.containsKey(lvlCfg.levelId)) continue;
      final blocks = lvlCfg.sharedBlocks
          .map((b) => _SharedBlockEntry(
                id: b.id,
                sectionIds: Set<String>.from(b.sectionIds),
                hours: b.hoursPerWeek,
              ))
          .toList();
      _sharedBlocksByLevel[lvlCfg.levelId] = blocks;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final e in _groupEntries.values) e.dispose();
    for (final blocks in _sharedBlocksByLevel.values) {
      for (final b in blocks) b.dispose();
    }
    super.dispose();
  }

  bool get _isHybrid => _type == SubjectType.special;

  void _toggleLevel(String levelId, bool add) {
    setState(() {
      if (add) {
        _selectedLevelIds.add(levelId);
        _sharedBlocksByLevel.putIfAbsent(levelId, () => []);
      } else {
        _selectedLevelIds.remove(levelId);
      }
      _validationError = null;
    });
  }

  void _setGroupActive(String sectionId, bool active) {
    setState(() {
      final entry = _groupEntries[sectionId]!;
      entry.active = active;
      if (!active) {
        entry.totalCtrl.clear();
        entry.indivCtrl.clear();
      } else {
        if (entry.totalCtrl.text.isEmpty) entry.totalCtrl.text = '${entry.totalHours}';
        // Always restore the stored individual hours (may be 0 for pure-shared groups).
        if (entry.indivCtrl.text.isEmpty) entry.indivCtrl.text = '${entry.individualHours}';
      }
      _validationError = null;
    });
  }

  void _setGroupTotalHours(String sectionId, String raw) {
    final n = int.tryParse(raw.trim());
    if (n != null && n >= 0) _groupEntries[sectionId]!.totalHours = n;
  }

  void _setGroupIndivHours(String sectionId, String raw) {
    final n = int.tryParse(raw.trim());
    if (n != null && n >= 0) _groupEntries[sectionId]!.individualHours = n;
  }

  void _addSharedBlock(String levelId) {
    setState(() {
      _sharedBlocksByLevel.putIfAbsent(levelId, () => []);
      _sharedBlocksByLevel[levelId]!.add(_SharedBlockEntry(
        id: _uuid.v4(),
        sectionIds: {},
        hours: 1,
      ));
    });
  }

  void _removeSharedBlock(String levelId, int index) {
    setState(() {
      final b = _sharedBlocksByLevel[levelId]![index];
      b.dispose();
      _sharedBlocksByLevel[levelId]!.removeAt(index);
      _validationError = null;
    });
  }

  void _toggleSectionInBlock(String levelId, int blockIndex, String sectionId, bool add) {
    setState(() {
      final block = _sharedBlocksByLevel[levelId]![blockIndex];
      if (add) block.sectionIds.add(sectionId);
      else block.sectionIds.remove(sectionId);
      _validationError = null;
    });
  }

  String? _validate(AppProvider provider) {
    if (_nameCtrl.text.trim().isEmpty) return 'El nombre es obligatorio.';
    if (_selectedLevelIds.isEmpty) return 'Selecciona al menos un nivel.';
    if (!_isHybrid) return null;

    for (final lid in _selectedLevelIds) {
      final units = provider.allSchedulableUnits
          .where((u) => u.levelId == lid && (_groupEntries[u.id]?.active ?? false))
          .toList();
      final blocks = _sharedBlocksByLevel[lid] ?? [];

      for (int i = 0; i < blocks.length; i++) {
        final b = blocks[i];
        if (b.sectionIds.isEmpty) return 'El bloque compartido ${i + 1} no tiene grupos seleccionados.';
        if (b.sectionIds.length < 2) return 'El bloque compartido ${i + 1} debe tener al menos 2 grupos.';
        final bHours = int.tryParse(b.hoursCtrl.text.trim()) ?? b.hours;
        if (bHours <= 0) return 'El bloque compartido ${i + 1} debe tener al menos 1 hora.';
      }

      for (final unit in units) {
        final entry  = _groupEntries[unit.id]!;
        final total  = int.tryParse(entry.totalCtrl.text.trim()) ?? entry.totalHours;
        final shared = blocks
            .where((b) => b.sectionIds.contains(unit.id))
            .fold(0, (s, b) => s + (int.tryParse(b.hoursCtrl.text.trim()) ?? b.hours));
        // Only require that shared hours don't exceed the total.
        // Individual hours are derived automatically as (total − shared),
        // so users can work with only-individual, only-shared, or a mix
        // without having to manually balance three fields.
        if (shared > total) {
          final grade = provider.findGrade(entry.section.gradeId);
          final label = '${grade?.name ?? ""} ${entry.section.name}';
          return '$label: horas compartidas ($shared) superan el total ($total). '
              'Aumenta el total o reduce las horas del bloque compartido.';
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final visibleUnits = provider.allSchedulableUnits
        .where((u) => _selectedLevelIds.contains(u.levelId))
        .toList();
    final Map<String, List<Section>> byLevel = {};
    for (final u in visibleUnits) byLevel.putIfAbsent(u.levelId, () => []).add(u);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Nueva Materia' : 'Editar Materia',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Nombre de la Materia', _nameCtrl, hint: 'Ej: Matemáticas, Español'),
                      const SizedBox(height: 20),

                      // ── Level chips ────────────────────────────────────────
                      const Text('Niveles educativos',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      if (provider.levels.isEmpty)
                        const Text('No hay niveles registrados.',
                            style: TextStyle(color: Colors.orange, fontSize: 12))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: provider.levels.map((level) {
                            final selected = _selectedLevelIds.contains(level.id);
                            return FilterChip(
                              label: Text(level.name),
                              selected: selected,
                              selectedColor: AppTheme.primary.withOpacity(0.15),
                              checkmarkColor: AppTheme.primary,
                              onSelected: (v) => _toggleLevel(level.id, v),
                            );
                          }).toList(),
                        ),
                      if (_selectedLevelIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Selecciona al menos un nivel.',
                              style: TextStyle(fontSize: 11, color: Colors.red)),
                        ),
                      const SizedBox(height: 20),

                      // ── Type & multi-teacher ───────────────────────────────
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: 220,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tipo',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<SubjectType>(
                                  value: _type,
                                  isExpanded: true,
                                  decoration: const InputDecoration(),
                                  items: SubjectType.values
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _type = v ?? SubjectType.base;
                                    _validationError = null;
                                  }),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: _multipleTeachers,
                                  onChanged: (v) => setState(() => _multipleTeachers = v),
                                ),
                                const SizedBox(width: 6),
                                const Text('Multi-maestro', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // ── Hybrid info banner ─────────────────────────────────
                      if (_isHybrid) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA5B4FC)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.merge_type_rounded, size: 16, color: Color(0xFF4F46E5)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Modo híbrido: define horas individuales y bloques compartidos. '
                                  'Total = individuales + suma de compartidas en que participa.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF4338CA)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // ── Per-group table ────────────────────────────────────
                      if (_selectedLevelIds.isNotEmpty) ...[
                        Row(
                          children: const [
                            Icon(Icons.group_work_rounded, size: 15, color: AppTheme.primary),
                            SizedBox(width: 6),
                            Text('Configuración por grupo',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (visibleUnits.isEmpty)
                          _warningBox('Los niveles seleccionados no tienen grupos creados todavía.')
                        else
                          _buildGroupTable(provider, byLevel, visibleUnits),
                        const SizedBox(height: 8),

                        // ── Shared blocks (hybrid only) ──────────────────────
                        if (_isHybrid && visibleUnits.isNotEmpty)
                          ..._selectedLevelIds.map((lid) {
                            final activeUnits = visibleUnits
                                .where((u) => u.levelId == lid && (_groupEntries[u.id]?.active ?? false))
                                .toList();
                            if (activeUnits.isEmpty) return const SizedBox.shrink();
                            final level  = provider.findLevel(lid);
                            final blocks = _sharedBlocksByLevel[lid] ?? [];
                            return _SharedBlocksSection(
                              levelName: level?.name ?? lid,
                              levelId: lid,
                              activeUnits: activeUnits,
                              blocks: blocks,
                              provider: provider,
                              onAdd: () => _addSharedBlock(lid),
                              onRemove: (i) => _removeSharedBlock(lid, i),
                              onToggleSection: (blockIdx, secId, add) =>
                                  _toggleSectionInBlock(lid, blockIdx, secId, add),
                              onHoursChanged: (blockIdx, raw) => setState(() {
                                final n = int.tryParse(raw.trim());
                                if (n != null && n > 0) blocks[blockIdx].hours = n;
                              }),
                            );
                          }),

                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: visibleUnits
                              .where((u) => _groupEntries[u.id]?.active == true)
                              .map((u) {
                            final grade = provider.findGrade(u.gradeId);
                            final e = _groupEntries[u.id]!;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${grade?.name ?? ""} ${u.name}: ${e.totalHours}h',
                                style: const TextStyle(fontSize: 10, color: AppTheme.primary),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Color picker ───────────────────────────────────────
                      Row(
                        children: [
                          const Text('Color',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          // Preview chip of selected color
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Color(_colorValue),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26, width: 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _colorGroups.map((group) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(group.label,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5)),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 7,
                                    children: group.colors.map((c) {
                                      final selected = _colorValue == c.value;
                                      return GestureDetector(
                                        onTap: () => setState(() => _colorValue = c.value),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: c,
                                            shape: BoxShape.circle,
                                            border: selected
                                                ? Border.all(color: Colors.black54, width: 2.5)
                                                : Border.all(color: Colors.transparent, width: 2.5),
                                            boxShadow: selected
                                                ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)]
                                                : null,
                                          ),
                                          child: selected
                                              ? const Icon(Icons.check, color: Colors.white, size: 15)
                                              : null,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // ── Validation error ───────────────────────────────────
                      if (_validationError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.error.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_validationError!,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.error)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupTable(
    AppProvider provider,
    Map<String, List<Section>> byLevel,
    List<Section> visibleUnits,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 42),
                const Expanded(
                  flex: 4,
                  child: Text('Grupo',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(_isHybrid ? 'Total h/sem' : 'Horas/sem',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                      textAlign: TextAlign.center),
                ),
                if (_isHybrid) ...[
                  const SizedBox(width: 8),
                  const Expanded(
                    flex: 2,
                    child: Text('Individuales',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                        textAlign: TextAlign.center),
                  ),
                ],
              ],
            ),
          ),
          ...byLevel.entries.expand((levelEntry) {
            final lid   = levelEntry.key;
            final units = levelEntry.value;
            final level = provider.findLevel(lid);
            return [
              if (byLevel.length > 1)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  color: AppTheme.primary.withOpacity(0.04),
                  child: Text(level?.name ?? lid,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5)),
                ),
              ...units.map((unit) {
                final grade = provider.findGrade(unit.gradeId);
                final label = '${grade?.name ?? ""} — ${unit.name}';
                final entry = _groupEntries[unit.id]!;
                return _GroupRow(
                  label: label,
                  entry: entry,
                  isHybrid: _isHybrid,
                  onActiveChanged: (v) => _setGroupActive(unit.id, v),
                  onTotalHoursChanged: (v) => _setGroupTotalHours(unit.id, v),
                  onIndivHoursChanged: (v) => _setGroupIndivHours(unit.id, v),
                );
              }),
            ];
          }),
        ],
      ),
    );
  }

  void _save() {
    final provider = context.read<AppProvider>();
    final err = _validate(provider);
    if (err != null) {
      setState(() => _validationError = err);
      return;
    }

    final levelConfigs = <SubjectLevelConfig>[];
    for (final lid in _selectedLevelIds) {
      final units = provider.allSchedulableUnits.where((u) => u.levelId == lid).toList();
      final sectionConfigs = <SubjectSectionConfig>[];
      for (final unit in units) {
        final entry = _groupEntries[unit.id];
        if (entry == null || !entry.active) continue;
        final total = int.tryParse(entry.totalCtrl.text.trim()) ?? entry.totalHours;
        if (total <= 0) continue;

        // Derive individual hours automatically so the user doesn't have to
        // keep three fields in sync manually.  Priority:
        //   1. Non-hybrid subjects → all hours are individual.
        //   2. Hybrid subjects    → individual = total − (sum of shared blocks
        //      covering this section), clamped to [0, total].
        final int indiv;
        if (!_isHybrid) {
          indiv = total;
        } else {
          final sharedForUnit = (_sharedBlocksByLevel[lid] ?? [])
              .where((b) => b.sectionIds.contains(unit.id))
              .fold(0, (s, b) => s + (int.tryParse(b.hoursCtrl.text.trim()) ?? b.hours));
          indiv = (total - sharedForUnit).clamp(0, total);
        }

        sectionConfigs.add(SubjectSectionConfig(
          sectionId: unit.id,
          hoursPerWeek: total,
          sessionPeriods: 1,
          individualHoursPerWeek: indiv,
        ));
      }

      final sharedBlocks = <SharedHoursBlock>[];
      if (_isHybrid) {
        for (final b in _sharedBlocksByLevel[lid] ?? []) {
          final h = int.tryParse(b.hoursCtrl.text.trim()) ?? b.hours;
          if (b.sectionIds.length >= 2 && h > 0) {
            sharedBlocks.add(SharedHoursBlock(
              id: b.id,
              sectionIds: b.sectionIds.toList(),
              hoursPerWeek: h,
            ));
          }
        }
      }

      levelConfigs.add(SubjectLevelConfig(
        levelId: lid,
        hoursPerWeek: 0,
        sessionPeriods: 1,
        sectionConfigs: sectionConfigs,
        sharedBlocks: sharedBlocks,
      ));
    }

    final subject = Subject(
      id: widget.existing?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      levelConfigs: levelConfigs,
      type: _type,
      multipleTeachers: _multipleTeachers,
      colorValue: _colorValue,
    );

    if (widget.existing == null) {
      provider.addSubject(subject);
    } else {
      provider.updateSubject(subject);
    }
    Navigator.pop(context);
  }

  Widget _warningBox(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: const TextStyle(fontSize: 12, color: Color(0xFFD97706))),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP ROW  — one row in the per-group table
// ─────────────────────────────────────────────────────────────────────────────

class _GroupRow extends StatefulWidget {
  final String label;
  final _GroupEntry entry;
  final bool isHybrid;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<String> onTotalHoursChanged;
  final ValueChanged<String> onIndivHoursChanged;

  const _GroupRow({
    required this.label,
    required this.entry,
    required this.isHybrid,
    required this.onActiveChanged,
    required this.onTotalHoursChanged,
    required this.onIndivHoursChanged,
  });

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  @override
  Widget build(BuildContext context) {
    final active = widget.entry.active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary.withOpacity(0.04) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Checkbox(
              value: active,
              activeColor: AppTheme.primary,
              onChanged: (v) {
                setState(() {});
                widget.onActiveChanged(v ?? false);
              },
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active ? AppTheme.primary : const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _hoursField(widget.entry.totalCtrl, active, widget.onTotalHoursChanged)),
          if (widget.isHybrid) ...[
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _hoursField(widget.entry.indivCtrl, active, widget.onIndivHoursChanged)),
          ],
        ],
      ),
    );
  }

  Widget _hoursField(TextEditingController ctrl, bool active, ValueChanged<String> onChanged) {
    return TextField(
      controller: ctrl,
      enabled: active,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: active ? AppTheme.primary : const Color(0xFFCBD5E1),
        fontWeight: active ? FontWeight.w700 : FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: '—',
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        filled: true,
        fillColor: active ? Colors.white : const Color(0xFFF1F5F9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
      onChanged: (v) {
        setState(() {});
        onChanged(v);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED BLOCKS SECTION  — hybrid mode shared-hours editor per level
// ─────────────────────────────────────────────────────────────────────────────

class _SharedBlocksSection extends StatelessWidget {
  final String levelName;
  final String levelId;
  final List<Section> activeUnits;
  final List<_SharedBlockEntry> blocks;
  final AppProvider provider;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int blockIdx, String sectionId, bool add) onToggleSection;
  final void Function(int blockIdx, String raw) onHoursChanged;

  const _SharedBlocksSection({
    required this.levelName,
    required this.levelId,
    required this.activeUnits,
    required this.blocks,
    required this.provider,
    required this.onAdd,
    required this.onRemove,
    required this.onToggleSection,
    required this.onHoursChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFEDE9FE),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.merge_type_rounded, size: 16, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bloques compartidos — $levelName',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5B21B6)),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 14, color: Color(0xFF7C3AED)),
                  label: const Text('Agregar bloque',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED))),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          if (blocks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Sin bloques compartidos. Haz clic en "Agregar bloque" para crear uno.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6D28D9)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: List.generate(blocks.length, (i) => _SharedBlockCard(
                  index: i,
                  block: blocks[i],
                  activeUnits: activeUnits,
                  provider: provider,
                  onRemove: () => onRemove(i),
                  onToggleSection: (secId, add) => onToggleSection(i, secId, add),
                  onHoursChanged: (raw) => onHoursChanged(i, raw),
                )),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED BLOCK CARD  — editor for one shared block
// ─────────────────────────────────────────────────────────────────────────────

class _SharedBlockCard extends StatelessWidget {
  final int index;
  final _SharedBlockEntry block;
  final List<Section> activeUnits;
  final AppProvider provider;
  final VoidCallback onRemove;
  final void Function(String sectionId, bool add) onToggleSection;
  final ValueChanged<String> onHoursChanged;

  const _SharedBlockCard({
    required this.index,
    required this.block,
    required this.activeUnits,
    required this.provider,
    required this.onRemove,
    required this.onToggleSection,
    required this.onHoursChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Bloque compartido',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5B21B6))),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.error),
                onPressed: onRemove,
                tooltip: 'Eliminar bloque',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Grupos que comparten:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: activeUnits.map((unit) {
              final grade    = provider.findGrade(unit.gradeId);
              final label    = '${grade?.name ?? ""} ${unit.name}';
              final selected = block.sectionIds.contains(unit.id);
              return FilterChip(
                label: Text(label, style: const TextStyle(fontSize: 11)),
                selected: selected,
                selectedColor: const Color(0xFFEDE9FE),
                checkmarkColor: const Color(0xFF7C3AED),
                side: BorderSide(
                    color: selected ? const Color(0xFF7C3AED) : const Color(0xFFDDD6FE)),
                onSelected: (v) => onToggleSection(unit.id, v),
              );
            }).toList(),
          ),
          if (block.sectionIds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Selecciona al menos 2 grupos.',
                  style: TextStyle(fontSize: 10, color: AppTheme.error)),
            )
          else if (block.sectionIds.length == 1)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Selecciona al menos 1 grupo más.',
                  style: TextStyle(fontSize: 10, color: AppTheme.warning)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Horas compartidas:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: block.hoursCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: const Color(0xFFF5F3FF),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFDDD6FE)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                    ),
                  ),
                  onChanged: onHoursChanged,
                ),
              ),
              const SizedBox(width: 8),
              const Text('h/sem', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
          if (block.sectionIds.length >= 2) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${block.sectionIds.length} grupos × ${block.hoursCtrl.text.trim()} h/sem compartidas',
                style: const TextStyle(fontSize: 10, color: Color(0xFF5B21B6)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class LevelDialog extends StatefulWidget {
  final EducationalLevel? existing;
  const LevelDialog({super.key, this.existing});

  @override
  State<LevelDialog> createState() => _LevelDialogState();
}

class _LevelDialogState extends State<LevelDialog> {
  late final TextEditingController _nameCtrl;
  late LevelType _type;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _type     = widget.existing?.type ?? LevelType.primaria;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: widget.existing == null ? 'Nuevo Nivel' : 'Editar Nivel',
      onSave: _save,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field('Nombre del Nivel', _nameCtrl,
              hint: 'Ej: Primaria, Secundaria'),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tipo de Nivel',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<LevelType>(
                value: _type,
                decoration: const InputDecoration(),
                items: LevelType.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _type = v ?? LevelType.primaria),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final provider = context.read<AppProvider>();
    final level = EducationalLevel(
      id: widget.existing?.id ?? _uuid.v4(),
      name: name,
      type: _type,
    );
    if (widget.existing == null) {
      provider.addLevel(level);
    } else {
      provider.updateLevel(level);
    }
    Navigator.pop(context);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEACHER DIALOG
// ─────────────────────────────────────────────────────────────────────────────
//
// The "Asignaciones" tab lets the user specify, per subject + grade (required)
// + section (optional):
//
//   • Grade-wide assignment  → teacher teaches the subject to ALL sections of
//     that grade. Represented as TeacherSubjectAssignment with sectionId=null.
//
//   • Section-specific assignment → teacher teaches the subject only to that
//     one section.  Takes priority over a grade-wide assignment during
//     schedule generation.
//
// A teacher with NO assignments is unrestricted and can be used for any group.
//
// Conflict rules (enforced on save):
//   • Cannot have both a grade-wide and a section-specific assignment for the
//     same (subjectId, gradeId) pair — the section-specific one already implies
//     the grade, so it would be redundant/confusing.
//   • The section must belong to the grade selected.
//   • Duplicate assignments (same subjectId + gradeId + sectionId) are rejected.

class TeacherDialog extends StatefulWidget {
  final Teacher? existing;
  const TeacherDialog({super.key, this.existing});

  @override
  State<TeacherDialog> createState() => _TeacherDialogState();
}

class _TeacherDialogState extends State<TeacherDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastNameCtrl;
  late List<String> _subjectIds;
  late List<TeacherSubjectAssignment> _assignments;
  late List<DayAvailability> _availability;
  late TabController _tabCtrl;

  // State for the "add assignment" inline form.
  String? _newSubjectId;
  String? _newGradeId;
  String? _newSectionId; // null = grade-wide
  String? _assignmentError;

  static const _allDays = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl     = TextEditingController(text: e?.name ?? '');
    _lastNameCtrl = TextEditingController(text: e?.lastName ?? '');
    _subjectIds   = List<String>.from(e?.subjectIds ?? []);
    _assignments  = List<TeacherSubjectAssignment>.from(e?.assignments ?? []);
    _availability = List<DayAvailability>.from(e?.availability ?? []);
    _tabCtrl      = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  DayAvailability? _getDayAvail(String day) {
    try { return _availability.firstWhere((a) => a.day == day); } catch (_) { return null; }
  }

  /// Validates and adds the current "new assignment" fields.
  String? _tryAddAssignment(AppProvider provider) {
    if (_newSubjectId == null) return 'Selecciona una materia.';
    if (_newGradeId == null) return 'Selecciona un grado.';

    // Validate section belongs to grade.
    if (_newSectionId != null) {
      final grade = provider.findGrade(_newGradeId!);
      if (grade != null && !grade.sections.any((s) => s.id == _newSectionId)) {
        return 'El grupo seleccionado no pertenece al grado.';
      }
    }

    final candidate = TeacherSubjectAssignment(
      subjectId: _newSubjectId!,
      gradeId: _newGradeId!,
      sectionId: _newSectionId,
    );

    // Duplicate check.
    if (_assignments.contains(candidate)) {
      return 'Esta asignación ya existe.';
    }

    // Conflict: grade-wide exists and you are adding a section-specific one
    // for the same (subject, grade) pair.
    if (_newSectionId != null) {
      final hasGradeWide = _assignments.any((a) =>
          a.subjectId == _newSubjectId &&
          a.gradeId == _newGradeId &&
          a.sectionId == null);
      if (hasGradeWide) {
        return 'Ya existe una asignación para todo el grado. '
            'Elimínala antes de agregar una asignación por grupo.';
      }
    } else {
      // Adding grade-wide: reject if any section-specific assignment already
      // exists for this (subject, grade) pair.
      final hasSpecific = _assignments.any((a) =>
          a.subjectId == _newSubjectId &&
          a.gradeId == _newGradeId &&
          a.sectionId != null);
      if (hasSpecific) {
        return 'Ya existen asignaciones por grupo para este grado. '
            'Elimínalas o cambia a asignación por grado completo.';
      }
    }

    setState(() {
      _assignments.add(candidate);
      _newSubjectId = null;
      _newGradeId   = null;
      _newSectionId = null;
      _assignmentError = null;
    });
    return null;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Nuevo Maestro' : 'Editar Maestro',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(width: 220, child: _field('Nombre', _nameCtrl, hint: 'Nombre(s)')),
                  SizedBox(width: 220, child: _field('Apellido(s)', _lastNameCtrl, hint: 'Apellido(s)')),
                ],
              ),
              const SizedBox(height: 16),

              TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'Materias'),
                  Tab(text: 'Asignaciones'),
                  Tab(text: 'Disponibilidad'),
                ],
              ),
              const SizedBox(height: 8),

              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // ── Tab 0: Subjects ──────────────────────────────────
                    _buildSubjectsTab(provider),

                    // ── Tab 1: Assignments ───────────────────────────────
                    _buildAssignmentsTab(provider),

                    // ── Tab 2: Availability ──────────────────────────────
                    _buildAvailabilityTab(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _save, child: const Text('Guardar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 0: Subjects ───────────────────────────────────────────────────────

  Widget _buildSubjectsTab(AppProvider provider) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'Selecciona las materias que imparte este maestro. '
              'Cada materia puede tener distintas horas según el nivel.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: provider.subjects.map((s) {
              final sel = _subjectIds.contains(s.id);
              final levelHints = s.levelConfigs
                  .map((c) {
                    final lvl = provider.findLevel(c.levelId);
                    return '${lvl?.name ?? c.levelId}: ${c.hoursPerWeek}h';
                  })
                  .join(' · ');
              return FilterChip(
                label: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.name, style: const TextStyle(fontSize: 12)),
                    if (s.levelConfigs.length > 1)
                      Text(levelHints,
                          style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
                selected: sel,
                selectedColor: s.color.withOpacity(0.2),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _subjectIds.add(s.id);
                    } else {
                      _subjectIds.remove(s.id);
                      // Remove assignments for this subject when de-selecting.
                      _assignments.removeWhere((a) => a.subjectId == s.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Assignments ────────────────────────────────────────────────────

  Widget _buildAssignmentsTab(AppProvider provider) {
    final relevantSubjects = provider.subjects
        .where((s) => _subjectIds.contains(s.id))
        .toList();

    // Sections available for the selected grade in the "add" form.
    final gradeForNew = _newGradeId != null ? provider.findGrade(_newGradeId!) : null;
    final sectionsForNew = gradeForNew?.sections ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Info banner ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin asignaciones: el maestro está disponible para todos los grupos.\n'
                    'Con asignaciones: define por grado (todo el grado) o por grupo '
                    '(solo ese grupo). El grupo tiene prioridad sobre el grado.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Add assignment form ─────────────────────────────────────────
          if (relevantSubjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_rounded, size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Primero asigna materias en la pestaña "Materias".',
                      style: TextStyle(fontSize: 11, color: Color(0xFFD97706)),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            const Text('Nueva asignación',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            // Subject dropdown
            DropdownButtonFormField<String>(
              value: _newSubjectId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Materia *',
                prefixIcon: Icon(Icons.menu_book_rounded, size: 16),
                isDense: true,
              ),
              items: relevantSubjects
                  .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() {
                _newSubjectId = v;
                _newGradeId   = null;
                _newSectionId = null;
                _assignmentError = null;
              }),
            ),
            const SizedBox(height: 8),

            // Grade dropdown — filtered to grades that have this subject.
            DropdownButtonFormField<String>(
              value: _newGradeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Grado *',
                prefixIcon: Icon(Icons.layers_rounded, size: 16),
                isDense: true,
              ),
              items: [
                if (_newSubjectId != null)
                  ...provider.grades
                      .where((g) {
                        final subj = provider.findSubject(_newSubjectId!);
                        return subj != null && subj.levelIds.contains(g.levelId);
                      })
                      .map((g) {
                        final level = provider.findLevel(g.levelId);
                        return DropdownMenuItem(
                          value: g.id,
                          child: Text('${level?.name ?? ''} › ${g.name}'),
                        );
                      }),
              ],
              onChanged: (v) => setState(() {
                _newGradeId   = v;
                _newSectionId = null;
                _assignmentError = null;
              }),
            ),
            const SizedBox(height: 8),

            // Section dropdown — optional (null = grade-wide).
            DropdownButtonFormField<String?>(
              value: _newSectionId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Grupo (opcional)',
                prefixIcon: Icon(Icons.group_work_rounded, size: 16),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todo el grado'),
                ),
                ...sectionsForNew.map((s) =>
                    DropdownMenuItem(value: s.id, child: Text(s.name))),
              ],
              onChanged: _newGradeId == null
                  ? null
                  : (v) => setState(() {
                        _newSectionId = v;
                        _assignmentError = null;
                      }),
            ),
            const SizedBox(height: 8),

            if (_assignmentError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(_assignmentError!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.error)),
              ),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar'),
                onPressed: () {
                  final err = _tryAddAssignment(provider);
                  if (err != null) setState(() => _assignmentError = err);
                },
              ),
            ),
          ],

          // ── Existing assignments list ───────────────────────────────────
          if (_assignments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            Text('Asignaciones (${_assignments.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            ..._assignments.map((a) => _AssignmentChip(
                  assignment: a,
                  provider: provider,
                  onDelete: () => setState(() => _assignments.remove(a)),
                )),
          ] else if (relevantSubjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Sin asignaciones — disponible para todos los grupos.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Availability ───────────────────────────────────────────────────

  Widget _buildAvailabilityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deja en blanco para disponibilidad total.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ..._allDays.map((day) {
            final dayAvail = _getDayAvail(day);
            final allAvail = dayAvail == null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: !allAvail,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _availability.removeWhere((a) => a.day == day);
                            _availability.add(DayAvailability(
                              day: day,
                              availablePeriods: List.generate(8, (i) => i),
                            ));
                          } else {
                            _availability.removeWhere((a) => a.day == day);
                          }
                        });
                      },
                    ),
                    Text(day, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                if (!allAvail)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      children: List.generate(8, (p) {
                        final av = dayAvail.availablePeriods.contains(p);
                        return FilterChip(
                          label: Text('S${p + 1}',
                              style: const TextStyle(fontSize: 11)),
                          selected: av,
                          onSelected: (v) {
                            setState(() {
                              final periods =
                                  List<int>.from(dayAvail.availablePeriods);
                              if (v) periods.add(p); else periods.remove(p);
                              _availability[_availability
                                      .indexWhere((a) => a.day == day)] =
                                  DayAvailability(
                                      day: day, availablePeriods: periods);
                            });
                          },
                        );
                      }),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final provider = context.read<AppProvider>();
    final teacher = Teacher(
      id: widget.existing?.id ?? _uuid.v4(),
      name: name,
      lastName: _lastNameCtrl.text.trim(),
      subjectIds: _subjectIds,
      assignments: _assignments,
      availability: _availability, sectionIds: [],
    );
    if (widget.existing == null) {
      provider.addTeacher(teacher);
    } else {
      provider.updateTeacher(teacher);
    }
    Navigator.pop(context);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ASSIGNMENT CHIP  — displays one TeacherSubjectAssignment with a delete button
// ─────────────────────────────────────────────────────────────────────────────

class _AssignmentChip extends StatelessWidget {
  final TeacherSubjectAssignment assignment;
  final AppProvider provider;
  final VoidCallback onDelete;

  const _AssignmentChip({
    required this.assignment,
    required this.provider,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subject = provider.findSubject(assignment.subjectId);
    final grade   = provider.findGrade(assignment.gradeId);
    final level   = grade != null ? provider.findLevel(grade.levelId) : null;

    String scopeLabel;
    if (assignment.sectionId == null) {
      scopeLabel = 'Todo el grado';
    } else {
      final section = provider.findSection(assignment.sectionId!);
      scopeLabel = 'Grupo: ${section?.name ?? assignment.sectionId}';
    }

    final subjectColor = subject?.color ?? AppTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: subjectColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: subjectColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: subjectColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject?.name ?? assignment.subjectId,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  '${level?.name ?? ''} › ${grade?.name ?? assignment.gradeId}  ·  $scopeLabel',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          // Badge: grade-wide vs section-specific
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: assignment.isGradeWide
                  ? AppTheme.primary.withOpacity(0.12)
                  : AppTheme.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              assignment.isGradeWide ? 'Grado completo' : 'Por grupo',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: assignment.isGradeWide ? AppTheme.primary : AppTheme.success,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.error),
            onPressed: onDelete,
            tooltip: 'Eliminar asignación',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }
}