import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/import_export_dialog.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final current = provider.currentScreen;

    return Container(
      width: 230,
      color: AppTheme.sidebarBg,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
          // Logo / Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Horarios\nEscolares',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sistema de Gestión',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // Nav items
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            screen: AppScreen.dashboard,
            current: current,
            onTap: () => provider.navigate(AppScreen.dashboard),
          ),

          _SectionLabel('Configuración'),

          _NavItem(
            icon: Icons.account_tree_rounded,
            label: 'Niveles y Grados',
            screen: AppScreen.levels,
            current: current,
            onTap: () => provider.navigate(AppScreen.levels),
          ),
          _NavItem(
            icon: Icons.menu_book_rounded,
            label: 'Materias',
            screen: AppScreen.subjects,
            current: current,
            onTap: () => provider.navigate(AppScreen.subjects),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Maestros',
            screen: AppScreen.teachers,
            current: current,
            onTap: () => provider.navigate(AppScreen.teachers),
          ),

          _SectionLabel('Horarios'),

          _NavItem(
            icon: Icons.auto_fix_high_rounded,
            label: 'Generación',
            screen: AppScreen.schedules,
            current: current,
            onTap: () => provider.navigate(AppScreen.schedules),
          ),
          _NavItem(
            icon: Icons.grid_view_rounded,
            label: 'Visualización',
            screen: AppScreen.visualization,
            current: current,
            onTap: () => provider.navigate(AppScreen.visualization),
          ),
          _NavItem(
            icon: Icons.build_circle_rounded,
            label: 'Resolver Conflictos',
            screen: AppScreen.conflictResolution,
            current: current,
            onTap: () => provider.navigate(AppScreen.conflictResolution),
          ),

          const SizedBox(height: 16),

          // ── Stats footer ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Consumer<AppProvider>(
              builder: (_, p, __) {
                final s = p.stats;
                return Column(
                  children: [
                    _StatRow('Secciones', '${s['sections']}'),
                    _StatRow('Materias', '${s['subjects']}'),
                    _StatRow('Maestros', '${s['teachers']}'),
                    _StatRow('Horarios', '${s['schedules']}'),
                  ],
                );
              },
            ),
          ),

          // ── Import / Export button ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _SidebarActionButton(
              icon: Icons.import_export_rounded,
              label: 'Importar / Exportar',
              onTap: () => ImportExportDialog.show(context),
            ),
          ),

          // ── Clear all data button ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _SidebarActionButton(
              icon: Icons.delete_sweep_rounded,
              label: 'Borrar configuración',
              danger: true,
              onTap: () => _ClearDataDialog.show(context),
            ),
          ),
          ],
        ),
      ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppScreen screen;
  final AppScreen current;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.screen,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = screen == current;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.55)),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.6),
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13.5,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Botón de acción reutilizable (footer del sidebar) ────────────────────────

class _SidebarActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SidebarActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = danger
        ? const Color(0xFFEF4444)   // rojo suave sobre fondo oscuro
        : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: danger
              ? const Color(0xFFEF4444).withOpacity(0.10)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: danger
                ? const Color(0xFFEF4444).withOpacity(0.35)
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: baseColor.withOpacity(0.75)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: baseColor.withOpacity(0.75),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Diálogo de confirmación para borrar toda la configuración ─────────────────

class _ClearDataDialog extends StatefulWidget {
  const _ClearDataDialog();

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ClearDataDialog(),
      );

  @override
  State<_ClearDataDialog> createState() => _ClearDataDialogState();
}

class _ClearDataDialogState extends State<_ClearDataDialog> {
  bool _confirmed = false; // checkbox de doble confirmación
  bool _busy = false;

  Future<void> _doClear() async {
    setState(() => _busy = true);
    await context.read<AppProvider>().clearAllData();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
          SizedBox(width: 8),
          Text('Borrar configuración',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Advertencia ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.25)),
              ),
              child: const Text(
                'Esta acción eliminará permanentemente toda la información '
                'almacenada en la aplicación:',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),

            // ── Lista de lo que se borrará ─────────────────────────────────
            _BulletItem('Niveles educativos, grados y grupos'),
            _BulletItem('Materias y sus configuraciones por nivel'),
            _BulletItem('Maestros, asignaciones y disponibilidad'),
            _BulletItem('Horarios generados'),

            const SizedBox(height: 16),

            // ── Checkbox de doble confirmación ─────────────────────────────
            InkWell(
              onTap: _busy
                  ? null
                  : () => setState(() => _confirmed = !_confirmed),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _confirmed,
                      activeColor: const Color(0xFFEF4444),
                      onChanged: _busy
                          ? null
                          : (v) =>
                              setState(() => _confirmed = v ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'Entiendo que esta acción no se puede deshacer.',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.delete_forever_rounded, size: 18),
          label: Text(_busy ? 'Borrando...' : 'Borrar todo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                const Color(0xFFEF4444).withOpacity(0.45),
          ),
          onPressed: (_confirmed && !_busy) ? _doClear : null,
        ),
      ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 8),
            child: Icon(Icons.circle, size: 6, color: Color(0xFFEF4444)),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}