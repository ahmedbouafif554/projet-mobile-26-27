import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'app_card.dart';
import 'app_search_field.dart';
import 'app_snackbar.dart';
import 'async_value_view.dart';
import 'confirm_delete_dialog.dart';
import 'empty_state.dart';
import 'shimmer_box.dart';

/// Colonne d'un [AppDataTable].
class AppTableColumn<T> {
  const AppTableColumn({
    required this.label,
    required this.cell,
    this.sortValue,
    this.flex = 2,
    this.numeric = false,
    this.primary = false,
  });

  final String label;
  final Widget Function(BuildContext context, T item) cell;

  /// Valeur de tri ; sans elle, la colonne n'est pas triable.
  final Comparable<Object?> Function(T item)? sortValue;

  /// Largeur relative de la colonne.
  final int flex;

  /// Aligne à droite (montants, quantités).
  final bool numeric;

  /// Colonne principale : titre de la carte sur petit écran.
  final bool primary;
}

/// Filtre en liste déroulante (« Rôle : Client »).
class AppTableFilter<T> {
  const AppTableFilter({
    required this.label,
    required this.options,
    required this.test,
    this.icon = Icons.filter_list_rounded,
  });

  final String label;

  /// Valeur → libellé.
  final Map<String, String> options;
  final bool Function(T item, String value) test;
  final IconData icon;
}

/// Action supplémentaire d'une ligne (menu « ⋮ »).
class AppTableAction<T> {
  const AppTableAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.isVisible,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final void Function(T item) onSelected;
  final bool Function(T item)? isVisible;
  final bool isDestructive;
}

/// Tableau générique du back office (et des listes du front office) :
/// recherche, filtres, tri, pagination, actions par ligne, chargement en
/// shimmer, état vide animé et affichage en cartes sur petit écran.
///
/// ```dart
/// AppDataTable<User>(
///   items: users.value,           // null pendant le chargement
///   isLoading: users.isLoading,
///   searchText: (u) => '${u.fullName} ${u.email}',
///   columns: [AppTableColumn(label: 'Nom', primary: true, ...)],
///   onEdit: (u) => ..., onDelete: (u) => repository.delete(u.id),
/// )
/// ```
class AppDataTable<T> extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.items,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.searchText,
    this.searchHint = 'Rechercher…',
    this.filters = const [],
    this.toolbarActions = const [],
    this.onView,
    this.onEdit,
    this.onDelete,
    this.deleteMessage,
    this.actions = const [],
    this.rowsPerPageOptions = const [10, 25, 50],
    this.emptyTitle = 'Aucun résultat',
    this.emptyMessage = 'Modifiez la recherche ou les filtres.',
    this.initialSortColumn,
    this.initialSortAscending = true,
  });

  final List<AppTableColumn<T>> columns;

  /// Données ; `null` pendant le premier chargement.
  final List<T>? items;
  final bool isLoading;
  final Object? error;
  final VoidCallback? onRetry;

  /// Texte dans lequel chercher ; sans lui, pas de champ de recherche.
  final String Function(T item)? searchText;
  final String searchHint;
  final List<AppTableFilter<T>> filters;

  /// Boutons à droite de la barre d'outils (« Exporter »…).
  final List<Widget> toolbarActions;

  final void Function(T item)? onView;
  final void Function(T item)? onEdit;

  /// Suppression, après confirmation automatique.
  final Future<void> Function(T item)? onDelete;
  final String Function(T item)? deleteMessage;
  final List<AppTableAction<T>> actions;

  final List<int> rowsPerPageOptions;
  final String emptyTitle;
  final String emptyMessage;
  final int? initialSortColumn;
  final bool initialSortAscending;

  @override
  State<AppDataTable<T>> createState() => _AppDataTableState<T>();
}

class _AppDataTableState<T> extends State<AppDataTable<T>> {
  String _query = '';
  late final List<String?> _filterValues = List.filled(
    widget.filters.length,
    null,
  );
  late int? _sortColumn = widget.initialSortColumn;
  late bool _ascending = widget.initialSortAscending;
  int _page = 0;
  late int _rowsPerPage = widget.rowsPerPageOptions.first;

  bool get _hasRowActions =>
      widget.onView != null ||
      widget.onEdit != null ||
      widget.onDelete != null ||
      widget.actions.isNotEmpty;

