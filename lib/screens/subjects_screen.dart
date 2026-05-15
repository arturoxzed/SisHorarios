import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/entity_dialogs.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  String? _filterLevelId;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final subjects = provider.subjects
        .where((s) =>
            (_filterLevelId == null || s.levelIds.contains(_filterLevelId)) &&
            (_search.isEmpty ||
                s.name.toLowerCase().contains(_search.toLowerCase())))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Materias',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  Text('Administra las materias del sistema',
                      style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String?>(
                  value: _filterLevelId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Todos los niveles',
                    prefixIcon: Icon(Icons.filter_list, size: 18),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Todos los niveles')),
                    ...provider.levels.map((l) =>
                        DropdownMenuItem(value: l.id, child: Text(l.name))),
                  ],
                  onChanged: (v) => setState(() => _filterLevelId = v),
                ),
              ),
              SizedBox(
                width: 210,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar materia...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            tooltip: 'Limpiar',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva Materia'),
                onPressed: provider.levels.isEmpty
                    ? null
                    : () => showDialog(
                          context: context,
                          builder: (_) => const SubjectDialog(),
                        ),
              ),
            ],
          ),

          if (provider.levels.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.warning_rounded,
                        color: Colors.orange, size: 40),
                    SizedBox(height: 8),
                    Text(
                        'Primero crea niveles educativos antes de registrar materias.',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
            )
          else if (subjects.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _search.isNotEmpty
                      ? 'No se encontraron materias para "$_search".'
                      : 'No hay materias. Haz clic en "Nueva Materia" para comenzar.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  childAspectRatio: 1.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: subjects.length,
                itemBuilder: (_, i) => _SubjectCard(
                  subject: subjects[i],
                  filterLevelId: _filterLevelId,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final String? filterLevelId;
  const _SubjectCard({required this.subject, this.filterLevelId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    final teacherCount =
        provider.teachers.where((t) => t.subjectIds.contains(subject.id)).length;

    final visibleConfigs = subject.levelConfigs
        .where((c) => filterLevelId == null || c.levelId == filterLevelId)
        .toList();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showDialog(
          context: context,
          builder: (_) => SubjectDialog(existing: subject),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ──────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: subject.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subject.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton(
                    iconSize: 16,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar',
                              style: TextStyle(color: AppTheme.error))),
                    ],
                    onSelected: (v) async {
                      if (v == 'edit') {
                        showDialog(
                            context: context,
                            builder: (_) =>
                                SubjectDialog(existing: subject));
                      } else if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar Materia'),
                            content: Text('¿Eliminar "${subject.name}"?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.error),
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          context.read<AppProvider>().deleteSubject(subject.id);
                        }
                      }
                    },
                  ),
                ],
              ),

              // ── Level badges (max 3) ───────────────────────────────────
              if (visibleConfigs.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    ...visibleConfigs.take(3).map((c) {
                      final level = provider.findLevel(c.levelId);
                      final activeCount = c.sectionConfigs
                          .where((s) => s.hoursPerWeek > 0)
                          .length;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          activeCount > 0
                              ? '${level?.name ?? c.levelId} ($activeCount g.)'
                              : level?.name ?? c.levelId,
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    }),
                    if (visibleConfigs.length > 3)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${visibleConfigs.length - 3} más',
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFF94A3B8)),
                        ),
                      ),
                  ],
                ),
              ],

              const Spacer(),

              // ── Bottom chips ────────────────────────────────────────────
              Wrap(
                spacing: 5,
                runSpacing: 3,
                children: [
                  _MiniChip(subject.type.label, Icons.category_rounded),
                  _MiniChip(
                      '$teacherCount maestro${teacherCount != 1 ? 's' : ''}',
                      Icons.person_rounded),
                  if (subject.levelConfigs.length > 1)
                    _MiniChip(
                      '${subject.levelConfigs.length} niveles',
                      Icons.layers_rounded,
                    ),
                ],
              ),
              if (subject.multipleTeachers) ...[
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.group_rounded,
                        size: 12, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text('Multi-maestro',
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.primary)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MiniChip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: const Color(0xFF64748B)),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF475569))),
        ],
      ),
    );
  }
}