  /// Données après recherche, filtres et tri.
  List<T> get _visible {
    final query = _query.toLowerCase();
    final result = (widget.items ?? const []).where((item) {
      if (query.isNotEmpty &&
          !(widget.searchText?.call(item).toLowerCase().contains(query) ??
              true)) {
        return false;
      }
      for (final (i, filter) in widget.filters.indexed) {
        final value = _filterValues[i];
        if (value != null && !filter.test(item, value)) return false;
      }
      return true;
    }).toList();

    final sortValue = _sortColumn == null
        ? null
        : widget.columns[_sortColumn!].sortValue;
    if (sortValue != null) {
      result.sort((a, b) {
        final compared = _compare(sortValue(a), sortValue(b));
        return _ascending ? compared : -compared;
      });
    }
    return result;
  }

  static int _compare(Comparable<Object?> a, Comparable<Object?> b) =>
      a is String && b is String
      ? a.toLowerCase().compareTo(b.toLowerCase())
      : a.compareTo(b);

  void _search(String query) => setState(() {
    _query = query;
    _page = 0;
  });

  void _filter(int index, String? value) => setState(() {
    _filterValues[index] = value;
    _page = 0;
  });

  void _sortBy(int column) => setState(() {
    if (_sortColumn == column) {
      _ascending = !_ascending;
    } else {
      _sortColumn = column;
      _ascending = true;
    }
  });

  Future<void> _delete(T item) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      message:
          widget.deleteMessage?.call(item) ??
          'Cette action est définitive et ne peut pas être annulée.',
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.onDelete!(item);
      if (mounted) AppSnackbar.success(context, 'Élément supprimé');
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final pageCount = (visible.length / _rowsPerPage).ceil().clamp(1, 9999);
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _rowsPerPage;
    final rows = visible.skip(start).take(_rowsPerPage).toList();

    final Widget body;
    if (widget.items == null && widget.isLoading) {
      body = const _LoadingRows();
    } else if (widget.error != null && widget.items == null) {
      body = ErrorView(message: '${widget.error}', onRetry: widget.onRetry);
    } else if (rows.isEmpty) {
      body = EmptyState(
        compact: true,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 720
            ? _Table<T>(
                table: this,
                rows: rows,
                pageKey: '$page-$_rowsPerPage-$_query',
              )
            : _Cards<T>(
                table: this,
                rows: rows,
                pageKey: '$page-$_rowsPerPage-$_query',
              ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Toolbar<T>(table: this),
          const Divider(height: 1),
          AnimatedSize(
            duration: AppDurations.medium,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: body,
          ),
          if (rows.isNotEmpty) ...[
            const Divider(height: 1),
            _Pagination(
              start: start,
              shown: rows.length,
              total: visible.length,
              page: page,
              pageCount: pageCount,
              rowsPerPage: _rowsPerPage,
              options: widget.rowsPerPageOptions,
              onPage: (p) => setState(() => _page = p),
              onRowsPerPage: (n) => setState(() {
                _rowsPerPage = n;
                _page = 0;
              }),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Barre d'outils : recherche, filtres, actions
// -----------------------------------------------------------------------------
class _Toolbar<T> extends StatelessWidget {
  const _Toolbar({required this.table});

  final _AppDataTableState<T> table;

  @override
  Widget build(BuildContext context) {
    final widget = table.widget;
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Wrap(
        spacing: AppSizes.sm,
        runSpacing: AppSizes.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (widget.searchText != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: AppSearchField(
                hint: widget.searchHint,
                dense: true,
                onChanged: table._search,
              ),
            ),
          for (final (i, filter) in widget.filters.indexed)
            _FilterButton<T>(
              filter: filter,
              value: table._filterValues[i],
              onChanged: (v) => table._filter(i, v),
            ),
          ...widget.toolbarActions,
        ],
      ),
    );
  }
}

class _FilterButton<T> extends StatelessWidget {
  const _FilterButton({
    required this.filter,
    required this.value,
    required this.onChanged,
  });

  final AppTableFilter<T> filter;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    final color = active ? AppColors.primary : context.palette.textSecondary;
    return PopupMenuButton<String>(
      tooltip: filter.label,
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem(value: '', child: Text('Tous (${filter.label})')),
        for (final e in filter.options.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == value,
            child: Text(e.value),
          ),
      ],
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: active ? AppColors.primary : context.palette.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filter.icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              active
                  ? '${filter.label} : ${filter.options[value]}'
                  : filter.label,
              style: context.text.labelLarge?.copyWith(color: color),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Affichage tableau (grand écran)
// -----------------------------------------------------------------------------
class _Table<T> extends StatelessWidget {
  const _Table({
    required this.table,
    required this.rows,
    required this.pageKey,
  });

  final _AppDataTableState<T> table;
  final List<T> rows;
  final String pageKey;

  @override
  Widget build(BuildContext context) {
    final widget = table.widget;
    final headerStyle = context.text.labelMedium?.copyWith(
      color: context.palette.textSecondary,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête (cliquer pour trier)
        Container(
          color: context.palette.surfaceMuted.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              for (final (i, column) in widget.columns.indexed)
                Expanded(
                  flex: column.flex,
                  child: Align(
                    alignment: column.numeric
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: InkWell(
                      onTap: column.sortValue == null
                          ? null
                          : () => table._sortBy(i),
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              column.label.toUpperCase(),
                              style: headerStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (column.sortValue != null)
                            AnimatedRotation(
                              turns: table._sortColumn == i && !table._ascending
                                  ? 0.5
                                  : 0,
                              duration: AppDurations.fast,
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                size: 14,
                                color: table._sortColumn == i
                                    ? AppColors.primary
                                    : context.palette.border,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (table._hasRowActions)
                SizedBox(
                  width: _RowActions.widthFor<T>(widget),
                  child: Text(
                    'ACTIONS',
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ),
        for (final (i, item) in rows.indexed)
          InkWell(
                onTap: widget.onView == null && widget.onEdit == null
                    ? null
                    : () => (widget.onView ?? widget.onEdit)!(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: context.palette.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      for (final column in widget.columns)
                        Expanded(
                          flex: column.flex,
                          child: Align(
                            alignment: column.numeric
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: column.cell(context, item),
                          ),
                        ),
                      if (table._hasRowActions)
                        SizedBox(
                          width: _RowActions.widthFor<T>(widget),
                          child: _RowActions<T>(table: table, item: item),
                        ),
                    ],
                  ),
                ),
              )
              .animate(key: ValueKey('$pageKey-$i'), delay: (25 * i).ms)
              .fadeIn(duration: 250.ms)
              .slideX(begin: 0.03, end: 0),
      ],
    );
  }
}

/// Boutons voir / modifier / supprimer et menu des autres actions.
class _RowActions<T> extends StatelessWidget {
  const _RowActions({required this.table, required this.item});

  final _AppDataTableState<T> table;
  final T item;

  static double widthFor<R>(AppDataTable<R> widget) =>
      40.0 *
          [
            widget.onView,
            widget.onEdit,
            widget.onDelete,
          ].where((a) => a != null).length +
      (widget.actions.isEmpty ? 0 : 40);

  @override
  Widget build(BuildContext context) {
    final widget = table.widget;
    final extra = widget.actions
        .where((a) => a.isVisible?.call(item) ?? true)
        .toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.onView != null)
          _iconButton(
            context,
            'Voir',
            Icons.visibility_outlined,
            () => widget.onView!(item),
          ),
        if (widget.onEdit != null)
          _iconButton(
            context,
            'Modifier',
            Icons.edit_outlined,
            () => widget.onEdit!(item),
          ),
        if (widget.onDelete != null)
          _iconButton(
            context,
            'Supprimer',
            Icons.delete_outline_rounded,
            () => table._delete(item),
            color: AppColors.error,
          ),
        if (widget.actions.isNotEmpty)
          SizedBox(
            width: 40,
            child: extra.isEmpty
                ? null
                : PopupMenuButton<AppTableAction<T>>(
                    tooltip: 'Plus d\'actions',
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (a) => a.onSelected(item),
                    itemBuilder: (_) => [
                      for (final a in extra)
                        PopupMenuItem(
                          value: a,
                          child: Row(
                            children: [
                              Icon(
                                a.icon,
                                size: 18,
                                color: a.isDestructive ? AppColors.error : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                a.label,
                                style: a.isDestructive
                                    ? const TextStyle(color: AppColors.error)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _iconButton(
    BuildContext context,
    String tooltip,
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
  }) => SizedBox(
    width: 40,
    child: IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color ?? context.palette.textSecondary),
    ),
  );
}

// -----------------------------------------------------------------------------
// Affichage en cartes (petit écran)
// -----------------------------------------------------------------------------
class _Cards<T> extends StatelessWidget {
  const _Cards({
    required this.table,
    required this.rows,
    required this.pageKey,
  });

  final _AppDataTableState<T> table;
  final List<T> rows;
  final String pageKey;

  @override
  Widget build(BuildContext context) {
    final widget = table.widget;
    final primary = widget.columns.firstWhere(
      (c) => c.primary,
      orElse: () => widget.columns.first,
    );
    final others = widget.columns.where((c) => c != primary);

    return Column(
      children: [
        for (final (i, item) in rows.indexed)
          InkWell(
                onTap: widget.onView == null && widget.onEdit == null
                    ? null
                    : () => (widget.onView ?? widget.onEdit)!(item),
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: context.palette.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: primary.cell(context, item)),
                          if (table._hasRowActions)
                            _CardMenu<T>(table: table, item: item),
                        ],
                      ),
                      const SizedBox(height: AppSizes.sm),
                      for (final column in others)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 110,
                                child: Text(
                                  column.label,
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: column.cell(context, item),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              )
              .animate(key: ValueKey('$pageKey-$i'), delay: (30 * i).ms)
              .fadeIn(duration: 250.ms)
              .slideY(begin: 0.06, end: 0),
      ],
    );
  }
}

/// Toutes les actions d'une ligne dans un menu (petit écran).
class _CardMenu<T> extends StatelessWidget {
  const _CardMenu({required this.table, required this.item});

  final _AppDataTableState<T> table;
  final T item;

  @override
  Widget build(BuildContext context) {
    final widget = table.widget;
    final entries = <(String, IconData, VoidCallback, bool)>[
      if (widget.onView != null)
        ('Voir', Icons.visibility_outlined, () => widget.onView!(item), false),
      if (widget.onEdit != null)
        ('Modifier', Icons.edit_outlined, () => widget.onEdit!(item), false),
      for (final a in widget.actions)
        if (a.isVisible?.call(item) ?? true)
          (a.label, a.icon, () => a.onSelected(item), a.isDestructive),
      if (widget.onDelete != null)
        (
          'Supprimer',
          Icons.delete_outline_rounded,
          () => table._delete(item),
          true,
        ),
    ];
    return PopupMenuButton<int>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (i) => entries[i].$3(),
      itemBuilder: (_) => [
        for (final (i, (label, icon, _, destructive)) in entries.indexed)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: destructive ? AppColors.error : null,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: destructive
                      ? const TextStyle(color: AppColors.error)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Chargement et pagination
// -----------------------------------------------------------------------------
class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            for (var i = 0; i < 6; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SkeletonBox(width: 40, height: 40, circle: true),
                    SizedBox(width: AppSizes.md),
                    Expanded(child: SkeletonBox(height: 16)),
                    SizedBox(width: AppSizes.md),
                    Expanded(child: SkeletonBox(height: 16)),
                    SizedBox(width: AppSizes.md),
                    SkeletonBox(width: 80, height: 24),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.start,
    required this.shown,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.rowsPerPage,
    required this.options,
    required this.onPage,
    required this.onRowsPerPage,
  });

  final int start;
  final int shown;
  final int total;
  final int page;
  final int pageCount;
  final int rowsPerPage;
  final List<int> options;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onRowsPerPage;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSizes.md,
        runSpacing: AppSizes.xs,
        children: [
          Text('${start + 1}–${start + shown} sur $total', style: muted),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lignes', style: muted),
              const SizedBox(width: AppSizes.sm),
              DropdownButton<int>(
                value: rowsPerPage,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                items: [
                  for (final n in options)
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (n) => n == null ? null : onRowsPerPage(n),
              ),
              const SizedBox(width: AppSizes.sm),
              IconButton(
                tooltip: 'Page précédente',
                onPressed: page > 0 ? () => onPage(page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('${page + 1} / $pageCount', style: context.text.labelLarge),
              IconButton(
                tooltip: 'Page suivante',
                onPressed: page < pageCount - 1 ? () => onPage(page + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
